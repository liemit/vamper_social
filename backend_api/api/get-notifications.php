<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null;

if (empty($user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID is required."]);
    exit();
}

try {
    // Ensure notifications table exists
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

    $stmt = $db->prepare("SELECT id, sender_id, type, title, body, is_read, created_at
                          FROM notifications
                          WHERE user_id = :uid AND is_read = 0
                          ORDER BY created_at DESC");
    $stmt->execute([':uid' => $user_id]);
    $notifications = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Mark as read after fetching so they show once as push alerts
    $upd = $db->prepare("UPDATE notifications SET is_read = 1 WHERE user_id = :uid AND is_read = 0");
    $upd->execute([':uid' => $user_id]);

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "data" => $notifications
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
