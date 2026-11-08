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
    $giftQuery = $db->query(
        'SELECT id, gift_key, name, emoji, price_coins
         FROM gift_catalog WHERE is_active = 1 ORDER BY sort_order, id'
    );
    $balanceQuery = $db->prepare('SELECT coins FROM users WHERE id = :id');
    $balanceQuery->execute([':id' => $userId]);
    $balance = $balanceQuery->fetchColumn();
    if ($balance === false) {
        throw new RuntimeException('Authenticated account could not be found.');
    }

    echo json_encode([
        'success' => true,
        'data' => $giftQuery->fetchAll(PDO::FETCH_ASSOC),
        'coins' => (int)$balance,
    ], JSON_UNESCAPED_UNICODE);
} catch (Throwable $error) {
    error_log('Unable to load gift catalog: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to load gifts right now.']);
}
