<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$is_multipart = isset($_FILES['image']) || isset($_FILES['video']) || isset($_FILES['media']);
$sender_id = $is_multipart ? ($_POST['sender_id'] ?? null) : null;
$receiver_id = $is_multipart ? ($_POST['receiver_id'] ?? null) : null;
$content = $is_multipart ? ($_POST['content'] ?? '') : null;
$conversation_id = $is_multipart ? ($_POST['conversation_id'] ?? null) : null;
$reply_to = $is_multipart ? ($_POST['reply_to'] ?? null) : null;

if (!$is_multipart) {
    $data = json_decode(file_get_contents("php://input"));
    $sender_id = $data->sender_id ?? null;
    $receiver_id = $data->receiver_id ?? null;
    $content = $data->content ?? '';
    $conversation_id = $data->conversation_id ?? null;
    $reply_to = $data->reply_to ?? null;
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

    // 2. Handle Media Upload (Image or Video)
    $uploaded_file = $_FILES['image'] ?? ($_FILES['video'] ?? ($_FILES['media'] ?? null));
    if ($is_multipart && $uploaded_file && $uploaded_file['error'] === UPLOAD_ERR_OK) {
        $is_video = isset($_FILES['video']) || (isset($_FILES['media']) && strpos($uploaded_file['type'], 'video') !== false);
        $max_size = $is_video ? (15 * 1024 * 1024) : (5 * 1024 * 1024); // 15MB for video, 5MB for image

        if ($uploaded_file['size'] > $max_size) {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => $is_video ? "Video too large. Max size is 15MB." : "Image too large. Max size is 5MB."]);
            exit();
        }

        $upload_dir = $is_video ? '../uploads/videos/' : '../uploads/messages/';
        if (!is_dir($upload_dir)) mkdir($upload_dir, 0777, true);

        $ext = pathinfo($uploaded_file['name'], PATHINFO_EXTENSION);
        $prefix = $is_video ? 'vid_' : 'msg_';
        $filename = $prefix . $sender_id . '_' . uniqid() . '.' . $ext;
        $target_path = $upload_dir . $filename;

        if (move_uploaded_file($uploaded_file['tmp_name'], $target_path)) {
            $message_type = $is_video ? 'video' : 'image';
            $media_url = ($is_video ? 'uploads/videos/' : 'uploads/messages/') . $filename;
            if (empty($content)) {
                $content = $is_video ? '🎬 [Video]' : '📷 [Photo]';
            }
        }
    }

    if (empty($content) && empty($media_url)) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Message content or media required."]);
        exit();
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

    // 3. Insert Message
    $msgStmt = $db->prepare("INSERT INTO messages (conversation_id, sender_id, receiver_id, message_type, content, media_url, reply_to, is_read, created_at)
                             VALUES (:cid, :sid, :rid, :mtype, :content, :media, :reply_to, 0, NOW())");
    $msgStmt->execute([
        ':cid' => $conversation_id,
        ':sid' => $sender_id,
        ':rid' => $receiver_id,
        ':mtype' => $message_type,
        ':content' => $content,
        ':media' => $media_url,
        ':reply_to' => $reply_to
    ]);

    $message_id = $db->lastInsertId();

    // Insert notification for receiver
    try {
        $db->exec("CREATE TABLE IF NOT EXISTS notifications (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            sender_id INT NULL,
            type VARCHAR(50) NOT NULL,
            title VARCHAR(255) NOT NULL,
            body TEXT NOT NULL,
            is_read INT DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_user (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

        $notifStmt = $db->prepare("INSERT INTO notifications (user_id, sender_id, type, title, body, is_read, created_at)
                                   VALUES (:uid, :sid, 'message', 'New Message', 'You received a new message!', 0, NOW())");
        $notifStmt->execute([':uid' => $receiver_id, ':sid' => $sender_id]);
    } catch (Exception $e) {}

    // 4. Update Conversation's last_message and updated_at
    $last_snippet = $message_type === 'image' ? '📷 [Photo]' : ($message_type === 'video' ? '🎬 [Video]' : $content);
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
            "reply_to" => $reply_to,
            "is_read" => 0,
            "created_at" => date('Y-m-d H:i:s')
        ]
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
