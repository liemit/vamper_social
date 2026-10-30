<?php

function ensureGiftTables(PDO $db): void
{
    $db->exec("CREATE TABLE IF NOT EXISTS gift_catalog (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        gift_key VARCHAR(40) NOT NULL UNIQUE,
        name VARCHAR(80) NOT NULL,
        emoji VARCHAR(16) NOT NULL,
        price_coins INT UNSIGNED NOT NULL,
        sort_order INT NOT NULL DEFAULT 0,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL,
        KEY idx_gift_catalog_active (is_active, sort_order)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $db->exec("CREATE TABLE IF NOT EXISTS gift_transactions (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        sender_id INT NOT NULL,
        receiver_id INT NOT NULL,
        gift_id INT UNSIGNED NOT NULL,
        context_type VARCHAR(10) NOT NULL,
        context_id INT NOT NULL,
        request_id VARCHAR(64) NOT NULL,
        gift_name VARCHAR(80) NOT NULL,
        gift_emoji VARCHAR(16) NOT NULL,
        price_coins INT UNSIGNED NOT NULL,
        created_at DATETIME NOT NULL,
        UNIQUE KEY uq_gift_sender_request (sender_id, request_id),
        KEY idx_gift_receiver_created (receiver_id, created_at),
        KEY idx_gift_context (context_type, context_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $db->exec("CREATE TABLE IF NOT EXISTS notifications (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        sender_id INT NULL,
        type VARCHAR(50) NOT NULL,
        title VARCHAR(255) NOT NULL,
        body TEXT NOT NULL,
        is_read INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user (user_id)
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

    $seed = $db->prepare(
        'INSERT IGNORE INTO gift_catalog
            (gift_key, name, emoji, price_coins, sort_order, is_active, created_at)
         VALUES
            (:rose_key, :rose_name, :rose_emoji, 10, 10, 1, UTC_TIMESTAMP()),
            (:heart_key, :heart_name, :heart_emoji, 25, 20, 1, UTC_TIMESTAMP()),
            (:coffee_key, :coffee_name, :coffee_emoji, 50, 30, 1, UTC_TIMESTAMP()),
            (:teddy_key, :teddy_name, :teddy_emoji, 100, 40, 1, UTC_TIMESTAMP()),
            (:diamond_key, :diamond_name, :diamond_emoji, 250, 50, 1, UTC_TIMESTAMP()),
            (:crown_key, :crown_name, :crown_emoji, 500, 60, 1, UTC_TIMESTAMP()),
            (:rocket_key, :rocket_name, :rocket_emoji, 1000, 70, 1, UTC_TIMESTAMP())'
    );
    $seed->execute([
        ':rose_key' => 'rose',
        ':rose_name' => 'Rose',
        ':rose_emoji' => '🌹',
        ':heart_key' => 'heart',
        ':heart_name' => 'Heart',
        ':heart_emoji' => '💖',
        ':coffee_key' => 'coffee',
        ':coffee_name' => 'Coffee',
        ':coffee_emoji' => '☕',
        ':teddy_key' => 'teddy',
        ':teddy_name' => 'Teddy bear',
        ':teddy_emoji' => '🧸',
        ':diamond_key' => 'diamond',
        ':diamond_name' => 'Diamond',
        ':diamond_emoji' => '💎',
        ':crown_key' => 'crown',
        ':crown_name' => 'Royal crown',
        ':crown_emoji' => '👑',
        ':rocket_key' => 'rocket',
        ':rocket_name' => 'Rocket',
        ':rocket_emoji' => '🚀',
    ]);
}

function sendGiftTransaction(
    PDO $db,
    int $senderId,
    int $receiverId,
    int $giftId,
    string $contextType,
    int $contextId,
    string $requestId
): array {
    if ($senderId === $receiverId) {
        throw new InvalidArgumentException('You cannot send a gift to yourself.');
    }
    if (!in_array($contextType, ['chat', 'party'], true) || $contextId < 0) {
        throw new InvalidArgumentException('Choose a valid gift destination.');
    }
    if (!preg_match('/^[a-zA-Z0-9._:-]{12,64}$/', $requestId)) {
        throw new InvalidArgumentException('A valid gift request ID is required.');
    }

    $db->beginTransaction();
    try {
        $balanceQuery = $db->prepare('SELECT coins FROM users WHERE id = :id FOR UPDATE');
        $balanceQuery->execute([':id' => $senderId]);
        $balance = $balanceQuery->fetchColumn();
        if ($balance === false) {
            throw new DomainException('Your account could not be found.');
        }

        $duplicateQuery = $db->prepare(
            'SELECT id, receiver_id, gift_id, context_type, context_id, gift_name,
                    gift_emoji, price_coins
             FROM gift_transactions WHERE sender_id = :sender_id AND request_id = :request_id
             LIMIT 1'
        );
        $duplicateQuery->execute([
            ':sender_id' => $senderId,
            ':request_id' => $requestId,
        ]);
        $duplicate = $duplicateQuery->fetch(PDO::FETCH_ASSOC);
        if ($duplicate) {
            if (
                (int)$duplicate['receiver_id'] !== $receiverId
                || (int)$duplicate['gift_id'] !== $giftId
                || $duplicate['context_type'] !== $contextType
                || ($contextType === 'party' && (int)$duplicate['context_id'] !== $contextId)
                || ($contextType === 'chat' && $contextId > 0
                    && (int)$duplicate['context_id'] !== $contextId)
            ) {
                throw new DomainException('This gift request ID was already used.');
            }
            $db->commit();
            $result = [
                'transaction_id' => (int)$duplicate['id'],
                'gift_id' => $giftId,
                'name' => $duplicate['gift_name'],
                'emoji' => $duplicate['gift_emoji'],
                'price_coins' => (int)$duplicate['price_coins'],
                'remaining_coins' => (int)$balance,
                'context_id' => (int)$duplicate['context_id'],
                'already_processed' => true,
            ];
            if ($contextType === 'chat') {
                $messageQuery = $db->prepare(
                    "SELECT id, content, created_at FROM messages
                     WHERE conversation_id = :conversation_id
                       AND message_type = 'gift'
                       AND JSON_UNQUOTE(JSON_EXTRACT(content, '$.transaction_id')) = :transaction_id
                     LIMIT 1"
                );
                $messageQuery->execute([
                    ':conversation_id' => (int)$duplicate['context_id'],
                    ':transaction_id' => (string)$duplicate['id'],
                ]);
                $message = $messageQuery->fetch(PDO::FETCH_ASSOC);
                if (!$message) {
                    throw new RuntimeException('The gift transaction has no matching chat message.');
                }
                $result['id'] = (int)$message['id'];
                $result['conversation_id'] = (int)$duplicate['context_id'];
                $result['sender_id'] = $senderId;
                $result['receiver_id'] = $receiverId;
                $result['message_type'] = 'gift';
                $result['content'] = $message['content'];
                $result['is_read'] = 0;
                $result['created_at'] = $message['created_at'];
            }
            return $result;
        }

        $receiverQuery = $db->prepare(
            'SELECT full_name FROM users WHERE id = :id AND is_active = 1 LIMIT 1'
        );
        $receiverQuery->execute([':id' => $receiverId]);
        $receiverName = $receiverQuery->fetchColumn();
        if ($receiverName === false) {
            throw new DomainException('The gift recipient is unavailable.');
        }
        $blockQuery = $db->prepare(
            'SELECT 1 FROM blocked_users
             WHERE (blocker_id = :sender_id AND blocked_id = :receiver_id)
                OR (blocker_id = :receiver_id2 AND blocked_id = :sender_id2)
             LIMIT 1'
        );
        $blockQuery->execute([
            ':sender_id' => $senderId,
            ':receiver_id' => $receiverId,
            ':receiver_id2' => $receiverId,
            ':sender_id2' => $senderId,
        ]);
        if ($blockQuery->fetchColumn()) {
            throw new DomainException('Gifts cannot be sent between blocked users.');
        }

        $giftQuery = $db->prepare(
            'SELECT id, name, emoji, price_coins
             FROM gift_catalog WHERE id = :id AND is_active = 1 LIMIT 1'
        );
        $giftQuery->execute([':id' => $giftId]);
        $gift = $giftQuery->fetch(PDO::FETCH_ASSOC);
        if (!$gift) {
            throw new DomainException('This gift is no longer available.');
        }

        if ($contextType === 'chat') {
            $firstUserId = min($senderId, $receiverId);
            $secondUserId = max($senderId, $receiverId);
            if ($contextId > 0) {
                $conversationQuery = $db->prepare(
                    'SELECT id FROM conversations
                     WHERE id = :id AND user1_id = :user1 AND user2_id = :user2
                     LIMIT 1 FOR UPDATE'
                );
                $conversationQuery->execute([
                    ':id' => $contextId,
                    ':user1' => $firstUserId,
                    ':user2' => $secondUserId,
                ]);
                $conversationId = $conversationQuery->fetchColumn();
                if ($conversationId === false) {
                    throw new DomainException('This conversation is not available.');
                }
            } else {
                $conversationQuery = $db->prepare(
                    'SELECT id FROM conversations
                     WHERE user1_id = :user1 AND user2_id = :user2
                     ORDER BY id ASC LIMIT 1 FOR UPDATE'
                );
                $conversationQuery->execute([
                    ':user1' => $firstUserId,
                    ':user2' => $secondUserId,
                ]);
                $conversationId = $conversationQuery->fetchColumn();
                if ($conversationId === false) {
                    $createConversation = $db->prepare(
                        'INSERT INTO conversations (user1_id, user2_id, updated_at)
                         VALUES (:user1, :user2, UTC_TIMESTAMP())'
                    );
                    $createConversation->execute([
                        ':user1' => $firstUserId,
                        ':user2' => $secondUserId,
                    ]);
                    $conversationId = $db->lastInsertId();
                }
            }
            $contextId = (int)$conversationId;
        } else {
            $partyQuery = $db->prepare(
                'SELECT id FROM parties WHERE id = :party_id AND is_live = 1 LIMIT 1'
            );
            $partyQuery->execute([':party_id' => $contextId]);
            if (!$partyQuery->fetchColumn()) {
                throw new DomainException('This Party is no longer active.');
            }

            $membersQuery = $db->prepare(
                'SELECT user_id FROM party_members
                 WHERE party_id = :party_id
                   AND user_id IN (:sender_id, :receiver_id)
                   AND last_seen >= UTC_TIMESTAMP() - INTERVAL 30 SECOND
                 FOR UPDATE'
            );
            $membersQuery->execute([
                ':party_id' => $contextId,
                ':sender_id' => $senderId,
                ':receiver_id' => $receiverId,
            ]);
            $activeMemberIds = array_map('intval', $membersQuery->fetchAll(PDO::FETCH_COLUMN));
            if (!in_array($senderId, $activeMemberIds, true) || !in_array($receiverId, $activeMemberIds, true)) {
                throw new DomainException('Both people must be in the Party to send a gift.');
            }
        }

        $price = (int)$gift['price_coins'];
        if ((int)$balance < $price) {
            throw new DomainException('Not enough VPC coins to send this gift.');
        }
        $debit = $db->prepare(
            'UPDATE users SET coins = coins - :price
             WHERE id = :id AND coins >= :minimum'
        );
        $debit->execute([
            ':price' => $price,
            ':id' => $senderId,
            ':minimum' => $price,
        ]);
        if ($debit->rowCount() !== 1) {
            throw new DomainException('Not enough VPC coins to send this gift.');
        }

        $transaction = $db->prepare(
            'INSERT INTO gift_transactions
                (sender_id, receiver_id, gift_id, context_type, context_id, request_id,
                 gift_name, gift_emoji, price_coins, created_at)
             VALUES
                (:sender_id, :receiver_id, :gift_id, :context_type, :context_id, :request_id,
                 :gift_name, :gift_emoji, :price_coins, UTC_TIMESTAMP())'
        );
        $transaction->execute([
            ':sender_id' => $senderId,
            ':receiver_id' => $receiverId,
            ':gift_id' => $giftId,
            ':context_type' => $contextType,
            ':context_id' => $contextId,
            ':request_id' => $requestId,
            ':gift_name' => $gift['name'],
            ':gift_emoji' => $gift['emoji'],
            ':price_coins' => $price,
        ]);
        $transactionId = (int)$db->lastInsertId();

        $giftMessage = [
            'transaction_id' => $transactionId,
            'gift_id' => $giftId,
            'name' => $gift['name'],
            'emoji' => $gift['emoji'],
            'price_coins' => $price,
        ];
        if ($contextType === 'chat') {
            $content = json_encode($giftMessage, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
            $message = $db->prepare(
                "INSERT INTO messages
                    (conversation_id, sender_id, receiver_id, message_type, content, media_url, is_read, created_at)
                 VALUES (:conversation_id, :sender_id, :receiver_id, 'gift', :content, NULL, 0, UTC_TIMESTAMP())"
            );
            $message->execute([
                ':conversation_id' => $contextId,
                ':sender_id' => $senderId,
                ':receiver_id' => $receiverId,
                ':content' => $content,
            ]);
            $messageId = (int)$db->lastInsertId();
            $updateConversation = $db->prepare(
                'UPDATE conversations SET last_message = :message, updated_at = UTC_TIMESTAMP()
                 WHERE id = :id'
            );
            $updateConversation->execute([
                ':message' => $gift['emoji'] . ' ' . $gift['name'] . ' gift',
                ':id' => $contextId,
            ]);
            $giftMessage['id'] = $messageId;
            $giftMessage['conversation_id'] = $contextId;
            $giftMessage['sender_id'] = $senderId;
            $giftMessage['receiver_id'] = $receiverId;
            $giftMessage['message_type'] = 'gift';
            $giftMessage['content'] = $content;
            $giftMessage['is_read'] = 0;
            $giftMessage['created_at'] = gmdate('Y-m-d H:i:s');
        } else {
            $eventPayload = json_encode($giftMessage, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
            $event = $db->prepare(
                "INSERT INTO party_events
                    (party_id, user_id, target_user_id, event_type, payload, created_at)
                 VALUES (:party_id, :sender_id, :receiver_id, 'gift', :payload, UTC_TIMESTAMP())"
            );
            $event->execute([
                ':party_id' => $contextId,
                ':sender_id' => $senderId,
                ':receiver_id' => $receiverId,
                ':payload' => $eventPayload,
            ]);
            $giftMessage['event_id'] = (int)$db->lastInsertId();
            $giftMessage['context_id'] = $contextId;
            $giftMessage['sender_id'] = $senderId;
            $giftMessage['receiver_id'] = $receiverId;
            $giftMessage['receiver_name'] = $receiverName;
        }

        $notification = $db->prepare(
            'INSERT INTO notifications
                (user_id, sender_id, type, title, body, is_read, created_at)
             VALUES (:receiver_id, :sender_id, \'gift\', :title, :body, 0, UTC_TIMESTAMP())'
        );
        $notification->execute([
            ':receiver_id' => $receiverId,
            ':sender_id' => $senderId,
            ':title' => 'You received a gift',
            ':body' => $gift['emoji'] . ' ' . $gift['name']
                . ($contextType === 'party' ? ' in a Party' : ' in chat'),
        ]);

        $db->commit();
        $giftMessage['remaining_coins'] = (int)$balance - $price;
        $giftMessage['already_processed'] = false;
        return $giftMessage;
    } catch (Throwable $error) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        throw $error;
    }
}
