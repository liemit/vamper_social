<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

$user_id = $data->user_id ?? ($_GET['user_id'] ?? null);
$mode = $data->mode ?? ($_GET['mode'] ?? 'soul'); // 'soul' or 'voice'
$action = $data->action ?? ($_GET['action'] ?? 'ping'); // 'ping' or 'leave'

if (empty($user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID required."]);
    exit();
}

try {
    // Ensure match_queue table exists
    $db->exec("CREATE TABLE IF NOT EXISTS match_queue (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        mode VARCHAR(20) NOT NULL COMMENT 'soul or voice',
        last_ping TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY unique_queue (user_id, mode)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    if ($action === 'leave') {
        $stmt = $db->prepare("DELETE FROM match_queue WHERE user_id = :uid AND mode = :mode");
        $stmt->execute([':uid' => $user_id, ':mode' => $mode]);
        http_response_code(200);
        echo json_encode(["success" => true, "message" => "Left match queue."]);
        exit();
    }

    // Default 'ping' action: Insert or Update last_ping timestamp
    $stmt = $db->prepare("INSERT INTO match_queue (user_id, mode, last_ping)
                          VALUES (:uid, :mode, NOW())
                          ON DUPLICATE KEY UPDATE last_ping = NOW()");
    $stmt->execute([':uid' => $user_id, ':mode' => $mode]);

    http_response_code(200);
    echo json_encode(["success" => true, "message" => "Match queue ping recorded."]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
