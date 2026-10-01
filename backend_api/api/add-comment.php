<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

if (empty($data->user_id) || empty($data->post_id) || empty($data->comment)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Incomplete data."]);
    exit;
}

$parent_id = isset($data->parent_id) ? $data->parent_id : null;

try {
    // 1. Insert comment
    $query = "INSERT INTO post_comments (post_id, user_id, parent_id, comment) VALUES (:p, :u, :parent, :c)";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':p', $data->post_id);
    $stmt->bindParam(':u', $data->user_id);
    $stmt->bindParam(':parent', $parent_id);
    $stmt->bindParam(':c', $data->comment);

    if ($stmt->execute()) {
        $comment_id = $db->lastInsertId();

        // 2. Fetch the newly created comment with author info
        $query_new = "SELECT c.*, u.full_name as author_name, u.profile_photo as author_photo
                      FROM post_comments c
                      JOIN users u ON c.user_id = u.id
                      WHERE c.id = :id";
        $stmt_new = $db->prepare($query_new);
        $stmt_new->bindParam(':id', $comment_id);
        $stmt_new->execute();
        $new_comment = $stmt_new->fetch(PDO::FETCH_ASSOC);

        http_response_code(201);
        echo json_encode([
            "success" => true,
            "message" => "Comment added.",
            "data" => $new_comment
        ]);
    } else {
        throw new Exception("Failed to insert comment.");
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
