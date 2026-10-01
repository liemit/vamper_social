<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$follower_id = isset($_GET['follower_id']) ? $_GET['follower_id'] : null;
$followed_id = isset($_GET['followed_id']) ? $_GET['followed_id'] : null;

if (empty($follower_id) || empty($followed_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Follower ID and Followed ID are required."]);
    exit;
}

try {
    $stmt_check = $db->prepare("SELECT id FROM follows WHERE follower_id = :u1 AND followed_id = :u2");
    $stmt_check->bindParam(':u1', $follower_id);
    $stmt_check->bindParam(':u2', $followed_id);
    $stmt_check->execute();

    echo json_encode([
        "success" => true,
        "is_following" => $stmt_check->rowCount() > 0
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
