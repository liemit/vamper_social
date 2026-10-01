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
    // Check if already liked
    $stmt_check = $db->prepare("SELECT id FROM post_likes WHERE post_id = :p AND user_id = :u");
    $stmt_check->bindParam(':p', $data->post_id);
    $stmt_check->bindParam(':u', $data->user_id);
    $stmt_check->execute();

    if ($stmt_check->rowCount() > 0) {
        // Unlike
        $stmt_del = $db->prepare("DELETE FROM post_likes WHERE post_id = :p AND user_id = :u");
        $stmt_del->bindParam(':p', $data->post_id);
        $stmt_del->bindParam(':u', $data->user_id);
        $stmt_del->execute();
        $is_liked = false;
        $message = "Unliked";
    } else {
        // Like
        $stmt_ins = $db->prepare("INSERT INTO post_likes (post_id, user_id) VALUES (:p, :u)");
        $stmt_ins->bindParam(':p', $data->post_id);
        $stmt_ins->bindParam(':u', $data->user_id);
        $stmt_ins->execute();
        $is_liked = true;
        $message = "Liked";
    }

    // Get new like count
    $stmt_count = $db->prepare("SELECT COUNT(*) FROM post_likes WHERE post_id = :p");
    $stmt_count->bindParam(':p', $data->post_id);
    $stmt_count->execute();
    $likes_count = $stmt_count->fetchColumn();

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => $message,
        "data" => [
            "is_liked" => $is_liked,
            "likes_count" => (int)$likes_count
        ]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
