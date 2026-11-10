<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/libs/PayPalGateway.php';

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
    $merchantStmt = $db->prepare("SELECT `value` FROM settings WHERE `key` = 'paypal_email' LIMIT 1");
    $merchantStmt->execute();
    $merchantEmail = $merchantStmt->fetchColumn();
    $checkoutEnabled = is_string($merchantEmail)
        && filter_var($merchantEmail, FILTER_VALIDATE_EMAIL) !== false
        && PayPalGateway::isConfigured($paymentMode);

    echo json_encode([
        'success' => true,
        'data' => [
            'payment_mode' => $paymentMode,
            'checkout_enabled' => $checkoutEnabled,
            'live_checkout_enabled' => $checkoutEnabled && $paymentMode === 'live',
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
