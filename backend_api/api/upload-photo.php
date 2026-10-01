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
    echo json_encode(["success" => false, "message" => "Invalid file type. Only JPG, PNG, and WebP are allowed."]);
    exit();
}

// Validate size
if ($file['size'] > $max_size) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "File too large. Max size is 5MB."]);
    exit();
}

// Create uploads directory if it doesn't exist
$upload_dir = '../uploads/profile_photos/';
if (!is_dir($upload_dir)) {
    mkdir($upload_dir, 0777, true);
}

// Generate unique file name
$extension = pathinfo($file['name'], PATHINFO_EXTENSION);
$filename = 'profile_' . $user_id . '_' . time() . '.' . $extension;
$target_path = $upload_dir . $filename;

// Move uploaded file
if (move_uploaded_file($file['tmp_name'], $target_path)) {
    try {
        // Construct the full URL/Path to store in DB
        // You might want to store just the filename or the relative path
        $db_path = 'uploads/profile_photos/' . $filename;

        // Update database
        $query = "UPDATE users SET profile_photo = :photo, updated_at = NOW() WHERE id = :id";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":photo", $db_path);
        $stmt->bindParam(":id", $user_id);

        if ($stmt->execute()) {
            // Fetch updated user
            $stmt_user = $db->prepare("SELECT id, full_name, email, profile_photo, is_verified FROM users WHERE id = :id LIMIT 1");
            $stmt_user->bindParam(":id", $user_id);
            $stmt_user->execute();
            $user = $stmt_user->fetch(PDO::FETCH_ASSOC);

            http_response_code(200);
            echo json_encode([
                "success" => true,
                "message" => "Photo uploaded successfully!",
                "data" => [
                    "user" => $user,
                    "photo_url" => $db_path
                ]
            ]);
        } else {
            unlink($target_path); // Delete file if DB update fails
            throw new Exception("Database update failed.");
        }
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Server error: " . $e->getMessage()]);
    }
} else {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Failed to move uploaded file."]);
}
?>
