<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

$user_id = $data->user_id ?? null;
$post_id = $data->post_id ?? null;
$reason = trim($data->reason ?? '');
$description = trim($data->description ?? '');

if (empty($user_id) || empty($post_id) || empty($reason)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Missing required fields (user_id, post_id, reason)."
    ]);
    exit();
}

try {
    // Auto-create reports table if not exists
    $db->exec("CREATE TABLE IF NOT EXISTS reports (
        id INT AUTO_INCREMENT PRIMARY KEY,
        reporter_id INT NOT NULL,
        target_type VARCHAR(50) DEFAULT 'post',
        target_id INT NOT NULL,
        reason VARCHAR(255) NOT NULL,
        description TEXT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    // Insert report
    $query = "INSERT INTO reports (reporter_id, target_type, target_id, reason, description, status, created_at)
              VALUES (:reporter_id, 'post', :target_id, :reason, :description, 'pending', NOW())";

    $stmt = $db->prepare($query);
    $stmt->execute([
        ':reporter_id' => $user_id,
        ':target_id' => $post_id,
        ':reason' => $reason,
        ':description' => $description
    ]);

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Report submitted successfully. Thank you for keeping our community safe!"
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
