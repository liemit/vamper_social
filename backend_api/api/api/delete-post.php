<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

if (empty($data->user_id) || empty($data->post_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID and Post ID are required."]);
    exit;
}

try {
    // 1. Verify Ownership
    $stmt_check = $db->prepare("SELECT id FROM posts WHERE id = :p AND user_id = :u");
    $stmt_check->bindParam(':p', $data->post_id);
    $stmt_check->bindParam(':u', $data->user_id);
    $stmt_check->execute();

    if ($stmt_check->rowCount() == 0) {
        http_response_code(403);
        echo json_encode(["success" => false, "message" => "Unauthorized: You don't own this post."]);
        exit;
    }

    // 2. Delete Post (Cascades will handle hashtags/likes if configured,
    // but let's be explicit if not using cascades in some environments)
    $stmt_del = $db->prepare("DELETE FROM posts WHERE id = :post_id");
    $stmt_del->bindParam(':post_id', $data->post_id);

    if ($stmt_del->execute()) {
        http_response_code(200);
        echo json_encode(["success" => true, "message" => "Post deleted successfully!"]);
    } else {
        throw new Exception("Database deletion failed.");
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Server error: " . $e->getMessage()]);
}
?>
