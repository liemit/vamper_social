<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/libs/PayPalGateway.php';
require_once __DIR__ . '/libs/PayPalOrderStorage.php';

$database = new Database();
$db = $database->getConnection();
$userId = authenticateApiUser($db);
$data = json_decode(file_get_contents('php://input'), true);
$packages = paypalCoinPackages();
$coins = is_array($data) ? filter_var($data['coins'] ?? null, FILTER_VALIDATE_INT) : false;

if ($coins === false || !isset($packages[$coins])) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Select a valid coin package.']);
    exit;
}

try {
    $db->exec("CREATE TABLE IF NOT EXISTS settings (
        `key` VARCHAR(255) PRIMARY KEY,
        `value` TEXT NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    ensurePayPalCheckoutSchema($db);
    [$mode, $merchantEmail] = paypalCurrentSettings($db);

    $checkoutId = paypalCheckoutId();
    $requestId = paypalCheckoutId();
    $amount = $packages[$coins];
    $insert = $db->prepare(
        "INSERT INTO paypal_checkout_orders
            (checkout_id, paypal_request_id, user_id, mode, merchant_email, coins, amount_usd, status)
         VALUES (:checkout_id, :request_id, :user_id, :mode, :merchant, :coins, :amount, 'creating')"
    );
    $insert->execute([
        ':checkout_id' => $checkoutId,
        ':request_id' => $requestId,
        ':user_id' => $userId,
        ':mode' => $mode,
        ':merchant' => $merchantEmail,
        ':coins' => $coins,
        ':amount' => $amount,
    ]);

    $gateway = new PayPalGateway($mode);
    $paypalOrder = $gateway->createOrder(
        $checkoutId,
        $userId,
        $coins,
        $amount,
        $merchantEmail,
        $requestId
    );
    $paypalOrderId = $paypalOrder['id'] ?? null;
    $approvalUrl = null;
    foreach (($paypalOrder['links'] ?? []) as $link) {
        if (in_array($link['rel'] ?? '', ['approve', 'payer-action'], true)) {
            $approvalUrl = $link['href'] ?? null;
            break;
        }
    }

    if (
        ($paypalOrder['status'] ?? null) !== 'CREATED'
        || !is_string($paypalOrderId)
        || !preg_match('/^[A-Z0-9-]{1,64}$/', $paypalOrderId)
        || !is_string($approvalUrl)
        || !str_starts_with($approvalUrl, 'https://')
    ) {
        throw new RuntimeException('PayPal did not return a valid approval link.');
    }

    $update = $db->prepare(
        "UPDATE paypal_checkout_orders
         SET paypal_order_id = :paypal_order_id, approval_url = :approval_url, status = 'pending'
         WHERE checkout_id = :checkout_id AND user_id = :user_id"
    );
    $update->execute([
        ':paypal_order_id' => $paypalOrderId,
        ':approval_url' => $approvalUrl,
        ':checkout_id' => $checkoutId,
        ':user_id' => $userId,
    ]);

    echo json_encode([
        'success' => true,
        'data' => [
            'checkout_id' => $checkoutId,
            'approval_url' => $approvalUrl,
            'coins' => $coins,
            'amount_usd' => $amount,
            'currency' => 'USD',
            'mode' => $mode,
        ],
    ]);
} catch (DomainException $error) {
    if (isset($checkoutId)) {
        try {
            $db->prepare(
                "UPDATE paypal_checkout_orders SET status = 'failed'
                 WHERE checkout_id = :checkout_id AND status IN ('creating', 'pending')"
            )->execute([':checkout_id' => $checkoutId]);
        } catch (Throwable $storageError) {
            error_log('Unable to close failed PayPal checkout: ' . $storageError->getMessage());
        }
    }
    http_response_code(409);
    echo json_encode(['success' => false, 'message' => $error->getMessage()]);
} catch (Throwable $error) {
    if (isset($checkoutId)) {
        try {
            $db->prepare(
                "UPDATE paypal_checkout_orders SET status = 'failed'
                 WHERE checkout_id = :checkout_id AND status IN ('creating', 'pending')"
            )->execute([':checkout_id' => $checkoutId]);
        } catch (Throwable $storageError) {
            error_log('Unable to close failed PayPal checkout: ' . $storageError->getMessage());
        }
    }
    error_log('Unable to create PayPal order: ' . $error->getMessage());
    http_response_code(503);
    echo json_encode([
        'success' => false,
        'message' => $error instanceof RuntimeException
            ? $error->getMessage()
            : 'Unable to start PayPal checkout. Please try again later.',
    ]);
}