<?php
require_once '../../config/cors.php';
require_once '../../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

if (empty($data->target_user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Target User ID is required."]);
    exit;
}

try {
    // Toggle is_active status
    $stmt = $db->prepare("UPDATE users SET is_active = 1 - is_active WHERE id = :id");
    $stmt->bindParam(':id', $data->target_user_id);

    if ($stmt->execute()) {
        $stmt_new = $db->prepare("SELECT is_active FROM users WHERE id = :id");
        $stmt_new->execute([':id' => $data->target_user_id]);
        $new_status = $stmt_new->fetchColumn();

        echo json_encode([
            "success" => true,
            "message" => $new_status ? "User unbanned" : "User banned",
            "data" => ["is_active" => (int)$new_status]
        ]);
    }
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>
