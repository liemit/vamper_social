<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/libs/LiveKit.php';

function voiceMatchRespond(int $status, array $data): void
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit();
}

function ensureVoiceMatchTables(PDO $db): void
{
    $db->exec("CREATE TABLE IF NOT EXISTS voice_match_queue (
        user_id INT NOT NULL PRIMARY KEY,
        gender_preference VARCHAR(10) NOT NULL DEFAULT 'both',
        last_seen DATETIME NOT NULL,
        KEY idx_voice_match_queue_last_seen (last_seen)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $db->exec("CREATE TABLE IF NOT EXISTS voice_match_sessions (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        room_name VARCHAR(80) NOT NULL UNIQUE,
        user1_id INT NOT NULL,
        user2_id INT NOT NULL,
        status VARCHAR(10) NOT NULL DEFAULT 'active',
        created_at DATETIME NOT NULL,
        ended_at DATETIME NULL,
        KEY idx_voice_match_session_users (user1_id, user2_id, status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $db->exec("CREATE TABLE IF NOT EXISTS voice_match_active_users (
        user_id INT NOT NULL PRIMARY KEY,
        session_id BIGINT UNSIGNED NOT NULL,
        last_seen DATETIME NOT NULL,
        UNIQUE KEY uq_voice_match_active_session_user (session_id, user_id),
        KEY idx_voice_match_active_session (session_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $db->exec("CREATE TABLE IF NOT EXISTS blocked_users (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        blocker_id INT NOT NULL,
        blocked_id INT NOT NULL,
        created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_block (blocker_id, blocked_id),
        KEY idx_blocker (blocker_id),
        KEY idx_blocked (blocked_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function voiceMatchAllows(string $preference, string $gender): bool
{
    return $preference === 'both' || $preference === $gender;
}

function voiceMatchSessionForUser(PDO $db, int $userId, array $settings): ?array
{
    $query = $db->prepare(
        'SELECT s.id, s.room_name, s.user1_id, s.user2_id, s.status,
                active.last_seen AS self_last_seen,
                (partner.last_seen < UTC_TIMESTAMP() - INTERVAL 30 SECOND) AS partner_is_stale,
                u.id AS partner_id, u.full_name, u.profile_photo, u.gender, u.date_of_birth
         FROM voice_match_active_users active
         INNER JOIN voice_match_sessions s ON s.id = active.session_id AND s.status = \'active\'
         INNER JOIN voice_match_active_users partner
           ON partner.session_id = s.id AND partner.user_id <> active.user_id
         INNER JOIN users u ON u.id = partner.user_id AND u.is_active = 1
         WHERE active.user_id = :user_id
         LIMIT 1'
    );
    $query->execute([':user_id' => $userId]);
    $session = $query->fetch(PDO::FETCH_ASSOC);
    if (!$session) {
        return null;
    }

    if ((int)$session['partner_is_stale'] === 1) {
        $end = $db->prepare(
            'UPDATE voice_match_sessions SET status = \'ended\', ended_at = UTC_TIMESTAMP()
             WHERE id = :id AND status = \'active\''
        );
        $end->execute([':id' => $session['id']]);
        $remove = $db->prepare('DELETE FROM voice_match_active_users WHERE session_id = :id');
        $remove->execute([':id' => $session['id']]);
        return null;
    }

    $heartbeat = $db->prepare(
        'UPDATE voice_match_active_users SET last_seen = UTC_TIMESTAMP()
         WHERE user_id = :user_id AND session_id = :session_id'
    );
    $heartbeat->execute([
        ':user_id' => $userId,
        ':session_id' => $session['id'],
    ]);

    $age = 22;
    if (!empty($session['date_of_birth'])) {
        $age = (new DateTime($session['date_of_birth']))->diff(new DateTime())->y;
    }

    return [
        'session_id' => (int)$session['id'],
        'room_name' => $session['room_name'],
        'livekit_url' => $settings['url'],
        'livekit_token' => liveKitToken(
            $settings,
            (string)$userId,
            (string)($session['full_name'] ?? 'Vamper user'),
            $session['room_name'],
            false,
            true,
            3600,
            false,
            false
        ),
        'partner' => [
            'id' => (int)$session['partner_id'],
            'full_name' => $session['full_name'],
            'profile_photo' => $session['profile_photo'],
            'gender' => $session['gender'],
            'age' => $age,
        ],
    ];
}

$database = new Database();
$db = $database->getConnection();
$userId = authenticateApiUser($db);
$data = json_decode(file_get_contents('php://input'), true) ?? [];
$action = (string)($data['action'] ?? '');

if (!in_array($action, ['search', 'poll', 'leave'], true)) {
    voiceMatchRespond(400, ['success' => false, 'message' => 'Choose a valid Voice Match action.']);
}

try {
    ensureVoiceMatchTables($db);

    if ($action === 'leave') {
        $db->beginTransaction();
        $active = $db->prepare(
            'SELECT session_id FROM voice_match_active_users WHERE user_id = :user_id FOR UPDATE'
        );
        $active->execute([':user_id' => $userId]);
        $sessionId = $active->fetchColumn();
        if ($sessionId !== false) {
            $end = $db->prepare(
                'UPDATE voice_match_sessions SET status = \'ended\', ended_at = UTC_TIMESTAMP()
                 WHERE id = :id AND status = \'active\''
            );
            $end->execute([':id' => $sessionId]);
            $removeMembers = $db->prepare(
                'DELETE FROM voice_match_active_users WHERE session_id = :id'
            );
            $removeMembers->execute([':id' => $sessionId]);
        }
        $removeQueue = $db->prepare('DELETE FROM voice_match_queue WHERE user_id = :user_id');
        $removeQueue->execute([':user_id' => $userId]);
        $db->commit();
        voiceMatchRespond(200, ['success' => true]);
    }

    $settings = liveKitSettings();
    if ($settings === null) {
        voiceMatchRespond(503, [
            'success' => false,
            'message' => 'Voice Match calls need LiveKit credentials configured on the server.',
        ]);
    }

    if ($action === 'search') {
        $preference = (string)($data['gender_preference'] ?? 'both');
        if (!in_array($preference, ['male', 'female', 'both'], true)) {
            voiceMatchRespond(400, ['success' => false, 'message' => 'Choose a valid gender preference.']);
        }
        $userQuery = $db->prepare(
            'SELECT gender FROM users WHERE id = :user_id AND is_active = 1 LIMIT 1'
        );
        $userQuery->execute([':user_id' => $userId]);
        $userGender = $userQuery->fetchColumn();
        if ($userGender === false) {
            voiceMatchRespond(404, ['success' => false, 'message' => 'Your account is unavailable.']);
        }

        $enqueue = $db->prepare(
            'INSERT INTO voice_match_queue (user_id, gender_preference, last_seen)
             VALUES (:user_id, :preference, UTC_TIMESTAMP())
             ON DUPLICATE KEY UPDATE gender_preference = VALUES(gender_preference),
                                     last_seen = UTC_TIMESTAMP()'
        );
        $enqueue->execute([':user_id' => $userId, ':preference' => $preference]);
    } else {
        $heartbeatQueue = $db->prepare(
            'UPDATE voice_match_queue SET last_seen = UTC_TIMESTAMP() WHERE user_id = :user_id'
        );
        $heartbeatQueue->execute([':user_id' => $userId]);
    }

    $existing = voiceMatchSessionForUser($db, $userId, $settings);
    if ($existing !== null) {
        $removeQueue = $db->prepare('DELETE FROM voice_match_queue WHERE user_id = :user_id');
        $removeQueue->execute([':user_id' => $userId]);
        voiceMatchRespond(200, ['success' => true, 'status' => 'matched', 'data' => $existing]);
    }

    $selfQuery = $db->prepare('SELECT gender, location FROM users WHERE id = :id LIMIT 1');
    $selfQuery->execute([':id' => $userId]);
    $self = $selfQuery->fetch(PDO::FETCH_ASSOC);
    if (!$self) {
        voiceMatchRespond(404, ['success' => false, 'message' => 'Your account is unavailable.']);
    }
    if ($action === 'poll') {
        $preferenceQuery = $db->prepare(
            'SELECT gender_preference FROM voice_match_queue WHERE user_id = :user_id'
        );
        $preferenceQuery->execute([':user_id' => $userId]);
        $preference = $preferenceQuery->fetchColumn();
        if ($preference === false) {
            voiceMatchRespond(200, ['success' => true, 'status' => 'left']);
        }
    }

    $candidateQuery = $db->prepare(
        'SELECT q.user_id, q.gender_preference, u.gender, u.location
         FROM voice_match_queue q
         INNER JOIN users u ON u.id = q.user_id AND u.is_active = 1
         LEFT JOIN voice_match_active_users active ON active.user_id = q.user_id
         WHERE q.user_id <> :user_id
           AND q.last_seen >= UTC_TIMESTAMP() - INTERVAL 15 SECOND
           AND active.user_id IS NULL
           AND NOT EXISTS (
               SELECT 1 FROM blocked_users b
               WHERE (b.blocker_id = :user_id2 AND b.blocked_id = q.user_id)
                  OR (b.blocker_id = q.user_id2 AND b.blocked_id = :user_id3)
           )
         ORDER BY (u.location = :location) DESC, q.last_seen ASC
         LIMIT 40'
    );
    $candidateQuery->execute([
        ':user_id' => $userId,
        ':user_id2' => $userId,
        ':user_id3' => $userId,
        ':location' => (string)($self['location'] ?? ''),
    ]);
    $candidate = null;
    foreach ($candidateQuery->fetchAll(PDO::FETCH_ASSOC) as $possible) {
        if (
            voiceMatchAllows((string)$preference, (string)$possible['gender'])
            && voiceMatchAllows((string)$possible['gender_preference'], (string)$self['gender'])
        ) {
            $candidate = $possible;
            break;
        }
    }

    if ($candidate !== null) {
        try {
            $db->beginTransaction();
            $lockQueue = $db->prepare(
                'SELECT user_id FROM voice_match_queue
                 WHERE user_id IN (:user1, :user2)
                   AND last_seen >= UTC_TIMESTAMP() - INTERVAL 15 SECOND
                 ORDER BY user_id FOR UPDATE'
            );
            $lockQueue->execute([':user1' => $userId, ':user2' => $candidate['user_id']]);
            $lockedUsers = array_map('intval', $lockQueue->fetchAll(PDO::FETCH_COLUMN));
            sort($lockedUsers);
            $expectedUsers = [$userId, (int)$candidate['user_id']];
            sort($expectedUsers);
            if ($lockedUsers !== $expectedUsers) {
                $db->rollBack();
                voiceMatchRespond(200, ['success' => true, 'status' => 'searching']);
            }

            $activeQuery = $db->prepare(
                'SELECT user_id FROM voice_match_active_users
                 WHERE user_id IN (:user1, :user2) FOR UPDATE'
            );
            $activeQuery->execute([':user1' => $userId, ':user2' => $candidate['user_id']]);
            if ($activeQuery->fetchColumn() !== false) {
                $db->rollBack();
                $existing = voiceMatchSessionForUser($db, $userId, $settings);
                if ($existing !== null) {
                    voiceMatchRespond(200, ['success' => true, 'status' => 'matched', 'data' => $existing]);
                }
                voiceMatchRespond(200, ['success' => true, 'status' => 'searching']);
            }

            $roomName = 'vamper-voice-' . bin2hex(random_bytes(16));
            $createSession = $db->prepare(
                'INSERT INTO voice_match_sessions
                    (room_name, user1_id, user2_id, status, created_at)
                 VALUES (:room_name, :user1, :user2, \'active\', UTC_TIMESTAMP())'
            );
            $createSession->execute([
                ':room_name' => $roomName,
                ':user1' => $userId,
                ':user2' => (int)$candidate['user_id'],
            ]);
            $sessionId = (int)$db->lastInsertId();
            $members = $db->prepare(
                'INSERT INTO voice_match_active_users (user_id, session_id, last_seen)
                 VALUES (:user1, :session_id, UTC_TIMESTAMP()), (:user2, :session_id, UTC_TIMESTAMP())'
            );
            $members->execute([
                ':user1' => $userId,
                ':user2' => (int)$candidate['user_id'],
                ':session_id' => $sessionId,
            ]);
            $removeQueue = $db->prepare(
                'DELETE FROM voice_match_queue WHERE user_id IN (:user1, :user2)'
            );
            $removeQueue->execute([':user1' => $userId, ':user2' => $candidate['user_id']]);
            $db->commit();
        } catch (PDOException $error) {
            if ($db->inTransaction()) {
                $db->rollBack();
            }
            error_log('Voice Match pairing race: ' . $error->getMessage());
        }

        $existing = voiceMatchSessionForUser($db, $userId, $settings);
        if ($existing !== null) {
            voiceMatchRespond(200, ['success' => true, 'status' => 'matched', 'data' => $existing]);
        }
    }

    voiceMatchRespond(200, ['success' => true, 'status' => 'searching']);
} catch (Throwable $error) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    error_log('Voice Match session error: ' . $error->getMessage());
    voiceMatchRespond(500, ['success' => false, 'message' => 'Voice Match is unavailable right now.']);
}
