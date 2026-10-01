<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

// 1. Validate Input
$user_id = isset($_POST['user_id']) ? $_POST['user_id'] : null;
$content = isset($_POST['content']) ? trim($_POST['content']) : '';

if (empty($user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID is required."]);
    exit;
}

try {
    $db->beginTransaction();

    // 2. Create Post
    $query = "INSERT INTO posts (user_id, content) VALUES (:user_id, :content)";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':user_id', $user_id);
    $stmt->bindParam(':content', $content);
    $stmt->execute();

    $post_id = $db->lastInsertId();

    // 3. Handle Multiple Image Uploads
    $uploaded_images = [];
    if (isset($_FILES['images'])) {
        $files = $_FILES['images'];
        $alignments = isset($_POST['alignments']) ? json_decode($_POST['alignments'], true) : [];
        $upload_dir = '../uploads/posts/';
        if (!is_dir($upload_dir)) mkdir($upload_dir, 0777, true);

        // Normalize the files array if multiple files are sent
        $file_count = count($files['name']);
        for ($i = 0; $i < $file_count; $i++) {
            if ($files['error'][$i] === UPLOAD_ERR_OK) {
                $ext = pathinfo($files['name'][$i], PATHINFO_EXTENSION);
                $filename = 'post_' . $user_id . '_' . uniqid() . '_' . $i . '.' . $ext;
                $target_path = $upload_dir . $filename;

                if (move_uploaded_file($files['tmp_name'][$i], $target_path)) {
                    $relative_url = 'uploads/posts/' . $filename;

                    // Get alignment and scale for this specific index
                    $ax = isset($alignments[$i]['x']) ? $alignments[$i]['x'] : 0.0;
                    $ay = isset($alignments[$i]['y']) ? $alignments[$i]['y'] : 0.0;
                    $sc = isset($alignments[$i]['scale']) ? $alignments[$i]['scale'] : 1.0;

                    // Insert into post_photos table
                    $stmt_photo = $db->prepare("INSERT INTO post_photos (post_id, photo_url, alignment_x, alignment_y, scale) VALUES (:p, :u, :ax, :ay, :sc)");
                    $stmt_photo->execute([
                        ':p' => $post_id,
                        ':u' => $relative_url,
                        ':ax' => $ax,
                        ':ay' => $ay,
                        ':sc' => $sc
                    ]);

                    $uploaded_images[] = [
                        "url" => $relative_url,
                        "alignment_x" => $ax,
                        "alignment_y" => $ay,
                        "scale" => $sc
                    ];
                }
            }
        }
    }

    // 4. Extract and Save Hashtags
    preg_match_all('/#(\w+)/u', $content, $matches);
    $hashtags = array_unique($matches[1]);

    foreach ($hashtags as $tag_name) {
        $tag_name = mb_strtolower($tag_name);
        $stmt_tag = $db->prepare("INSERT INTO hashtags (name, usage_count)
                                 VALUES (:name, 1)
                                 ON DUPLICATE KEY UPDATE usage_count = usage_count + 1");
        $stmt_tag->bindParam(':name', $tag_name);
        $stmt_tag->execute();

        $stmt_get_tag = $db->prepare("SELECT id FROM hashtags WHERE name = :name");
        $stmt_get_tag->bindParam(':name', $tag_name);
        $stmt_get_tag->execute();
        $hashtag_id = $stmt_get_tag->fetchColumn();

        $stmt_link = $db->prepare("INSERT IGNORE INTO post_hashtags (post_id, hashtag_id) VALUES (:p, :h)");
        $stmt_link->bindParam(':p', $post_id);
        $stmt_link->bindParam(':h', $hashtag_id);
        $stmt_link->execute();
    }

    $db->commit();

    http_response_code(201);
    echo json_encode([
        "success" => true,
        "message" => "Moment shared successfully!",
        "data" => [
            "post_id" => $post_id,
            "images" => $uploaded_images,
            "hashtags" => $hashtags
        ]
    ]);

} catch (Exception $e) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
