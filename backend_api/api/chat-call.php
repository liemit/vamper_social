<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/libs/LiveKit.php';

function chatCallRespond(int $status, array $body): void
{
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_UNICODE);
    exit();
}

function ensureChatCallTables(PDO $db): void
{
    $db->exec("CREATE TABLE IF NOT EXISTS chat_calls (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        conversation_id INT NOT NULL,
        caller_id INT NOT NULL,
        receiver_id INT NOT NULL,
        call_type VARCHAR(10) NOT NULL,
        room_name VARCHAR(80) NOT NULL UNIQUE,
        status VARCHAR(10) NOT NULL DEFAULT 'ringing',
        created_at DATETIME NOT NULL,
        answered_at DATETIME NULL,
        ended_at DATETIME NULL,
        caller_last_seen DATETIME NOT NULL,
        receiver_last_seen DATETIME NOT NULL,
        KEY idx_chat_calls_receiver_status (receiver_id, status, created_at),
        KEY idx_chat_calls_caller_status (caller_id, status, created_at)
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

function chatCallDetails(PDO $db, array $call, int $userId, array $settings): array
{
    $partnerId = (int)$call['caller_id'] === $userId
        ? (int)$call['receiver_id']
        : (int)$call['caller_id'];
    $partnerQuery = $db->prepare(
        'SELECT id, full_name, profile_photo FROM users WHERE id = :id LIMIT 1'
    );
    $partnerQuery->execute([':id' => $partnerId]);
    $partner = $partnerQuery->fetch(PDO::FETCH_ASSOC);
    if (!$partner) {
        throw new RuntimeException('The other call participant is unavailable.');
    }
    $nameQuery = $db->prepare('SELECT full_name FROM users WHERE id = :id LIMIT 1');
    $nameQuery->execute([':id' => $userId]);
    $callerName = $nameQuery->fetchColumn();

    $isVideo = $call['call_type'] === 'video';
    return [
        'call_id' => (int)$call['id'],
        'conversation_id' => (int)$call['conversation_id'],
        'call_type' => $call['call_type'],
        'status' => $call['status'],
        'is_caller' => (int)$call['caller_id'] === $userId,
        'room_name' => $call['room_name'],
        'livekit_url' => $settings['url'],
        'livekit_token' => $call['status'] === 'accepted'
            ? liveKitToken(
                $settings,
                (string)$userId,
                (string)($callerName ?: 'Vamper user'),
                $call['room_name'],
                false,
                true,
                3600,
                false,
                false,
                $isVideo
            )
            : null,
        'partner' => [
            'id' => (int)$partner['id'],
            'full_name' => $partner['full_name'],
            'profile_photo' => $partner['profile_photo'],
        ],
    ];
}

$database = new Database();
$db = $database->getConnection();
$userId = authenticateApiUser($db);
$data = json_decode(file_get_contents('php://input'), true) ?? [];
$action = (string)($data['action'] ?? '');

if (!in_array($action, ['start', 'poll', 'accept', 'decline', 'end'], true)) {
    chatCallRespond(400, ['success' => false, 'message' => 'Choose a valid call action.']);
}

try {
    ensureChatCallTables($db);
    $settings = liveKitSettings();
    if ($settings === null) {
        chatCallRespond(503, [
            'success' => false,
            'message' => 'Calls need LiveKit credentials configured on the server.',
        ]);
    }

    if ($action === 'start') {
        $conversationId = filter_var($data['conversation_id'] ?? null, FILTER_VALIDATE_INT);
        $callType = (string)($data['call_type'] ?? '');
        if (!$conversationId || !in_array($callType, ['audio', 'video'], true)) {
            chatCallRespond(400, ['success' => false, 'message' => 'Choose a valid conversation and call type.']);
        }

        $conversation = $db->prepare(
            'SELECT user1_id, user2_id FROM conversations WHERE id = :id LIMIT 1'
        );
        $conversation->execute([':id' => $conversationId]);
        $members = $conversation->fetch(PDO::FETCH_ASSOC);
        if (!$members || !in_array($userId, [(int)$members['user1_id'], (int)$members['user2_id']], true)) {
            chatCallRespond(403, ['success' => false, 'message' => 'You are not a member of this conversation.']);
        }

        $hasMessages = $db->prepare(
            'SELECT COUNT(DISTINCT sender_id) FROM messages WHERE conversation_id = :conversation_id'
        );
        $hasMessages->execute([':conversation_id' => $conversationId]);
        if ((int)$hasMessages->fetchColumn() < 2) {
            chatCallRespond(403, ['success' => false, 'message' => 'Both people must send a message before starting a call.']);
        }

        $receiverId = (int)$members['user1_id'] === $userId
            ? (int)$members['user2_id']
            : (int)$members['user1_id'];
        $blocked = $db->prepare(
            'SELECT 1 FROM blocked_users
             WHERE (blocker_id = :caller AND blocked_id = :receiver)
                OR (blocker_id = :receiver2 AND blocked_id = :caller2)
             LIMIT 1'
        );
        $blocked->execute([
            ':caller' => $userId,
            ':receiver' => $receiverId,
            ':receiver2' => $receiverId,
            ':caller2' => $userId,
        ]);
        if ($blocked->fetchColumn()) {
            chatCallRespond(403, ['success' => false, 'message' => 'Calls are unavailable between blocked users.']);
        }

        $db->beginTransaction();
        $lockedUsers = [$userId, $receiverId];
        sort($lockedUsers);
        $lockAccounts = $db->prepare(
            'SELECT id FROM users WHERE id IN (:first_id, :second_id) ORDER BY id FOR UPDATE'
        );
        $lockAccounts->execute([
            ':first_id' => $lockedUsers[0],
            ':second_id' => $lockedUsers[1],
        ]);
        $lockAccounts->fetchAll(PDO::FETCH_COLUMN);

        $expireCalls = $db->prepare(
            "UPDATE chat_calls
             SET status = 'missed', ended_at = UTC_TIMESTAMP()
             WHERE status = 'ringing'
               AND created_at < UTC_TIMESTAMP() - INTERVAL 45 SECOND"
        );
        $expireCalls->execute();
        $expireStaleCalls = $db->prepare(
            "UPDATE chat_calls
             SET status = 'ended', ended_at = UTC_TIMESTAMP()
             WHERE status = 'accepted'
               AND (caller_last_seen < UTC_TIMESTAMP() - INTERVAL 35 SECOND
                    OR receiver_last_seen < UTC_TIMESTAMP() - INTERVAL 35 SECOND)"
        );
        $expireStaleCalls->execute();
        $busy = $db->prepare(
            "SELECT id FROM chat_calls
             WHERE status IN ('ringing', 'accepted')
               AND (caller_id IN (:caller, :receiver) OR receiver_id IN (:receiver2, :caller2))
             LIMIT 1"
        );
        $busy->execute([
            ':caller' => $userId,
            ':receiver' => $receiverId,
            ':receiver2' => $receiverId,
            ':caller2' => $userId,
        ]);
        if ($busy->fetchColumn()) {
            $db->rollBack();
            chatCallRespond(409, ['success' => false, 'message' => 'You or your match is already in a call.']);
        }

        $insert = $db->prepare(
            "INSERT INTO chat_calls
                (conversation_id, caller_id, receiver_id, call_type, room_name, status,
                 created_at, caller_last_seen, receiver_last_seen)
             VALUES
                (:conversation_id, :caller_id, :receiver_id, :call_type, :room_name,
                 'ringing', UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP())"
        );
        $roomName = 'vamper-chat-' . bin2hex(random_bytes(16));
        $insert->execute([
            ':conversation_id' => $conversationId,
            ':caller_id' => $userId,
            ':receiver_id' => $receiverId,
            ':call_type' => $callType,
            ':room_name' => $roomName,
        ]);
        $callId = (int)$db->lastInsertId();
        $db->commit();

        $call = [
            'id' => $callId,
            'conversation_id' => $conversationId,
            'caller_id' => $userId,
            'receiver_id' => $receiverId,
            'call_type' => $callType,
            'room_name' => $roomName,
            'status' => 'ringing',
        ];
        chatCallRespond(200, [
            'success' => true,
            'data' => chatCallDetails($db, $call, $userId, $settings),
        ]);
    }

    if ($action === 'poll' && empty($data['call_id'])) {
        $incoming = $db->prepare(
            "SELECT c.id, c.conversation_id, c.caller_id, c.receiver_id, c.call_type,
                    c.room_name, c.status
             FROM chat_calls c
             WHERE c.receiver_id = :receiver_id AND c.status = 'ringing'
               AND c.created_at >= UTC_TIMESTAMP() - INTERVAL 45 SECOND
             ORDER BY c.created_at DESC LIMIT 1"
        );
        $incoming->execute([':receiver_id' => $userId]);
        $call = $incoming->fetch(PDO::FETCH_ASSOC);
        if (!$call) {
            chatCallRespond(200, ['success' => true, 'status' => 'none']);
        }
        chatCallRespond(200, [
            'success' => true,
            'status' => 'incoming',
            'data' => chatCallDetails($db, $call, $userId, $settings),
        ]);
    }

    $callId = filter_var($data['call_id'] ?? null, FILTER_VALIDATE_INT);
    if (!$callId || $callId < 1) {
        chatCallRespond(400, ['success' => false, 'message' => 'A valid call ID is required.']);
    }

    $db->beginTransaction();
    $callQuery = $db->prepare(
        'SELECT c.*,
                (c.created_at < UTC_TIMESTAMP() - INTERVAL 45 SECOND) AS is_expired,
                (c.caller_last_seen < UTC_TIMESTAMP() - INTERVAL 35 SECOND) AS caller_is_stale,
                (c.receiver_last_seen < UTC_TIMESTAMP() - INTERVAL 35 SECOND) AS receiver_is_stale
         FROM chat_calls c WHERE c.id = :id FOR UPDATE'
    );
    $callQuery->execute([':id' => $callId]);
    $call = $callQuery->fetch(PDO::FETCH_ASSOC);
    if (!$call || !in_array($userId, [(int)$call['caller_id'], (int)$call['receiver_id']], true)) {
        $db->rollBack();
        chatCallRespond(404, ['success' => false, 'message' => 'Call not found.']);
    }

    if ($call['status'] === 'ringing' && (int)$call['is_expired'] === 1) {
        $expire = $db->prepare(
            "UPDATE chat_calls SET status = 'missed', ended_at = UTC_TIMESTAMP() WHERE id = :id"
        );
        $expire->execute([':id' => $callId]);
        $call['status'] = 'missed';
    }

    if ($action === 'accept') {
        if ((int)$call['receiver_id'] !== $userId) {
            $db->rollBack();
            chatCallRespond(403, ['success' => false, 'message' => 'Only the recipient can accept this call.']);
        }
        if ($call['status'] !== 'ringing') {
            $db->commit();
            chatCallRespond(409, ['success' => false, 'message' => 'This call is no longer ringing.']);
        }
        $accept = $db->prepare(
            "UPDATE chat_calls
             SET status = 'accepted', answered_at = UTC_TIMESTAMP(),
                 receiver_last_seen = UTC_TIMESTAMP()
             WHERE id = :id AND status = 'ringing'"
        );
        $accept->execute([':id' => $callId]);
        $call['status'] = 'accepted';
    } elseif ($action === 'decline') {
        if ((int)$call['receiver_id'] !== $userId || $call['status'] !== 'ringing') {
            $db->rollBack();
            chatCallRespond(403, ['success' => false, 'message' => 'This call cannot be declined.']);
        }
        $decline = $db->prepare(
            "UPDATE chat_calls SET status = 'declined', ended_at = UTC_TIMESTAMP()
             WHERE id = :id AND status = 'ringing'"
        );
        $decline->execute([':id' => $callId]);
        $call['status'] = 'declined';
    } elseif ($action === 'end') {
        if (!in_array($call['status'], ['ringing', 'accepted'], true)) {
            $db->commit();
            chatCallRespond(200, ['success' => true, 'status' => $call['status']]);
        }
        $end = $db->prepare(
            "UPDATE chat_calls SET status = 'ended', ended_at = UTC_TIMESTAMP() WHERE id = :id"
        );
        $end->execute([':id' => $callId]);
        $call['status'] = 'ended';
    } elseif ($action === 'poll') {
        $lastSeenColumn = (int)$call['caller_id'] === $userId
            ? 'caller_last_seen'
            : 'receiver_last_seen';
        $updateHeartbeat = $db->prepare(
            "UPDATE chat_calls SET `$lastSeenColumn` = UTC_TIMESTAMP() WHERE id = :id"
        );
        $updateHeartbeat->execute([':id' => $callId]);
        $partnerLastSeenColumn = (int)$call['caller_id'] === $userId
            ? 'receiver_is_stale'
            : 'caller_is_stale';
        if (
            $call['status'] === 'accepted'
            && (int)$call[$partnerLastSeenColumn] === 1
        ) {
            $end = $db->prepare(
                "UPDATE chat_calls SET status = 'ended', ended_at = UTC_TIMESTAMP() WHERE id = :id"
            );
            $end->execute([':id' => $callId]);
            $call['status'] = 'ended';
        }
    }
    $db->commit();

    $response = ['success' => true, 'status' => $call['status']];
    if (in_array($call['status'], ['ringing', 'accepted'], true)) {
        $response['data'] = chatCallDetails($db, $call, $userId, $settings);
    } else {
        $response['data'] = [
            'call_id' => (int)$call['id'],
            'call_type' => $call['call_type'],
            'status' => $call['status'],
        ];
    }
    chatCallRespond(200, $response);
} catch (Throwable $error) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    error_log('Chat call error: ' . $error->getMessage());
    chatCallRespond(500, ['success' => false, 'message' => 'Unable to process this call right now.']);
}
