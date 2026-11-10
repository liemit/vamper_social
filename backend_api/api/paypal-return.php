<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/PayPalOrderStorage.php';

$checkoutId = trim((string)($_GET['checkout'] ?? ''));
$paypalOrderId = trim((string)($_GET['token'] ?? ''));
$isCancelled = isset($_GET['cancel']);
$title = 'Vamper checkout';
$message = 'This checkout link is invalid or has expired.';
$statusCode = 400;

if (preg_match('/^[a-f0-9-]{36}$/i', $checkoutId)) {
    try {
        $database = new Database();
        $db = $database->getConnection();
        ensurePayPalCheckoutSchema($db);
        $stmt = $db->prepare(
            'SELECT paypal_order_id, status FROM paypal_checkout_orders
             WHERE checkout_id = :checkout_id LIMIT 1'
        );
        $stmt->execute([':checkout_id' => $checkoutId]);
        $order = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($order && $isCancelled) {
            $cancel = $db->prepare(
                "UPDATE paypal_checkout_orders SET status = 'cancelled'
                 WHERE checkout_id = :checkout_id AND status = 'pending'"
            );
            $cancel->execute([':checkout_id' => $checkoutId]);
            $title = 'Checkout cancelled';
            $message = 'No payment was captured. Return to Vamper if you want to try again.';
            $statusCode = 200;
        } elseif (
            $order
            && is_string($paypalOrderId)
            && $paypalOrderId !== ''
            && hash_equals((string)$order['paypal_order_id'], $paypalOrderId)
            && $order['status'] === 'pending'
        ) {
            $title = 'Return to Vamper';
            $message = 'PayPal returned you to Vamper. Go back to the app and tap “Verify payment” to confirm the order and add your coins.';
            $statusCode = 200;
        } elseif ($order && $order['status'] === 'completed') {
            $title = 'Payment complete';
            $message = 'This order has already been verified. Return to Vamper to see your coin balance.';
            $statusCode = 200;
        }
    } catch (Throwable $error) {
        error_log('PayPal return page failed: ' . $error->getMessage());
        $title = 'Checkout unavailable';
        $message = 'We could not load this checkout status. Return to Vamper and retry verification.';
        $statusCode = 503;
    }
}

http_response_code($statusCode);
header('Content-Type: text/html; charset=UTF-8');
$escapedTitle = htmlspecialchars($title, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
$escapedMessage = htmlspecialchars($message, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
echo '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    . '<title>' . $escapedTitle . '</title><body style="font:16px system-ui;max-width:560px;margin:12vh auto;padding:24px;color:#263238">'
    . '<h1>' . $escapedTitle . '</h1><p>' . $escapedMessage . '</p></body></html>';