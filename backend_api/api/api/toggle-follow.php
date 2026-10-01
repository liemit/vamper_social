<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

if (empty($data->follower_id) || empty($data->followed_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Follower ID and Followed ID are required."]);
    exit;
}

try {
    // Check if already following
    $stmt_check = $db->prepare("SELECT id FROM follows WHERE follower_id = :u1 AND followed_id = :u2");
    $stmt_check->bindParam(':u1', $data->follower_id);
    $stmt_check->bindParam(':u2', $data->followed_id);
    $stmt_check->execute();

    if ($stmt_check->rowCount() > 0) {
        // Unfollow
        $stmt_del = $db->prepare("DELETE FROM follows WHERE follower_id = :u1 AND followed_id = :u2");
        $stmt_del->bindParam(':u1', $data->follower_id);
        $stmt_del->bindParam(':u2', $data->followed_id);
        $stmt_del->execute();
        $is_following = false;
        $message = "Unfollowed successfully";
    } else {
        // Follow
        $stmt_ins = $db->prepare("INSERT INTO follows (follower_id, followed_id) VALUES (:u1, :u2)");
        $stmt_ins->bindParam(':u1', $data->follower_id);
        $stmt_ins->bindParam(':u2', $data->followed_id);
        $stmt_ins->execute();
        $is_following = true;
        $message = "Followed successfully";
    }

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => $message,
        "data" => ["is_following" => $is_following]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
