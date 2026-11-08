<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/../libs/AdminTools.php';

$database = new Database();
$db = $database->getConnection();
$authenticatedUserId = authenticateApiUser($db);
$data = json_decode(file_get_contents('php://input'));
$coins = filter_var($data->coins ?? null, FILTER_VALIDATE_INT);
$amountUsd = filter_var($data->amount_usd ?? null, FILTER_VALIDATE_FLOAT);
$paymentToken = trim($data->payment_token ?? '');
$userId = filter_var($data->user_id ?? null, FILTER_VALIDATE_INT);

$packages = [100 => 4.99, 500 => 19.99, 1200 => 39.99, 3000 => 89.99];
if (
    !is_object($data)
    || !$userId
    || $userId !== $authenticatedUserId
    || $coins === false
    || !isset($packages[$coins])
    || $amountUsd === false
    || abs($packages[$coins] - $amountUsd) > 0.001
    || !preg_match('/^pp_sandbox_[a-zA-Z0-9_-]{1,80}$/', $paymentToken)
) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid sandbox checkout parameters.']);
    exit;
}

try {
    if (!adminTableExists($db, 'settings')) {
        $db->exec("CREATE TABLE IF NOT EXISTS settings (
            `key` VARCHAR(255) PRIMARY KEY,
            `value` TEXT NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    }
    $modeQuery = $db->prepare("SELECT `value` FROM settings WHERE `key` = 'paypal_mode' LIMIT 1");
    $modeQuery->execute();
    $paymentMode = $modeQuery->fetchColumn() ?: 'sandbox';
    if ($paymentMode !== 'sandbox') {
        http_response_code(503);
        echo json_encode([
            'success' => false,
            'message' => 'Live payment verification is not configured. No coins were credited.',
        ]);
        exit;
    }

    ensureVpcLedgerTable($db);
    if (!adminTableExists($db, 'processed_sandbox_payments')) {
        $db->exec("CREATE TABLE IF NOT EXISTS processed_sandbox_payments (
            payment_token VARCHAR(100) NOT NULL PRIMARY KEY,
            user_id INT NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    }

    $db->beginTransaction();
    $db->prepare('INSERT INTO processed_sandbox_payments (payment_token, user_id) VALUES (:token, :user)')
        ->execute([':token' => $paymentToken, ':user' => $userId]);

    $balanceQuery = $db->prepare('SELECT coins FROM users WHERE id = :id AND is_active = 1 FOR UPDATE');
    $balanceQuery->execute([':id' => $userId]);
    $balanceBefore = $balanceQuery->fetchColumn();
    if ($balanceBefore === false) {
        throw new DomainException('User account is unavailable.');
    }

    $db->prepare('UPDATE users SET coins = coins + :coins WHERE id = :id')
        ->execute([':coins' => $coins, ':id' => $userId]);
    $db->prepare(
        "INSERT INTO transactions (user_id, amount_usd, coins, gateway, status, created_at)
         VALUES (:user, :amount, :coins, 'PayPal Sandbox (mock)', 'sandbox_mock', NOW())"
    )->execute([':user' => $userId, ':amount' => $amountUsd, ':coins' => $coins]);
    $transactionId = (string)$db->lastInsertId();
    recordVpcLedger(
        $db,
        $userId,
        $coins,
        (int)$balanceBefore,
        (int)$balanceBefore + $coins,
        'sandbox_mock_topup',
        'Sandbox-only simulated coin package',
        $transactionId
    );
    $userQuery = $db->prepare(
        'SELECT id, full_name, email, role, gender, date_of_birth, bio, profile_photo,
                location, is_verified, coins, is_active, created_at
         FROM users WHERE id = :id LIMIT 1'
    );
    $userQuery->execute([':id' => $userId]);
    $user = $userQuery->fetch(PDO::FETCH_ASSOC);
    $db->commit();

    echo json_encode([
        'success' => true,
        'message' => "Sandbox test: added $coins VPC. This does not represent a real PayPal payment.",
        'data' => ['user' => $user],
    ]);
} catch (DomainException $error) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $error->getMessage()]);
} catch (PDOException $error) {
    if ($db->inTransaction()) $db->rollBack();
    if ($error->getCode() === '23000') {
        http_response_code(409);
        echo json_encode(['success' => false, 'message' => 'This sandbox payment token was already processed.']);
        exit;
    }
    error_log('Sandbox payment processing failed: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to process the sandbox checkout.']);
}
