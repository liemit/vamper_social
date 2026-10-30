<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/libs/GiftSystem.php';

$database = new Database();
$db = $database->getConnection();
$userId = authenticateApiUser($db);

try {
    ensureGiftTables($db);

    $collectionQuery = $db->prepare(
        'SELECT gift_id, MAX(gift_name) AS name, MAX(gift_emoji) AS emoji,
                COUNT(*) AS quantity, MIN(created_at) AS first_received_at,
                MAX(created_at) AS last_received_at
         FROM gift_transactions
         WHERE receiver_id = :receiver_id
         GROUP BY gift_id
         ORDER BY last_received_at DESC, gift_id DESC'
    );
    $collectionQuery->execute([':receiver_id' => $userId]);

    $historyQuery = $db->prepare(
        'SELECT t.id, t.gift_name AS name, t.gift_emoji AS emoji,
                t.context_type, t.created_at,
                COALESCE(u.full_name, \'Former user\') AS sender_name
         FROM gift_transactions t
         LEFT JOIN users u ON u.id = t.sender_id
         WHERE t.receiver_id = :receiver_id
         ORDER BY t.id DESC
         LIMIT 50'
    );
    $historyQuery->execute([':receiver_id' => $userId]);

    $summaryQuery = $db->prepare(
        'SELECT COUNT(*) AS total_gifts, COUNT(DISTINCT gift_id) AS unique_gifts
         FROM gift_transactions
         WHERE receiver_id = :receiver_id'
    );
    $summaryQuery->execute([':receiver_id' => $userId]);

    echo json_encode([
        'success' => true,
        'data' => [
            'summary' => $summaryQuery->fetch(PDO::FETCH_ASSOC),
            'collection' => $collectionQuery->fetchAll(PDO::FETCH_ASSOC),
            'recent_gifts' => $historyQuery->fetchAll(PDO::FETCH_ASSOC),
        ],
    ], JSON_UNESCAPED_UNICODE);
} catch (Throwable $error) {
    error_log('Unable to load gift collection: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Unable to load your gift collection right now.',
    ]);
}
