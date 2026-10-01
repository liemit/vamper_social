<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$post_id = isset($_GET['post_id']) ? $_GET['post_id'] : null;
$user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null; // For checking current user's like/dislike

if (empty($post_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Post ID is required."]);
    exit;
}

try {
    // Fetch comments with author info, like/dislike counts, and current user interaction
    $query = "SELECT c.*, u.full_name as author_name, u.profile_photo as author_photo,
              (SELECT COUNT(*) FROM comment_interactions WHERE comment_id = c.id AND interaction_type = 'like') as likes_count,
              (SELECT COUNT(*) FROM comment_interactions WHERE comment_id = c.id AND interaction_type = 'dislike') as dislikes_count,
              (SELECT interaction_type FROM comment_interactions WHERE comment_id = c.id AND user_id = :current_user) as user_interaction,
              p_u.full_name as reply_to_name,
              parent.user_id as reply_to_user_id
              FROM post_comments c
              JOIN users u ON c.user_id = u.id
              LEFT JOIN post_comments parent ON c.parent_id = parent.id
              LEFT JOIN users p_u ON parent.user_id = p_u.id
              WHERE c.post_id = :post_id
              ORDER BY c.created_at ASC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':post_id', $post_id);
    $stmt->bindParam(':current_user', $user_id);
    $stmt->execute();

    $comments = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Ensure numeric types for Flutter
    foreach ($comments as &$c) {
        $c['likes_count'] = (int)$c['likes_count'];
        $c['dislikes_count'] = (int)$c['dislikes_count'];
    }

    echo json_encode([
        "success" => true,
        "data" => $comments
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
