<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$method = $_SERVER['REQUEST_METHOD'];

// Ensure table exists
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

if ($method === 'GET') {
    $user_id = $_GET['user_id'] ?? ($_GET['blocker_id'] ?? null);
    if (empty($user_id)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "User ID required."]);
        exit();
    }

    try {
        $stmt = $db->prepare("SELECT u.id, u.full_name, u.profile_photo, u.gender, u.is_verified
                              FROM blocked_users b
                              JOIN users u ON b.blocked_id = u.id
                              WHERE b.blocker_id = :uid");
        $stmt->execute([':uid' => $user_id]);
        $blockedUsers = $stmt->fetchAll(PDO::FETCH_ASSOC);

        http_response_code(200);
        echo json_encode(["success" => true, "data" => $blockedUsers]);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
    }
    exit();
}

$data = json_decode(file_get_contents("php://input"));
$blocker_id = $data->blocker_id ?? null;
$blocked_id = $data->blocked_id ?? null;
$action = $data->action ?? 'block'; // 'block' or 'unblock'

if (empty($blocker_id) || empty($blocked_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Blocker ID and Blocked ID are required."]);
    exit();
}

try {
    if ($action === 'unblock') {
        $stmt = $db->prepare("DELETE FROM blocked_users WHERE blocker_id = :bid AND blocked_id = :boid");
        $stmt->execute([':bid' => $blocker_id, ':boid' => $blocked_id]);
        $msg = "User unblocked successfully.";
    } else {
        $stmt = $db->prepare("INSERT IGNORE INTO blocked_users (blocker_id, blocked_id) VALUES (:bid, :boid)");
        $stmt->execute([':bid' => $blocker_id, ':boid' => $blocked_id]);
        $msg = "User blocked successfully.";
    }

    http_response_code(200);
    echo json_encode(["success" => true, "message" => $msg]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
