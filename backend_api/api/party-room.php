<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/libs/LiveKit.php';
require_once __DIR__ . '/libs/GiftSystem.php';

function partyRoomRespond(int $status, array $body): void
{
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_UNICODE);
    exit();
}

function ensurePartyRoomTables(PDO $db): void
{
    $db->exec("CREATE TABLE IF NOT EXISTS party_members (
        party_id INT NOT NULL,
        user_id INT NOT NULL,
        seat_index TINYINT NULL,
        is_hand_raised TINYINT(1) NOT NULL DEFAULT 0,
        is_cohost TINYINT(1) NOT NULL DEFAULT 0,
        can_share_screen TINYINT(1) NOT NULL DEFAULT 0,
        is_mic_locked TINYINT(1) NOT NULL DEFAULT 0,
        last_seen DATETIME NOT NULL,
        PRIMARY KEY (party_id, user_id),
        UNIQUE KEY uq_party_member_seat (party_id, seat_index),
        KEY idx_party_member_last_seen (party_id, last_seen)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $db->exec("CREATE TABLE IF NOT EXISTS party_messages (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        party_id INT NOT NULL,
        user_id INT NOT NULL,
        message VARCHAR(500) NOT NULL,
        created_at DATETIME NOT NULL,
        KEY idx_party_messages (party_id, id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $db->exec("CREATE TABLE IF NOT EXISTS party_events (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        party_id INT NOT NULL,
        user_id INT NOT NULL,
        target_user_id INT NULL,
        event_type VARCHAR(20) NOT NULL,
        payload TEXT NOT NULL,
        created_at DATETIME NOT NULL,
        KEY idx_party_events (party_id, id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    foreach ([
        'can_share_screen' => 'TINYINT(1) NOT NULL DEFAULT 0',
        'is_mic_locked' => 'TINYINT(1) NOT NULL DEFAULT 0',
    ] as $column => $definition) {
        $columnQuery = $db->query("SHOW COLUMNS FROM party_members LIKE " . $db->quote($column));
        if ($columnQuery->fetch(PDO::FETCH_ASSOC) === false) {
            $db->exec("ALTER TABLE party_members ADD COLUMN `$column` $definition");
        }
    }

    $targetColumn = $db->query("SHOW COLUMNS FROM party_events LIKE 'target_user_id'");
    if ($targetColumn->fetch(PDO::FETCH_ASSOC) === false) {
        $db->exec('ALTER TABLE party_events ADD COLUMN target_user_id INT NULL');
    }

    $payloadColumn = $db->query("SHOW COLUMNS FROM party_events LIKE 'payload'");
    $payloadDefinition = $payloadColumn->fetch(PDO::FETCH_ASSOC);
    if ($payloadDefinition && stripos((string)$payloadDefinition['Type'], 'text') === false) {
        $db->exec('ALTER TABLE party_events MODIFY payload TEXT NOT NULL');
    }
}

function partyRoomName(int $partyId): string
{
    return 'vamper-party-' . $partyId;
}

$database = new Database();
$db = $database->getConnection();
$userId = authenticateApiUser($db);
$data = json_decode(file_get_contents('php://input'), true);
$partyId = filter_var($data['party_id'] ?? null, FILTER_VALIDATE_INT);
$action = (string)($data['action'] ?? '');

if (!$partyId || $partyId < 1) {
    partyRoomRespond(400, ['success' => false, 'message' => 'A valid party ID is required.']);
}

try {
    if ($action === 'join' || $action === 'send_gift') {
        ensurePartyRoomTables($db);
    }
    $partyQuery = $db->prepare(
        'SELECT id, host_id, title, is_private, password, is_live FROM parties WHERE id = :id LIMIT 1'
    );
    $partyQuery->execute([':id' => $partyId]);
    $party = $partyQuery->fetch(PDO::FETCH_ASSOC);
    if (!$party || (int)$party['is_live'] !== 1) {
        partyRoomRespond(404, ['success' => false, 'message' => 'This party is no longer available.']);
    }

    $hostId = (int)$party['host_id'];
    $roomName = partyRoomName($partyId);
    $isHost = $userId === $hostId;

    if ($action === 'join') {
        if (!$isHost) {
            $blockQuery = $db->prepare(
                'SELECT 1 FROM blocked_users
                 WHERE (blocker_id = :host_id AND blocked_id = :user_id)
                    OR (blocker_id = :user_id AND blocked_id = :host_id)
                 LIMIT 1'
            );
            $blockQuery->execute([':host_id' => $hostId, ':user_id' => $userId]);
            if ($blockQuery->fetchColumn()) {
                partyRoomRespond(403, ['success' => false, 'message' => 'You cannot join this party room.']);
            }
        }

        if ((int)$party['is_private'] === 1 && !$isHost) {
            $providedPassword = (string)($data['password'] ?? '');
            $storedPassword = (string)($party['password'] ?? '');
            $isPasswordHash = password_get_info($storedPassword)['algo'] !== null;
            $passwordMatches = strlen($providedPassword) <= 72 && (
                $isPasswordHash
                    ? password_verify($providedPassword, $storedPassword)
                    : ($storedPassword !== '' && hash_equals($storedPassword, $providedPassword))
            );

            if (!$passwordMatches) {
                partyRoomRespond(403, ['success' => false, 'message' => 'Incorrect party password.']);
            }
            if (!$isPasswordHash) {
                $upgrade = $db->prepare('UPDATE parties SET password = :password WHERE id = :id');
                $upgrade->execute([
                    ':password' => password_hash($providedPassword, PASSWORD_DEFAULT),
                    ':id' => $partyId,
                ]);
            }
        }

        $member = $db->prepare(
            "INSERT INTO party_members (party_id, user_id, seat_index, last_seen)
             VALUES (:party_id, :user_id, :seat_index, UTC_TIMESTAMP())
             ON DUPLICATE KEY UPDATE
                seat_index = IF(VALUES(seat_index) = 0, 0, seat_index),
                last_seen = UTC_TIMESTAMP()"
        );
        $member->execute([
            ':party_id' => $partyId,
            ':user_id' => $userId,
            ':seat_index' => $isHost ? 0 : null,
        ]);

        $seatQuery = $db->prepare(
            'SELECT seat_index, can_share_screen, is_mic_locked
             FROM party_members WHERE party_id = :party_id AND user_id = :user_id'
        );
        $seatQuery->execute([':party_id' => $partyId, ':user_id' => $userId]);
        $member = $seatQuery->fetch(PDO::FETCH_ASSOC);
        $seatIndex = $member['seat_index'];
        $settings = liveKitSettings();
        $liveKitToken = $settings === null
            ? null
            : liveKitToken(
                $settings,
                (string)$userId,
                (string)$party['title'],
                $roomName,
                false,
                $seatIndex !== null,
                3600,
                $isHost || (bool)$member['can_share_screen'],
                (bool)$member['is_mic_locked']
            );
        partyRoomRespond(200, [
            'success' => true,
            'livekit_configured' => $settings !== null,
            'livekit_url' => $settings['url'] ?? null,
            'livekit_token' => $liveKitToken,
            'can_share_screen' => $isHost || (bool)$member['can_share_screen'],
            'is_mic_locked' => (bool)$member['is_mic_locked'],
            'message' => $settings === null
                ? 'Party membership started; LiveKit server credentials are not configured.'
                : 'Connected to the party service.',
        ]);
    }

    $membership = $db->prepare(
        'SELECT seat_index, is_cohost, can_share_screen, is_mic_locked
         FROM party_members WHERE party_id = :party_id AND user_id = :user_id LIMIT 1'
    );
    $membership->execute([':party_id' => $partyId, ':user_id' => $userId]);
    $member = $membership->fetch(PDO::FETCH_ASSOC);
    if (!$member) {
        partyRoomRespond(403, ['success' => false, 'message' => 'Join this party before using room features.']);
    }

    $isCohost = (int)$member['is_cohost'] === 1;
    $canModerate = $isHost || $isCohost;

    switch ($action) {
        case 'refresh_token':
            $settings = liveKitSettings();
            if ($settings === null) {
                partyRoomRespond(503, [
                    'success' => false,
                    'message' => 'LiveKit is not configured on the server.',
                ]);
            }
            partyRoomRespond(200, [
                'success' => true,
                'livekit_url' => $settings['url'],
                'livekit_token' => liveKitToken(
                    $settings,
                    (string)$userId,
                    (string)$party['title'],
                    $roomName,
                    false,
                    $member['seat_index'] !== null,
                    3600,
                    $isHost || (bool)$member['can_share_screen'],
                    (bool)$member['is_mic_locked']
                ),
                'can_publish' => $member['seat_index'] !== null,
                'can_share_screen' => $isHost || (bool)$member['can_share_screen'],
                'is_mic_locked' => (bool)$member['is_mic_locked'],
            ]);

        case 'sync':
            $heartbeat = $db->prepare(
                'UPDATE party_members SET last_seen = UTC_TIMESTAMP()
                 WHERE party_id = :party_id AND user_id = :user_id'
            );
            $heartbeat->execute([':party_id' => $partyId, ':user_id' => $userId]);

            $participantsQuery = $db->prepare(
                'SELECT pm.user_id, pm.seat_index, pm.is_hand_raised, pm.is_cohost,
                        pm.can_share_screen, pm.is_mic_locked,
                        u.full_name, u.profile_photo, frame.image_url AS active_profile_frame_code
                 FROM party_members pm
                 INNER JOIN users u ON u.id = pm.user_id
                 LEFT JOIN shop_items frame
                   ON frame.id = u.active_profile_frame_id AND frame.type = \'profile_frame\'
                 WHERE pm.party_id = :party_id AND pm.last_seen >= UTC_TIMESTAMP() - INTERVAL 30 SECOND
                 ORDER BY pm.seat_index IS NULL, pm.seat_index, u.full_name'
            );
            $participantsQuery->execute([':party_id' => $partyId]);
            $participants = $participantsQuery->fetchAll(PDO::FETCH_ASSOC);

            $messageId = max(0, (int)($data['after_message_id'] ?? 0));
            $messagesQuery = $db->prepare(
                'SELECT m.id, m.user_id, m.message, m.created_at, u.full_name
                 FROM party_messages m
                 INNER JOIN users u ON u.id = m.user_id
                 WHERE m.party_id = :party_id AND m.id > :after_id
                 ORDER BY m.id ASC LIMIT 100'
            );
            $messagesQuery->execute([':party_id' => $partyId, ':after_id' => $messageId]);

            $eventId = max(0, (int)($data['after_event_id'] ?? 0));
            $eventsQuery = $db->prepare(
                'SELECT e.id, e.user_id, e.target_user_id, e.event_type, e.payload,
                        u.full_name, target.full_name AS target_name
                 FROM party_events e
                 INNER JOIN users u ON u.id = e.user_id
                 LEFT JOIN users target ON target.id = e.target_user_id
                 WHERE e.party_id = :party_id AND e.id > :after_id
                 ORDER BY e.id ASC LIMIT 100'
            );
            $eventsQuery->execute([':party_id' => $partyId, ':after_id' => $eventId]);

            $count = $db->prepare(
                'UPDATE parties SET participants_count = (
                    SELECT COUNT(*) FROM party_members
                    WHERE party_id = :party_id AND last_seen >= UTC_TIMESTAMP() - INTERVAL 30 SECOND
                 ) WHERE id = :party_id'
            );
            $count->execute([':party_id' => $partyId]);

            partyRoomRespond(200, [
                'success' => true,
                'data' => [
                    'participants' => $participants,
                    'messages' => $messagesQuery->fetchAll(PDO::FETCH_ASSOC),
                    'events' => $eventsQuery->fetchAll(PDO::FETCH_ASSOC),
                    'self' => [
                        'seat_index' => $member['seat_index'] === null ? null : (int)$member['seat_index'],
                        'is_hand_raised' => (int)$member['is_hand_raised'],
                        'is_cohost' => $isCohost,
                        'can_share_screen' => $isHost || (bool)$member['can_share_screen'],
                        'is_mic_locked' => (bool)$member['is_mic_locked'],
                    ],
                    'is_host' => $isHost,
                ],
            ]);

        case 'take_seat':
            $seatIndex = filter_var($data['seat_index'] ?? null, FILTER_VALIDATE_INT);
            if (
                $seatIndex === false
                || $seatIndex < ($isHost ? 0 : 1)
                || $seatIndex > 9
            ) {
                partyRoomRespond(400, ['success' => false, 'message' => 'Choose an available participant seat.']);
            }
            $db->beginTransaction();
            $seatQuery = $db->prepare(
                'SELECT user_id FROM party_members
                 WHERE party_id = :party_id AND seat_index = :seat_index FOR UPDATE'
            );
            $seatQuery->execute([':party_id' => $partyId, ':seat_index' => $seatIndex]);
            $seatOwner = $seatQuery->fetchColumn();
            if ($seatOwner !== false && (int)$seatOwner !== $userId) {
                $db->rollBack();
                partyRoomRespond(409, ['success' => false, 'message' => 'That seat has already been taken.']);
            }
            $takeSeat = $db->prepare(
                'UPDATE party_members SET seat_index = :seat_index, is_hand_raised = 0, last_seen = UTC_TIMESTAMP()
                 WHERE party_id = :party_id AND user_id = :user_id'
            );
            $takeSeat->execute([
                ':seat_index' => $seatIndex,
                ':party_id' => $partyId,
                ':user_id' => $userId,
            ]);
            $db->commit();
            partyRoomRespond(200, ['success' => true, 'message' => 'You took the seat.']);

        case 'leave_seat':
            if ($isHost) {
                partyRoomRespond(400, ['success' => false, 'message' => 'The host seat cannot be left.']);
            }
            $leaveSeat = $db->prepare(
                'UPDATE party_members SET seat_index = NULL, last_seen = UTC_TIMESTAMP()
                 WHERE party_id = :party_id AND user_id = :user_id'
            );
            $leaveSeat->execute([':party_id' => $partyId, ':user_id' => $userId]);
            partyRoomRespond(200, ['success' => true, 'message' => 'You left the speaker seat.']);

        case 'raise_hand':
            $raised = !empty($data['raised']) ? 1 : 0;
            $raiseHand = $db->prepare(
                'UPDATE party_members SET is_hand_raised = :raised, last_seen = UTC_TIMESTAMP()
                 WHERE party_id = :party_id AND user_id = :user_id'
            );
            $raiseHand->execute([':raised' => $raised, ':party_id' => $partyId, ':user_id' => $userId]);
            partyRoomRespond(200, ['success' => true]);

        case 'send_message':
            $text = trim((string)($data['message'] ?? ''));
            if ($text === '' || mb_strlen($text) > 500) {
                partyRoomRespond(400, ['success' => false, 'message' => 'Messages must be 1 to 500 characters.']);
            }
            $sendMessage = $db->prepare(
                'INSERT INTO party_messages (party_id, user_id, message, created_at)
                 VALUES (:party_id, :user_id, :message, UTC_TIMESTAMP())'
            );
            $sendMessage->execute([':party_id' => $partyId, ':user_id' => $userId, ':message' => $text]);
            partyRoomRespond(200, ['success' => true, 'message_id' => (int)$db->lastInsertId()]);

        case 'send_gift':
            $giftId = filter_var($data['gift_id'] ?? null, FILTER_VALIDATE_INT);
            $targetId = filter_var($data['target_user_id'] ?? null, FILTER_VALIDATE_INT);
            if (!$giftId || !$targetId) {
                partyRoomRespond(400, ['success' => false, 'message' => 'Choose a gift and a participant.']);
            }
            ensureGiftTables($db);
            try {
                $gift = sendGiftTransaction(
                    $db,
                    $userId,
                    $targetId,
                    $giftId,
                    'party',
                    $partyId,
                    (string)($data['request_id'] ?? '')
                );
            } catch (InvalidArgumentException | DomainException $error) {
                partyRoomRespond(400, ['success' => false, 'message' => $error->getMessage()]);
            }
            partyRoomRespond(200, ['success' => true, 'data' => $gift]);

        case 'react':
            $reaction = (string)($data['reaction'] ?? '');
            if (!in_array($reaction, ['👏', '😂', '🔥', '🎉', '❤️'], true)) {
                partyRoomRespond(400, ['success' => false, 'message' => 'Unsupported reaction.']);
            }
            $event = $db->prepare(
                "INSERT INTO party_events (party_id, user_id, event_type, payload, created_at)
                 VALUES (:party_id, :user_id, 'reaction', :payload, UTC_TIMESTAMP())"
            );
            $event->execute([':party_id' => $partyId, ':user_id' => $userId, ':payload' => $reaction]);
            partyRoomRespond(200, ['success' => true]);

        case 'send_effect':
            $effect = (string)($data['effect'] ?? '');
            $targetId = filter_var($data['target_user_id'] ?? null, FILTER_VALIDATE_INT);
            if (!in_array($effect, ['❤️', '💩', '🔫', '🐶', '🦁', '🥁'], true)) {
                partyRoomRespond(400, ['success' => false, 'message' => 'Unsupported party effect.']);
            }
            if (!$targetId || $targetId === $userId) {
                partyRoomRespond(400, ['success' => false, 'message' => 'Choose another participant.']);
            }
            $targetQuery = $db->prepare(
                'SELECT 1 FROM party_members WHERE party_id = :party_id AND user_id = :user_id LIMIT 1'
            );
            $targetQuery->execute([':party_id' => $partyId, ':user_id' => $targetId]);
            if (!$targetQuery->fetchColumn()) {
                partyRoomRespond(404, ['success' => false, 'message' => 'That participant is no longer in the room.']);
            }
            $event = $db->prepare(
                "INSERT INTO party_events (party_id, user_id, target_user_id, event_type, payload, created_at)
                 VALUES (:party_id, :user_id, :target_user_id, 'effect', :payload, UTC_TIMESTAMP())"
            );
            $event->execute([
                ':party_id' => $partyId,
                ':user_id' => $userId,
                ':target_user_id' => $targetId,
                ':payload' => $effect,
            ]);
            partyRoomRespond(200, ['success' => true]);

        case 'set_screen_share_permission':
            if (!$isHost) {
                partyRoomRespond(403, ['success' => false, 'message' => 'Only the host can grant screen sharing.']);
            }
            $targetId = filter_var($data['target_user_id'] ?? null, FILTER_VALIDATE_INT);
            if (!$targetId || $targetId === $hostId) {
                partyRoomRespond(400, ['success' => false, 'message' => 'Choose another participant.']);
            }
            $permission = $db->prepare(
                'UPDATE party_members SET can_share_screen = :allowed
                 WHERE party_id = :party_id AND user_id = :target_id'
            );
            $participantCheck = $db->prepare(
                'SELECT 1 FROM party_members WHERE party_id = :party_id AND user_id = :target_id'
            );
            $participantCheck->execute([':party_id' => $partyId, ':target_id' => $targetId]);
            if (!$participantCheck->fetchColumn()) {
                partyRoomRespond(404, ['success' => false, 'message' => 'That participant is no longer in the room.']);
            }
            $permission->execute([
                ':allowed' => !empty($data['allowed']) ? 1 : 0,
                ':party_id' => $partyId,
                ':target_id' => $targetId,
            ]);
            partyRoomRespond(200, ['success' => true]);

        case 'set_cohost':
            if (!$isHost) {
                partyRoomRespond(403, ['success' => false, 'message' => 'Only the host can manage co-hosts.']);
            }
            $targetId = filter_var($data['target_user_id'] ?? null, FILTER_VALIDATE_INT);
            if (!$targetId || $targetId === $hostId) {
                partyRoomRespond(400, ['success' => false, 'message' => 'Choose a current participant.']);
            }
            $setCohost = $db->prepare(
                'UPDATE party_members SET is_cohost = :is_cohost
                 WHERE party_id = :party_id AND user_id = :target_id'
            );
            $setCohost->execute([
                ':is_cohost' => !empty($data['is_cohost']) ? 1 : 0,
                ':party_id' => $partyId,
                ':target_id' => $targetId,
            ]);
            if ($setCohost->rowCount() === 0) {
                partyRoomRespond(404, ['success' => false, 'message' => 'That participant is no longer in the room.']);
            }
            partyRoomRespond(200, ['success' => true]);

        case 'mute_participant':
        case 'remove_participant':
        case 'set_mic_lock':
            if (!$canModerate) {
                partyRoomRespond(403, ['success' => false, 'message' => 'Host or co-host permission is required.']);
            }
            $targetId = filter_var($data['target_user_id'] ?? null, FILTER_VALIDATE_INT);
            if (!$targetId || $targetId === $hostId || $targetId === $userId) {
                partyRoomRespond(400, ['success' => false, 'message' => 'Choose another participant.']);
            }
            $settings = liveKitSettings();
            if ($settings === null) {
                partyRoomRespond(503, ['success' => false, 'message' => 'LiveKit moderation is not configured on the server.']);
            }
            if ($action === 'remove_participant') {
                liveKitAdminRequest($settings, 'RemoveParticipant', [
                    'room' => $roomName,
                    'identity' => (string)$targetId,
                ]);
                $remove = $db->prepare('DELETE FROM party_members WHERE party_id = :party_id AND user_id = :user_id');
                $remove->execute([':party_id' => $partyId, ':user_id' => $targetId]);
                partyRoomRespond(200, ['success' => true, 'message' => 'Participant removed from the party.']);
            }

            $shouldLock = $action === 'mute_participant' || !empty($data['locked']);
            $lockStmt = $db->prepare(
                'UPDATE party_members SET is_mic_locked = :locked
                 WHERE party_id = :party_id AND user_id = :target_id'
            );
            $participantCheck = $db->prepare(
                'SELECT 1 FROM party_members WHERE party_id = :party_id AND user_id = :target_id'
            );
            $participantCheck->execute([':party_id' => $partyId, ':target_id' => $targetId]);
            if (!$participantCheck->fetchColumn()) {
                partyRoomRespond(404, ['success' => false, 'message' => 'That participant is no longer in the room.']);
            }
            $lockStmt->execute([
                ':locked' => $shouldLock ? 1 : 0,
                ':party_id' => $partyId,
                ':target_id' => $targetId,
            ]);
            if (!$shouldLock) {
                partyRoomRespond(200, ['success' => true, 'message' => 'Participant microphone unlocked.']);
            }

            $participantInfo = liveKitAdminRequest($settings, 'GetParticipant', [
                'room' => $roomName,
                'identity' => (string)$targetId,
            ]);
            $mutedTracks = 0;
            foreach (($participantInfo['tracks'] ?? []) as $track) {
                $isAudio = strtolower((string)($track['type'] ?? '')) === 'audio'
                    || strtoupper((string)($track['source'] ?? '')) === 'MICROPHONE';
                if ($isAudio && !empty($track['sid'])) {
                    liveKitAdminRequest($settings, 'MutePublishedTrack', [
                        'room' => $roomName,
                        'identity' => (string)$targetId,
                        'trackSid' => (string)$track['sid'],
                        'muted' => true,
                    ]);
                    $mutedTracks++;
                }
            }
            partyRoomRespond(200, [
                'success' => true,
                'message' => $mutedTracks > 0
                    ? 'Participant microphone locked and muted.'
                    : 'Participant microphone locked.',
            ]);

        case 'leave':
            $leave = $db->prepare('DELETE FROM party_members WHERE party_id = :party_id AND user_id = :user_id');
            $leave->execute([':party_id' => $partyId, ':user_id' => $userId]);
            partyRoomRespond(200, ['success' => true]);

        default:
            partyRoomRespond(400, ['success' => false, 'message' => 'Unsupported party-room action.']);
    }
} catch (Throwable $error) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    error_log('Party room request failed: ' . $error->getMessage());
    $status = $error instanceof PDOException && $error->getCode() === '23000'
        ? 409
        : (str_starts_with($error->getMessage(), 'LiveKit') ? 503 : 500);
    partyRoomRespond($status, [
        'success' => false,
        'message' => match ($status) {
            409 => 'That seat has already been taken.',
            503 => 'LiveKit is unavailable. Check the server configuration and try again.',
            default => 'Unable to process the party-room request.',
        },
    ]);
}
?>
