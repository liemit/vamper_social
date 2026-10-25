<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));
$message_id = $data->message_id ?? null;
$user_id = $data->user_id ?? null;
$reaction = $data->reaction ?? null; // e.g. '❤️', '👍', null to clear

if (empty($message_id) || empty($user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Message ID and User ID are required."]);
    exit();
}

try {
    // Ensure reaction column exists
    try {
        $colCheck = $db->query("SHOW COLUMNS FROM messages LIKE 'reaction'");
        if ($colCheck->rowCount() == 0) {
            $db->exec("ALTER TABLE messages ADD COLUMN reaction VARCHAR(50) NULL");
        }
    } catch (Exception $e) {}

    $stmt = $db->prepare("UPDATE messages SET reaction = :reaction WHERE id = :mid");
    $stmt->execute([
        ':reaction' => $reaction,
        ':mid' => $message_id
    ]);

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Reaction updated!"
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
