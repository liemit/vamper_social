<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/libs/ChatPresence.php';

$database = new Database();
$db = $database->getConnection();
$userId = authenticateApiUser($db);
$data = json_decode(file_get_contents('php://input'), true) ?? [];
$action = $data['action'] ?? null;

if (!in_array($action, ['heartbeat', 'offline'], true)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Invalid presence action.']);
    exit();
}

try {
    ensureChatPresenceTable($db);

    if ($action === 'heartbeat') {
        $stmt = $db->prepare(
            "INSERT INTO user_presence (user_id, last_seen, is_active)
             VALUES (:user_id, UTC_TIMESTAMP(), 1)
             ON DUPLICATE KEY UPDATE last_seen = UTC_TIMESTAMP(), is_active = 1"
        );
    } else {
        $stmt = $db->prepare(
            "UPDATE user_presence
             SET last_seen = UTC_TIMESTAMP(), is_active = 0
             WHERE user_id = :user_id"
        );
    }

    $stmt->execute([':user_id' => $userId]);

    echo json_encode(['success' => true]);
} catch (PDOException $error) {
    error_log('Unable to update chat presence: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to update presence.']);
}
