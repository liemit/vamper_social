<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();
authenticateApiUser($db);

try {
    $db->exec("CREATE TABLE IF NOT EXISTS settings (
        `key` VARCHAR(255) PRIMARY KEY,
        `value` TEXT NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $stmt = $db->prepare("SELECT `value` FROM settings WHERE `key` = 'paypal_mode' LIMIT 1");
    $stmt->execute();
    $paymentMode = $stmt->fetchColumn() ?: 'sandbox';
    if (!in_array($paymentMode, ['sandbox', 'live'], true)) {
        throw new UnexpectedValueException('Unsupported PayPal payment mode in settings.');
    }

    echo json_encode([
        'success' => true,
        'data' => [
            'payment_mode' => $paymentMode,
            'live_checkout_enabled' => false,
        ],
    ]);
} catch (PDOException $error) {
    error_log('Unable to read PayPal payment settings: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Unable to load payment settings.',
    ]);
} catch (UnexpectedValueException $error) {
    error_log('Invalid PayPal payment mode: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Payment settings contain an unsupported mode.',
    ]);
}
