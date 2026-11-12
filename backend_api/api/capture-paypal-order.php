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
$checkoutId = is_array($data) ? trim((string)($data['checkout_id'] ?? '')) : '';

if (!preg_match('/^[a-f0-9-]{36}$/i', $checkoutId)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid checkout reference.']);
    exit;
}

try {
    ensurePayPalCheckoutSchema($db);
    $orderQuery = $db->prepare(
        'SELECT * FROM paypal_checkout_orders
         WHERE checkout_id = :checkout_id AND user_id = :user_id LIMIT 1'
    );
    $orderQuery->execute([':checkout_id' => $checkoutId, ':user_id' => $userId]);
    $checkout = $orderQuery->fetch(PDO::FETCH_ASSOC);
    if (!$checkout) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'PayPal checkout was not found.']);
        exit;
    }

    if ($checkout['status'] === 'completed') {
        $balanceQuery = $db->prepare('SELECT coins FROM users WHERE id = :id AND is_active = 1');
        $balanceQuery->execute([':id' => $userId]);
        $balance = $balanceQuery->fetchColumn();
        echo json_encode([
            'success' => true,
            'message' => 'This PayPal order was already processed.',
            'data' => ['coins' => (int)$checkout['coins'], 'balance' => (int)$balance, 'already_processed' => true],
        ]);
        exit;
    }
    if ($checkout['status'] !== 'pending' || empty($checkout['paypal_order_id'])) {
        http_response_code(409);
        echo json_encode(['success' => false, 'message' => 'This PayPal checkout is not ready to capture.']);
        exit;
    }

    $db->exec("CREATE TABLE IF NOT EXISTS settings (
        `key` VARCHAR(255) PRIMARY KEY,
        `value` TEXT NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    [$currentMode] = paypalCurrentSettings($db);
    if ($currentMode !== $checkout['mode']) {
        http_response_code(409);
        echo json_encode([
            'success' => false,
            'message' => 'Payment mode changed during checkout. Start a new order in the current mode.',
        ]);
        exit;
    }

    $packages = paypalCoinPackages();
    $checkoutCoins = (int)$checkout['coins'];
    if (
        ($checkout['currency'] ?? null) !== 'USD'
        || !isset($packages[$checkoutCoins])
        || !paypalAmountMatches((string)$checkout['amount_usd'], $packages[$checkoutCoins])
    ) {
        throw new DomainException('The stored PayPal package does not match an available package.');
    }

    $gateway = new PayPalGateway($checkout['mode']);
    $expectedAmount = $packages[$checkoutCoins];
    $paypalOrder = $gateway->getOrder($checkout['paypal_order_id']);
    if (($paypalOrder['status'] ?? null) === 'APPROVED') {
        verifyPayPalOrder(
            $paypalOrder,
            $checkout['paypal_order_id'],
            $checkoutId,
            $userId,
            $expectedAmount,
            $checkout['merchant_email'],
            false
        );
        $paypalOrder = $gateway->captureOrder(
            $checkout['paypal_order_id'],
            substr(hash('sha256', 'capture:' . $checkoutId), 0, 36)
        );
    }

    $capture = verifyPayPalOrder(
        $paypalOrder,
        $checkout['paypal_order_id'],
        $checkoutId,
        $userId,
        $expectedAmount,
        $checkout['merchant_email'],
        true
    );

    $db->beginTransaction();
    $lockedQuery = $db->prepare(
        'SELECT * FROM paypal_checkout_orders WHERE checkout_id = :checkout_id FOR UPDATE'
    );
    $lockedQuery->execute([':checkout_id' => $checkoutId]);
    $lockedCheckout = $lockedQuery->fetch(PDO::FETCH_ASSOC);
    if (!$lockedCheckout) {
        throw new RuntimeException('PayPal checkout record disappeared.');
    }
    if ($lockedCheckout['status'] === 'completed') {
        $balanceQuery = $db->prepare('SELECT coins FROM users WHERE id = :id AND is_active = 1');
        $balanceQuery->execute([':id' => $userId]);
        $balance = $balanceQuery->fetchColumn();
        $db->commit();
        echo json_encode([
            'success' => true,
            'message' => 'This PayPal order was already processed.',
            'data' => ['coins' => (int)$checkout['coins'], 'balance' => (int)$balance, 'already_processed' => true],
        ]);
        exit;
    }
    if ($lockedCheckout['status'] !== 'pending') {
        throw new DomainException('This PayPal checkout has already been closed.');
    }

    $balanceQuery = $db->prepare('SELECT coins FROM users WHERE id = :id AND is_active = 1 FOR UPDATE');
    $balanceQuery->execute([':id' => $userId]);
    $balanceBefore = $balanceQuery->fetchColumn();
    if ($balanceBefore === false) {
        throw new DomainException('User account is unavailable.');
    }

    $coins = (int)$checkout['coins'];
    $balanceAfter = (int)$balanceBefore + $coins;
    $db->prepare('UPDATE users SET coins = :coins WHERE id = :id')
        ->execute([':coins' => $balanceAfter, ':id' => $userId]);

    $isSandbox = $checkout['mode'] === 'sandbox';
    $transactionStatus = $isSandbox ? 'sandbox_mock' : 'completed';
    $gatewayName = $isSandbox ? 'PayPal Sandbox' : 'PayPal';
    $db->prepare(
        'INSERT INTO transactions (user_id, amount_usd, coins, gateway, status, created_at)
         VALUES (:user, :amount, :coins, :gateway, :status, NOW())'
    )->execute([
        ':user' => $userId,
        ':amount' => $checkout['amount_usd'],
        ':coins' => $coins,
        ':gateway' => $gatewayName,
        ':status' => $transactionStatus,
    ]);
    $transactionId = (int)$db->lastInsertId();

    recordVpcLedger(
        $db,
        $userId,
        $coins,
        (int)$balanceBefore,
        $balanceAfter,
        $isSandbox ? 'paypal_sandbox_topup' : 'paypal_topup',
        $isSandbox ? 'PayPal Sandbox order capture' : 'PayPal order capture',
        $capture['id']
    );

    $db->prepare(
        "UPDATE paypal_checkout_orders
         SET status = 'completed', capture_id = :capture_id,
             transaction_id = :transaction_id, completed_at = NOW()
         WHERE checkout_id = :checkout_id"
    )->execute([
        ':capture_id' => $capture['id'],
        ':transaction_id' => $transactionId,
        ':checkout_id' => $checkoutId,
    ]);
    $db->commit();

    echo json_encode([
        'success' => true,
        'message' => $isSandbox
            ? "PayPal Sandbox order verified. Added $coins test VPC."
            : "PayPal payment verified. Added $coins VPC.",
        'data' => ['coins' => $coins, 'balance' => $balanceAfter, 'already_processed' => false],
    ]);
} catch (DomainException $error) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(409);
    echo json_encode(['success' => false, 'message' => $error->getMessage()]);
} catch (Throwable $error) {
    if ($db->inTransaction()) $db->rollBack();
    error_log('PayPal capture processing failed: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $error instanceof RuntimeException
            ? $error->getMessage()
            : 'Unable to verify the PayPal payment. Please try again.',
    ]);
}