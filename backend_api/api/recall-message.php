<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));
$message_id = $data->message_id ?? null;
$user_id = $data->user_id ?? null;

if (empty($message_id) || empty($user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Message ID and User ID are required."]);
    exit();
}

try {
    // Verify ownership
    $stmt = $db->prepare("SELECT id, sender_id FROM messages WHERE id = :mid LIMIT 1");
    $stmt->execute([':mid' => $message_id]);
    $msg = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$msg || intval($msg['sender_id']) !== intval($user_id)) {
        http_response_code(403);
        echo json_encode(["success" => false, "message" => "Unauthorized to recall this message."]);
        exit();
    }

    // Update message to recalled
    $upd = $db->prepare("UPDATE messages SET message_type = 'recalled', content = '[Message recalled]', media_url = NULL WHERE id = :mid");
    $upd->execute([':mid' => $message_id]);

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Message recalled successfully."
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
