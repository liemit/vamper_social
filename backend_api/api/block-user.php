<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

// Ensure blocked_users table exists
try {
    $db->exec("CREATE TABLE IF NOT EXISTS blocked_users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        blocker_id INT NOT NULL,
        blocked_id INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_block (blocker_id, blocked_id),
        INDEX idx_blocker (blocker_id),
        INDEX idx_blocked (blocked_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");
} catch (Exception $e) {}

$data = json_decode(file_get_contents("php://input"));
$action = $data->action ?? ($_GET['action'] ?? 'block');
$blocker_id = $data->blocker_id ?? ($_GET['blocker_id'] ?? null);
$blocked_id = $data->blocked_id ?? ($_GET['blocked_id'] ?? null);

if ($action === 'list') {
    if (empty($blocker_id)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Blocker ID required."]);
        exit();
    }
    try {
        $stmt = $db->prepare("SELECT b.blocked_id as id, u.full_name, u.profile_photo, u.email
                              FROM blocked_users b
                              JOIN users u ON b.blocked_id = u.id
                              WHERE b.blocker_id = :bid
                              ORDER BY b.created_at DESC");
        $stmt->execute([':bid' => $blocker_id]);
        $list = $stmt->fetchAll(PDO::FETCH_ASSOC);

        http_response_code(200);
        echo json_encode(["success" => true, "data" => $list]);
        exit();
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
        exit();
    }
}

if (empty($blocker_id) || empty($blocked_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Blocker ID and Blocked ID are required."]);
    exit();
}

try {
    if ($action === 'block') {
        $stmt = $db->prepare("INSERT INTO blocked_users (blocker_id, blocked_id, created_at)
                              VALUES (:bid, :target, NOW())
                              ON DUPLICATE KEY UPDATE created_at = NOW()");
        $stmt->execute([':bid' => $blocker_id, ':target' => $blocked_id]);
        $msg = "User blocked successfully.";
    } else if ($action === 'unblock') {
        $stmt = $db->prepare("DELETE FROM blocked_users WHERE blocker_id = :bid AND blocked_id = :target");
        $stmt->execute([':bid' => $blocker_id, ':target' => $blocked_id]);
        $msg = "User unblocked successfully.";
    } else {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Invalid action."]);
        exit();
    }

    http_response_code(200);
    echo json_encode(["success" => true, "message" => $msg]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
