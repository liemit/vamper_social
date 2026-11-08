<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/../libs/AdminTools.php';
require_once __DIR__ . '/libs/GooglePlayBilling.php';

$database = new Database();
$db = $database->getConnection();
$userId = authenticateApiUser($db);
$data = json_decode(file_get_contents('php://input'));

$products = [
    'vamper_coins_100' => 100,
    'vamper_coins_500' => 500,
    'vamper_coins_1200' => 1200,
    'vamper_coins_3000' => 3000,
];
$productId = is_object($data) ? trim((string)($data->product_id ?? '')) : '';
$purchaseToken = is_object($data) ? trim((string)($data->purchase_token ?? '')) : '';
$clientAccountId = is_object($data) ? trim((string)($data->obfuscated_account_id ?? '')) : '';
$expectedAccountId = hash('sha256', 'vamper-user-' . $userId);

if (!isset($products[$productId]) || $purchaseToken === '' || strlen($purchaseToken) > 2048
    || !hash_equals($expectedAccountId, $clientAccountId)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid Google Play purchase details.']);
    exit();
}

try {
    $settings = googlePlayBillingSettings();
    $packagePath = rawurlencode($settings['package_name']);
    $productPath = rawurlencode($productId);
    $tokenPath = rawurlencode($purchaseToken);
    $purchase = googlePlayApiRequest(
        $settings,
        'GET',
        "/androidpublisher/v3/applications/$packagePath/purchases/products/$productPath/tokens/$tokenPath"
    );

    if (!isset($purchase['purchaseState']) || (int)$purchase['purchaseState'] !== 0) {
        http_response_code(409);
        echo json_encode(['success' => false, 'message' => 'Google Play has not confirmed this purchase.']);
        exit();
    }

    $googleAccountId = $purchase['externalAccountIdentifiers']['obfuscatedExternalAccountId'] ?? null;
    if (!is_string($googleAccountId) || !hash_equals($expectedAccountId, $googleAccountId)) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'This purchase is not linked to the signed-in account.']);
        exit();
    }

    ensureVpcLedgerTable($db);
    $db->exec("CREATE TABLE IF NOT EXISTS google_play_purchases (
        purchase_token_hash CHAR(64) NOT NULL PRIMARY KEY,
        user_id INT NOT NULL,
        product_id VARCHAR(100) NOT NULL,
        order_id VARCHAR(100) NULL,
        coins INT UNSIGNED NOT NULL,
        price_amount_micros BIGINT NULL,
        price_currency_code CHAR(3) NULL,
        purchase_time_millis BIGINT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        KEY idx_google_play_user_created (user_id, created_at),
        KEY idx_google_play_order (order_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $tokenHash = hash('sha256', $purchaseToken);
    $coins = $products[$productId];
    $orderId = isset($purchase['orderId']) ? (string)$purchase['orderId'] : null;
    $priceMicros = isset($purchase['priceAmountMicros']) ? (int)$purchase['priceAmountMicros'] : null;
    $currencyCode = isset($purchase['priceCurrencyCode']) ? (string)$purchase['priceCurrencyCode'] : null;
    $purchaseTimeMillis = isset($purchase['purchaseTimeMillis']) ? (int)$purchase['purchaseTimeMillis'] : null;

    $db->beginTransaction();
    $existingQuery = $db->prepare('SELECT user_id, product_id FROM google_play_purchases WHERE purchase_token_hash = :token_hash FOR UPDATE');
    $existingQuery->execute([':token_hash' => $tokenHash]);
    $existingPurchase = $existingQuery->fetch(PDO::FETCH_ASSOC);
    if ($existingPurchase) {
        if ((int)$existingPurchase['user_id'] !== $userId || $existingPurchase['product_id'] !== $productId) {
            $db->rollBack();
            http_response_code(409);
            echo json_encode(['success' => false, 'message' => 'This purchase token has already been used.']);
            exit();
        }

        $balanceQuery = $db->prepare('SELECT coins FROM users WHERE id = :id AND is_active = 1 LIMIT 1');
        $balanceQuery->execute([':id' => $userId]);
        $balance = $balanceQuery->fetchColumn();
        if ($balance === false) {
            throw new DomainException('User account is unavailable.');
        }
        $db->commit();
        echo json_encode([
            'success' => true,
            'message' => 'Purchase was already credited.',
            'data' => ['coins_credited' => 0, 'balance' => (int)$balance, 'already_processed' => true],
        ]);
        exit();
    }

    $balanceQuery = $db->prepare('SELECT coins FROM users WHERE id = :id AND is_active = 1 FOR UPDATE');
    $balanceQuery->execute([':id' => $userId]);
    $balanceBefore = $balanceQuery->fetchColumn();
    if ($balanceBefore === false) {
        throw new DomainException('User account is unavailable.');
    }

    $balanceAfter = (int)$balanceBefore + $coins;
    $db->prepare('UPDATE users SET coins = :coins WHERE id = :id')
        ->execute([':coins' => $balanceAfter, ':id' => $userId]);
    $db->prepare(
        'INSERT INTO google_play_purchases
            (purchase_token_hash, user_id, product_id, order_id, coins, price_amount_micros, price_currency_code, purchase_time_millis)
         VALUES (:token_hash, :user_id, :product_id, :order_id, :coins, :price_micros, :currency, :purchase_time)'
    )->execute([
        ':token_hash' => $tokenHash,
        ':user_id' => $userId,
        ':product_id' => $productId,
        ':order_id' => $orderId,
        ':coins' => $coins,
        ':price_micros' => $priceMicros,
        ':currency' => $currencyCode,
        ':purchase_time' => $purchaseTimeMillis,
    ]);
    recordVpcLedger(
        $db,
        $userId,
        $coins,
        (int)$balanceBefore,
        $balanceAfter,
        'google_play_purchase',
        'Verified Google Play coin purchase: ' . $productId,
        $orderId ?? $tokenHash
    );
    $db->commit();

    echo json_encode([
        'success' => true,
        'message' => 'Google Play purchase verified and credited.',
        'data' => ['coins_credited' => $coins, 'balance' => $balanceAfter, 'already_processed' => false],
    ]);
} catch (DomainException $error) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $error->getMessage()]);
} catch (PDOException $error) {
    if ($db->inTransaction()) $db->rollBack();
    if ($error->getCode() === '23000') {
        http_response_code(409);
        echo json_encode(['success' => false, 'message' => 'This purchase has already been processed.']);
        exit();
    }
    error_log('Google Play purchase database operation failed: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to credit this Google Play purchase.']);
} catch (Throwable $error) {
    if ($db->inTransaction()) $db->rollBack();
    error_log('Google Play purchase verification failed: ' . $error->getMessage());
    http_response_code(503);
    echo json_encode(['success' => false, 'message' => 'Google Play purchase verification is unavailable.']);
}
?>
