<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

// Support both JSON POST and Multipart FormData (for image upload)
$is_multipart = isset($_FILES['image']);
$sender_id = $is_multipart ? ($_POST['sender_id'] ?? null) : null;
$receiver_id = $is_multipart ? ($_POST['receiver_id'] ?? null) : null;
$content = $is_multipart ? ($_POST['content'] ?? '') : null;
$conversation_id = $is_multipart ? ($_POST['conversation_id'] ?? null) : null;

if (!$is_multipart) {
    $data = json_decode(file_get_contents("php://input"));
    $sender_id = $data->sender_id ?? null;
    $receiver_id = $data->receiver_id ?? null;
    $content = $data->content ?? '';
    $conversation_id = $data->conversation_id ?? null;
}

if (empty($sender_id) || empty($receiver_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Sender ID and Receiver ID are required."]);
    exit();
}

try {
    // 1. Ensure conversation exists
    if (empty($conversation_id)) {
        $u1 = min(intval($sender_id), intval($receiver_id));
        $u2 = max(intval($sender_id), intval($receiver_id));

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

    $message_type = 'text';
    $media_url = null;

    // 2. Handle Image Upload if present
    if ($is_multipart && isset($_FILES['image']) && $_FILES['image']['error'] === UPLOAD_ERR_OK) {
        $upload_dir = '../uploads/messages/';
        if (!is_dir($upload_dir)) mkdir($upload_dir, 0777, true);

        $ext = pathinfo($_FILES['image']['name'], PATHINFO_EXTENSION);
        $filename = 'msg_' . $sender_id . '_' . uniqid() . '.' . $ext;
        $target_path = $upload_dir . $filename;

        if (move_uploaded_file($_FILES['image']['tmp_name'], $target_path)) {
            $message_type = 'image';
            $media_url = 'uploads/messages/' . $filename;
            if (empty($content)) {
                $content = '📷 [Photo]';
            }
        }
    }

    if (empty($content) && empty($media_url)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Message content or image required."]);
        exit();
    }

    // 3. Insert Message
    $msgStmt = $db->prepare("INSERT INTO messages (conversation_id, sender_id, receiver_id, message_type, content, media_url, is_read, created_at)
                             VALUES (:cid, :sid, :rid, :mtype, :content, :media, 0, NOW())");
    $msgStmt->execute([
        ':cid' => $conversation_id,
        ':sid' => $sender_id,
        ':rid' => $receiver_id,
        ':mtype' => $message_type,
        ':content' => $content,
        ':media' => $media_url
    ]);

    $message_id = $db->lastInsertId();

    // 4. Update Conversation's last_message and updated_at
    $last_snippet = $message_type === 'image' ? '📷 [Photo]' : $content;
    $updConv = $db->prepare("UPDATE conversations SET last_message = :snippet, updated_at = NOW() WHERE id = :cid");
    $updConv->execute([':snippet' => $last_snippet, ':cid' => $conversation_id]);

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Message sent!",
        "data" => [
            "id" => (int)$message_id,
            "conversation_id" => (int)$conversation_id,
            "sender_id" => (int)$sender_id,
            "receiver_id" => (int)$receiver_id,
            "message_type" => $message_type,
            "content" => $content,
            "media_url" => $media_url,
            "is_read" => 0,
            "created_at" => date('Y-m-d H:i:s')
        ]
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
