<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$conversation_id = isset($_GET['conversation_id']) ? $_GET['conversation_id'] : null;
$user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null;
$partner_id = isset($_GET['partner_id']) ? $_GET['partner_id'] : null;

if (empty($conversation_id) && (empty($user_id) || empty($partner_id))) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Conversation ID or User & Partner IDs required."]);
    exit();
}

try {
    // If conversation_id not passed, lookup or create conversation
    if (empty($conversation_id)) {
        $u1 = min(intval($user_id), intval($partner_id));
        $u2 = max(intval($user_id), intval($partner_id));

        $cStmt = $db->prepare("SELECT id FROM conversations WHERE user1_id = :u1 AND user2_id = :u2 LIMIT 1");
        $cStmt->execute([':u1' => $u1, ':u2' => $u2]);

        if ($cStmt->rowCount() > 0) {
            $conversation_id = $cStmt->fetchColumn();
        } else {
            $insStmt = $db->prepare("INSERT INTO conversations (user1_id, user2_id, updated_at) VALUES (:u1, :u2, NOW())");
            $insStmt->execute([':u1' => $u1, ':u2' => $u2]);
            $conversation_id = $db->lastInsertId();
        }
    }

    // Ensure reply_to and reaction columns exist safely
    try {
        $colCheck = $db->query("SHOW COLUMNS FROM messages LIKE 'reply_to'");
        if ($colCheck->rowCount() == 0) {
            $db->exec("ALTER TABLE messages ADD COLUMN reply_to TEXT NULL");
        }
        $colCheck2 = $db->query("SHOW COLUMNS FROM messages LIKE 'reaction'");
        if ($colCheck2->rowCount() == 0) {
            $db->exec("ALTER TABLE messages ADD COLUMN reaction VARCHAR(50) NULL");
        }
    } catch (Exception $e) {}

    // Fetch messages
    $mStmt = $db->prepare("SELECT id, conversation_id, sender_id, receiver_id, message_type, content, media_url, reply_to, reaction, is_read, created_at
                           FROM messages
                           WHERE conversation_id = :cid
                           ORDER BY created_at ASC");
    $mStmt->execute([':cid' => $conversation_id]);
    $messages = $mStmt->fetchAll(PDO::FETCH_ASSOC);

    // Mark messages as read for current user
    if ($user_id) {
        $rStmt = $db->prepare("UPDATE messages SET is_read = 1 WHERE conversation_id = :cid AND receiver_id = :uid AND is_read = 0");
        $rStmt->execute([':cid' => $conversation_id, ':uid' => $user_id]);
    }

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "conversation_id" => (int)$conversation_id,
        "data" => $messages
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
