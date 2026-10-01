<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

if (empty($data->user_id) || empty($data->comment_id) || empty($data->type)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Incomplete data."]);
    exit;
}

$u = $data->user_id;
$c = $data->comment_id;
$type = $data->type; // 'like' or 'dislike'

try {
    // 1. Check current interaction
    $stmt_check = $db->prepare("SELECT interaction_type FROM comment_interactions WHERE comment_id = :c AND user_id = :u");
    $stmt_check->bindParam(':c', $c);
    $stmt_check->bindParam(':u', $u);
    $stmt_check->execute();
    $existing = $stmt_check->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        if ($existing['interaction_type'] == $type) {
            // Remove if same type
            $stmt_del = $db->prepare("DELETE FROM comment_interactions WHERE comment_id = :c AND user_id = :u");
            $stmt_del->execute([':c' => $c, ':u' => $u]);
            $current_type = null;
        } else {
            // Switch type
            $stmt_upd = $db->prepare("UPDATE comment_interactions SET interaction_type = :t WHERE comment_id = :c AND user_id = :u");
            $stmt_upd->execute([':t' => $type, ':c' => $c, ':u' => $u]);
            $current_type = $type;
        }
    } else {
        // New interaction
        $stmt_ins = $db->prepare("INSERT INTO comment_interactions (comment_id, user_id, interaction_type) VALUES (:c, :u, :t)");
        $stmt_ins->execute([':c' => $c, ':u' => $u, ':t' => $type]);
        $current_type = $type;
    }

    // 2. Fetch new counts
    $stmt_counts = $db->prepare("SELECT
        SUM(CASE WHEN interaction_type = 'like' THEN 1 ELSE 0 END) as likes,
        SUM(CASE WHEN interaction_type = 'dislike' THEN 1 ELSE 0 END) as dislikes
        FROM comment_interactions WHERE comment_id = :c");
    $stmt_counts->execute([':c' => $c]);
    $counts = $stmt_counts->fetch(PDO::FETCH_ASSOC);

    echo json_encode([
        "success" => true,
        "data" => [
            "user_interaction" => $current_type,
            "likes_count" => (int)($counts['likes'] ?? 0),
            "dislikes_count" => (int)($counts['dislikes'] ?? 0)
        ]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
