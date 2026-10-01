<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

// 1. Identify Inputs
$user_id = isset($_POST['user_id']) ? $_POST['user_id'] : null;
$post_id = isset($_POST['post_id']) ? $_POST['post_id'] : null;
$content = isset($_POST['content']) ? trim($_POST['content']) : null;
$status = isset($_POST['status']) ? $_POST['status'] : null;
$delete_photos = isset($_POST['delete_photos']) ? json_decode($_POST['delete_photos'], true) : [];
$new_alignments = isset($_POST['new_alignments']) ? json_decode($_POST['new_alignments'], true) : [];
$update_alignments = isset($_POST['update_alignments']) ? json_decode($_POST['update_alignments'], true) : [];

if (empty($user_id) || empty($post_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID and Post ID are required."]);
    exit;
}

try {
    $db->beginTransaction();

    // 2. Verify Ownership
    $stmt_check = $db->prepare("SELECT id FROM posts WHERE id = :p AND user_id = :u");
    $stmt_check->execute([':p' => $post_id, ':u' => $user_id]);

    if ($stmt_check->rowCount() == 0) {
        http_response_code(403);
        echo json_encode(["success" => false, "message" => "Unauthorized."]);
        exit;
    }

    // 3. Update Text and Status
    $fields = [];
    $params = [':post_id' => $post_id];
    if ($content !== null) { $fields[] = "content = :content"; $params[':content'] = $content; }
    if ($status !== null) { $fields[] = "status = :status"; $params[':status'] = (int)$status; }

    if (!empty($fields)) {
        $query = "UPDATE posts SET " . implode(", ", $fields) . ", updated_at = NOW() WHERE id = :post_id";
        $stmt = $db->prepare($query);
        $stmt->execute($params);
    }

    // 4. Update Existing Photo Alignments/Scale
    if (!empty($update_alignments)) {
        foreach ($update_alignments as $url => $align) {
            $stmt_upd_align = $db->prepare("UPDATE post_photos SET alignment_x = :x, alignment_y = :y, scale = :sc WHERE post_id = :p AND photo_url = :u");
            $stmt_upd_align->execute([
                ':x' => $align['x'],
                ':y' => $align['y'],
                ':sc' => isset($align['scale']) ? $align['scale'] : 1.0,
                ':p' => $post_id,
                ':u' => $url
            ]);
        }
    }

    // 5. Handle Deletions
    if (!empty($delete_photos)) {
        foreach ($delete_photos as $url) {
            $stmt_del = $db->prepare("DELETE FROM post_photos WHERE post_id = :p AND photo_url = :u");
            $stmt_del->execute([':p' => $post_id, ':u' => $url]);
            $file_path = '../' . $url;
            if (file_exists($file_path)) unlink($file_path);
        }
    }

    // 6. Handle New Uploads
    if (isset($_FILES['images'])) {
        $files = $_FILES['images'];
        $upload_dir = '../uploads/posts/';
        if (!is_dir($upload_dir)) mkdir($upload_dir, 0777, true);

        $file_count = is_array($files['name']) ? count($files['name']) : 0;
        for ($i = 0; $i < $file_count; $i++) {
            if ($files['error'][$i] === UPLOAD_ERR_OK) {
                $ext = pathinfo($files['name'][$i], PATHINFO_EXTENSION);
                $filename = 'post_' . $user_id . '_' . uniqid() . '_upd_' . $i . '.' . $ext;
                $target_path = $upload_dir . $filename;

                if (move_uploaded_file($files['tmp_name'][$i], $target_path)) {
                    $relative_url = 'uploads/posts/' . $filename;
                    $ax = isset($new_alignments[$i]['x']) ? $new_alignments[$i]['x'] : 0.0;
                    $ay = isset($new_alignments[$i]['y']) ? $new_alignments[$i]['y'] : 0.0;
                    $sc = isset($new_alignments[$i]['scale']) ? $new_alignments[$i]['scale'] : 1.0;

                    $stmt_photo = $db->prepare("INSERT INTO post_photos (post_id, photo_url, alignment_x, alignment_y, scale) VALUES (:p, :u, :ax, :ay, :sc)");
                    $stmt_photo->execute([':p' => $post_id, ':u' => $relative_url, ':ax' => $ax, ':ay' => $ay, ':sc' => $sc]);
                }
            }
        }
    }

    $db->commit();
    echo json_encode(["success" => true, "message" => "Post updated successfully!"]);

} catch (Exception $e) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
