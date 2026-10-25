<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

if (empty($data->follower_id) || empty($data->followed_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Follower ID and Followed ID are required."]);
    exit;
}

try {
    // Check if already following
    $stmt_check = $db->prepare("SELECT id FROM follows WHERE follower_id = :u1 AND followed_id = :u2");
    $stmt_check->bindParam(':u1', $data->follower_id);
    $stmt_check->bindParam(':u2', $data->followed_id);
    $stmt_check->execute();

    if ($stmt_check->rowCount() > 0) {
        // Unfollow
        $stmt_del = $db->prepare("DELETE FROM follows WHERE follower_id = :u1 AND followed_id = :u2");
        $stmt_del->bindParam(':u1', $data->follower_id);
        $stmt_del->bindParam(':u2', $data->followed_id);
        $stmt_del->execute();
        $is_following = false;
        $message = "Unfollowed successfully";
    } else {
        // Follow
        $stmt_ins = $db->prepare("INSERT INTO follows (follower_id, followed_id) VALUES (:u1, :u2)");
        $stmt_ins->bindParam(':u1', $data->follower_id);
        $stmt_ins->bindParam(':u2', $data->followed_id);
        $stmt_ins->execute();
        $is_following = true;
        $message = "Followed successfully";

        // Insert notification
        try {
            $db->exec("CREATE TABLE IF NOT EXISTS notifications (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                sender_id INT NULL,
                type VARCHAR(50) NOT NULL,
                title VARCHAR(255) NOT NULL,
                body TEXT NOT NULL,
                is_read INT DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_user (user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

            $notifStmt = $db->prepare("INSERT INTO notifications (user_id, sender_id, type, title, body, is_read, created_at)
                                       VALUES (:uid, :sid, 'follow', 'New Follower', 'Someone started following you!', 0, NOW())");
            $notifStmt->execute([':uid' => $data->followed_id, ':sid' => $data->follower_id]);
        } catch (Exception $e) {}
    }

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => $message,
        "data" => ["is_following" => $is_following]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
