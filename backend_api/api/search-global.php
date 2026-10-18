<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$query_str = isset($_GET['q']) ? trim($_GET['q']) : '';
$type = isset($_GET['type']) ? trim($_GET['type']) : 'all'; // 'all', 'users', 'posts'
$current_user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null;

if (empty($query_str)) {
    http_response_code(200);
    echo json_encode([
        "success" => true,
        "data" => [
            "users" => [],
            "posts" => []
        ]
    ]);
    exit();
}

try {
    $like_term = "%$query_str%";
    $matching_users = [];
    $matching_posts = [];

    // 1. Search Users (by full_name or email)
    if ($type === 'all' || $type === 'users') {
        $user_sql = "SELECT id, full_name, email, profile_photo, gender, location, is_verified
                    FROM users
                    WHERE (full_name LIKE :term OR email LIKE :term)
                    AND is_active = 1
                    LIMIT 20";
        $stmt_u = $db->prepare($user_sql);
        $stmt_u->bindValue(':term', $like_term);
        $stmt_u->execute();
        $matching_users = $stmt_u->fetchAll(PDO::FETCH_ASSOC);
    }

    // 2. Search Posts (by content or hashtag)
    if ($type === 'all' || $type === 'posts') {
        $post_sql = "SELECT p.*, u.full_name, u.profile_photo,
                     (SELECT COUNT(*) FROM post_likes WHERE post_id = p.id) as likes_count,
                     (SELECT COUNT(*) FROM post_comments WHERE post_id = p.id) as comments_count,
                     (SELECT COUNT(*) FROM post_likes WHERE post_id = p.id AND user_id = :curr_user) as is_liked
                     FROM posts p
                     JOIN users u ON p.user_id = u.id
                     WHERE p.status = 1
                     AND p.content LIKE :term
                     ORDER BY p.created_at DESC
                     LIMIT 20";
        $stmt_p = $db->prepare($post_sql);
        $stmt_p->bindValue(':term', $like_term);
        $stmt_p->bindValue(':curr_user', $current_user_id);
        $stmt_p->execute();
        $matching_posts = $stmt_p->fetchAll(PDO::FETCH_ASSOC);

        foreach ($matching_posts as &$post) {
            $post_id = $post['id'];
            $stmt_photos = $db->prepare("SELECT photo_url FROM post_photos WHERE post_id = :p ORDER BY id ASC");
            $stmt_photos->execute([':p' => $post_id]);
            $post['images'] = $stmt_photos->fetchAll(PDO::FETCH_ASSOC);
            $post['is_liked'] = (int)$post['is_liked'] > 0;
        }
    }

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "data" => [
            "users" => $matching_users,
            "posts" => $matching_posts
        ]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
