<?php
require_once __DIR__ . '/../../libs/AdminTools.php';

function ensurePayPalCheckoutSchema(PDO $db): void
{
    $db->exec("CREATE TABLE IF NOT EXISTS paypal_checkout_orders (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        checkout_id CHAR(36) NOT NULL UNIQUE,
        paypal_order_id VARCHAR(64) NULL UNIQUE,
        paypal_request_id VARCHAR(38) NOT NULL UNIQUE,
        capture_id VARCHAR(64) NULL UNIQUE,
        user_id INT NOT NULL,
        mode ENUM('sandbox','live') NOT NULL,
        merchant_email VARCHAR(255) NOT NULL,
        coins INT NOT NULL,
        amount_usd DECIMAL(10,2) NOT NULL,
        currency CHAR(3) NOT NULL DEFAULT 'USD',
        approval_url TEXT NULL,
        status VARCHAR(24) NOT NULL DEFAULT 'creating',
        transaction_id INT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        completed_at DATETIME NULL,
        KEY idx_paypal_checkout_user (user_id, created_at),
        KEY idx_paypal_checkout_status (status, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    if (!adminTableExists($db, 'transactions')) {
        $db->exec("CREATE TABLE IF NOT EXISTS transactions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            amount_usd DECIMAL(10,2) NOT NULL,
            coins INT NOT NULL,
            gateway VARCHAR(50) DEFAULT 'PayPal',
            status VARCHAR(50) DEFAULT 'completed',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    }
    ensureVpcLedgerTable($db);
}

function paypalCheckoutId(): string
{
    $bytes = random_bytes(16);
    $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
    $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
    $hex = bin2hex($bytes);
    return substr($hex, 0, 8) . '-' . substr($hex, 8, 4) . '-'
        . substr($hex, 12, 4) . '-' . substr($hex, 16, 4) . '-' . substr($hex, 20);
}

function paypalCoinPackages(): array
{
    return [100 => '4.99', 500 => '19.99', 1200 => '39.99', 3000 => '89.99'];
}

function paypalAmountMatches(mixed $actual, string $expected): bool
{
    if (
        !is_string($actual)
        || !preg_match('/^(0|[1-9][0-9]*)(?:\\.([0-9]{1,2}))?$/D', $actual, $actualParts)
        || !preg_match('/^(0|[1-9][0-9]*)\\.([0-9]{2})$/D', $expected, $expectedParts)
    ) {
        return false;
    }

    $actualDollars = ltrim($actualParts[1], '0') ?: '0';
    $actualCents = str_pad($actualParts[2] ?? '', 2, '0');
    return $actualDollars === $expectedParts[1] && $actualCents === $expectedParts[2];
}

function paypalCurrentSettings(PDO $db): array
{
    $modeStmt = $db->prepare("SELECT `value` FROM settings WHERE `key` = 'paypal_mode' LIMIT 1");
    $modeStmt->execute();
    $mode = $modeStmt->fetchColumn() ?: 'sandbox';
    $merchantStmt = $db->prepare("SELECT `value` FROM settings WHERE `key` = 'paypal_email' LIMIT 1");
    $merchantStmt->execute();
    $merchantEmail = $merchantStmt->fetchColumn();

    if (!in_array($mode, ['sandbox', 'live'], true)) {
        throw new RuntimeException('The configured PayPal mode is invalid.');
    }
    if (!is_string($merchantEmail) || filter_var($merchantEmail, FILTER_VALIDATE_EMAIL) === false) {
        throw new RuntimeException('A valid PayPal merchant email must be configured in Admin.');
    }
    if (!PayPalGateway::isConfigured($mode)) {
        throw new RuntimeException('PayPal credentials or the HTTPS return URL are not configured for this mode.');
    }
    return [$mode, $merchantEmail];
}

function verifyPayPalOrder(
    array $paypalOrder,
    string $paypalOrderId,
    string $checkoutId,
    int $userId,
    string $amount,
    string $merchantEmail,
    bool $requireCompleted
): array {
    if (($paypalOrder['status'] ?? null) !== ($requireCompleted ? 'COMPLETED' : 'APPROVED')) {
        throw new DomainException($requireCompleted
            ? 'PayPal has not completed this payment.'
            : 'Approve the payment in PayPal before continuing.');
    }

    $purchaseUnits = $paypalOrder['purchase_units'] ?? null;
    if (!is_array($purchaseUnits) || count($purchaseUnits) !== 1) {
        throw new DomainException('PayPal order does not match the expected purchase.');
    }
    $purchase = $purchaseUnits[0];
    $payeeEmail = $purchase['payee']['email_address'] ?? null;
    $paypalAmount = $purchase['amount'] ?? [];
    if (
        ($paypalOrder['id'] ?? null) !== $paypalOrderId
        || ($purchase['reference_id'] ?? null) !== $checkoutId
        || ($purchase['custom_id'] ?? null) !== (string)$userId
        || ($purchase['invoice_id'] ?? null) !== $checkoutId
        || !is_string($payeeEmail)
        || strcasecmp($payeeEmail, $merchantEmail) !== 0
        || ($paypalAmount['currency_code'] ?? null) !== 'USD'
        || !paypalAmountMatches($paypalAmount['value'] ?? null, $amount)
    ) {
        throw new DomainException('PayPal order recipient, currency, amount, or account does not match.');
    }

    if (!$requireCompleted) {
        return [];
    }

    $captures = $purchase['payments']['captures'] ?? null;
    if (!is_array($captures) || count($captures) !== 1) {
        error_log('PayPal order verification failed: expected exactly one capture.');
        throw new DomainException(
            'PayPal did not return exactly one capture. No coins were credited; contact support if your Sandbox balance was charged.'
        );
    }
    $capture = $captures[0];
    $captureAmount = $capture['amount'] ?? [];
    $captureStatus = $capture['status'] ?? 'missing';
    if ($captureStatus !== 'COMPLETED') {
        error_log('PayPal order verification failed: capture status ' . $captureStatus . '.');
        throw new DomainException(
            'PayPal capture status is ' . $captureStatus . '; coins were not credited. Check Sandbox Activity and retry verification if the payment later completes.'
        );
    }
    if (!is_string($capture['id'] ?? null) || $capture['id'] === '') {
        error_log('PayPal order verification failed: capture ID is missing.');
        throw new DomainException(
            'PayPal did not return a capture ID. No coins were credited; contact support before retrying payment.'
        );
    }
    if (($captureAmount['currency_code'] ?? null) !== 'USD') {
        error_log('PayPal order verification failed: capture currency did not match USD.');
        throw new DomainException(
            'PayPal capture currency did not match the order. No coins were credited; contact support before retrying payment.'
        );
    }
    if (!paypalAmountMatches($captureAmount['value'] ?? null, $amount)) {
        error_log(
            'PayPal order verification failed: capture amount did not match the expected package amount.'
        );
        throw new DomainException(
            'PayPal capture amount did not match the package. No coins were credited; contact support before retrying payment.'
        );
    }
    return $capture;
}
