<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$current_user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null;
$target_user_id = isset($_GET['target_user_id']) ? $_GET['target_user_id'] : null;

try {
    $where_clauses = ["p.status = 1"];
    $params = [':current_user' => $current_user_id];

    if ($current_user_id) {
        $where_clauses = ["(p.status = 1 OR p.user_id = :current_user)"];
    }

    if ($target_user_id) {
        $where_clauses[] = "p.user_id = :target_user";
        $params[':target_user'] = $target_user_id;
    }

    $where_sql = implode(" AND ", $where_clauses);

    $query = "SELECT p.*, u.full_name, u.profile_photo,
              (SELECT COUNT(*) FROM post_likes WHERE post_id = p.id) as likes_count,
              (SELECT COUNT(*) FROM post_comments WHERE post_id = p.id) as comments_count,
              (SELECT COUNT(*) FROM post_likes WHERE post_id = p.id AND user_id = :current_user) as is_liked
              FROM posts p
              JOIN users u ON p.user_id = u.id
              WHERE $where_sql
              ORDER BY p.created_at DESC
              LIMIT 50";

    $stmt = $db->prepare($query);
    foreach ($params as $key => $val) {
        $stmt->bindValue($key, $val);
    }
    $stmt->execute();
    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($posts as &$post) {
        $post_id = $post['id'];

        // 1. Fetch All Photos for this post with alignments and scale
        $stmt_photos = $db->prepare("SELECT photo_url, alignment_x, alignment_y, scale FROM post_photos WHERE post_id = :post_id ORDER BY id ASC");
        $stmt_photos->bindParam(':post_id', $post_id);
        $stmt_photos->execute();
        $post['images'] = $stmt_photos->fetchAll(PDO::FETCH_ASSOC);

        // 2. Fetch Hashtags
        $stmt_tags = $db->prepare("SELECT h.name FROM hashtags h
                                  JOIN post_hashtags ph ON h.id = ph.hashtag_id
                                  WHERE ph.post_id = :post_id");
        $stmt_tags->bindParam(':post_id', $post_id);
        $stmt_tags->execute();
        $post['hashtags'] = $stmt_tags->fetchAll(PDO::FETCH_COLUMN);

        $post['is_liked'] = (int)$post['is_liked'] > 0;
    }

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "data" => $posts
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
