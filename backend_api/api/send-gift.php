<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/libs/GiftSystem.php';

$database = new Database();
$db = $database->getConnection();
$senderId = authenticateApiUser($db);
$data = json_decode(file_get_contents('php://input'), true);

$giftId = filter_var($data['gift_id'] ?? null, FILTER_VALIDATE_INT);
$receiverId = filter_var($data['receiver_id'] ?? null, FILTER_VALIDATE_INT);
$contextId = filter_var($data['context_id'] ?? 0, FILTER_VALIDATE_INT);
$contextType = (string)($data['context_type'] ?? '');
$requestId = (string)($data['request_id'] ?? '');

if (!$giftId || !$receiverId || $contextId === false || $contextId < 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Gift, recipient, and destination are required.']);
    exit();
}

try {
    ensureGiftTables($db);
    $gift = sendGiftTransaction(
        $db,
        $senderId,
        $receiverId,
        $giftId,
        $contextType,
        $contextId,
        $requestId
    );
    echo json_encode(['success' => true, 'data' => $gift], JSON_UNESCAPED_UNICODE);
} catch (InvalidArgumentException $error) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $error->getMessage()]);
} catch (DomainException $error) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $error->getMessage()]);
} catch (Throwable $error) {
    error_log('Unable to send gift: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to send this gift right now.']);
}
