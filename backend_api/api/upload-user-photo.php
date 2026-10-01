<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

// Validate user_id from POST
if (empty($_POST['user_id'])) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID is required."]);
    exit();
}

$user_id = $_POST['user_id'];
$is_profile = isset($_POST['is_profile']) ? (int)$_POST['is_profile'] : 0;
$sort_order = isset($_POST['sort_order']) ? (int)$_POST['sort_order'] : 0;

// Check if file was uploaded
if (!isset($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "No file uploaded or upload error."]);
    exit();
}

$file = $_FILES['photo'];
$allowed_types = ['image/jpeg', 'image/png', 'image/webp'];
$max_size = 5 * 1024 * 1024; // 5MB

// Validate type
if (!in_array($file['type'], $allowed_types)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Invalid file type."]);
    exit();
}

// Validate size
if ($file['size'] > $max_size) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "File too large (Max 5MB)."]);
    exit();
}

// Create directory
$upload_dir = '../uploads/user_photos/';
if (!is_dir($upload_dir)) {
    mkdir($upload_dir, 0777, true);
}

// Generate unique name
$extension = pathinfo($file['name'], PATHINFO_EXTENSION);
$filename = 'user_' . $user_id . '_' . uniqid() . '.' . $extension;
$target_path = $upload_dir . $filename;

if (move_uploaded_file($file['tmp_name'], $target_path)) {
    try {
        $db_path = 'uploads/user_photos/' . $filename;

        // If this is set as profile, update users table as well
        if ($is_profile == 1) {
            $update_user = $db->prepare("UPDATE users SET profile_photo = :photo WHERE id = :id");
            $update_user->bindParam(":photo", $db_path);
            $update_user->bindParam(":id", $user_id);
            $update_user->execute();
        }

        // Insert into user_photos
        $query = "INSERT INTO user_photos (user_id, photo_url, is_profile, sort_order)
                  VALUES (:user_id, :photo_url, :is_profile, :sort_order)";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":user_id", $user_id);
        $stmt->bindParam(":photo_url", $db_path);
        $stmt->bindParam(":is_profile", $is_profile);
        $stmt->bindParam(":sort_order", $sort_order);

        if ($stmt->execute()) {
            $photo_id = $db->lastInsertId();

            http_response_code(200);
            echo json_encode([
                "success" => true,
                "message" => "Photo uploaded and saved.",
                "data" => [
                    "id" => $photo_id,
                    "url" => $db_path,
                    "is_profile" => $is_profile,
                    "sort_order" => $sort_order
                ]
            ]);
        } else {
            unlink($target_path);
            throw new Exception("Database record creation failed.");
        }
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => $e->getMessage()]);
    }
} else {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Failed to save file."]);
}
?>
