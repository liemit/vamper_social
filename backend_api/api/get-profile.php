<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

// Get user_id and optional viewer_id
$user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null;
$viewer_id = isset($_GET['viewer_id']) ? $_GET['viewer_id'] : (isset($_GET['current_user_id']) ? $_GET['current_user_id'] : null);

if (empty($user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID is required."]);
    exit;
}

// Check hard block between viewer and target user
if (!empty($viewer_id) && $viewer_id != $user_id) {
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

        $bStmt = $db->prepare("SELECT id FROM blocked_users WHERE (blocker_id = :v AND blocked_id = :u) OR (blocker_id = :u AND blocked_id = :v) LIMIT 1");
        $bStmt->execute([':v' => $viewer_id, ':u' => $user_id]);
        if ($bStmt->rowCount() > 0) {
            http_response_code(403);
            echo json_encode(["success" => false, "is_blocked" => true, "message" => "This profile is unavailable due to user blocking."]);
            exit();
        }
    } catch (Exception $e) {}
}

try {
    // Fetch public user data
    $query = "SELECT id, full_name, profile_photo, gender, date_of_birth, bio, location, is_verified, coins, created_at, active_profile_frame_id, active_party_frame_id
              FROM users
              WHERE id = :id LIMIT 1";

    $stmt = $db->prepare($query);
    $stmt->bindParam(":id", $user_id);
    $stmt->execute();

    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user) {
        http_response_code(200);
        echo json_encode([
            "success" => true,
            "data" => $user
        ]);
    } else {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "User not found."]);
    }

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
