<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

foreach (['active_profile_frame_id', 'active_party_frame_id'] as $column) {
    $columnStmt = $db->query("SHOW COLUMNS FROM users LIKE " . $db->quote($column));
    if ($columnStmt->rowCount() === 0) {
        $db->exec("ALTER TABLE users ADD COLUMN `$column` INT NULL");
    }
}

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
    $query = "SELECT u.id, u.full_name, u.profile_photo, u.gender, u.date_of_birth, u.bio,
                     u.location, u.is_verified, u.coins, u.created_at,
                     u.active_profile_frame_id, u.active_party_frame_id,
                     profile_frame.image_url AS active_profile_frame_code,
                     party_frame.image_url AS active_party_frame_code
              FROM users u
              LEFT JOIN shop_items profile_frame
                ON profile_frame.id = u.active_profile_frame_id AND profile_frame.type = 'profile_frame'
              LEFT JOIN shop_items party_frame
                ON party_frame.id = u.active_party_frame_id AND party_frame.type = 'party_frame'
              WHERE u.id = :id LIMIT 1";

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
