<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

$email = isset($data->email) ? strtolower(trim((string)$data->email)) : '';
$full_name = isset($data->full_name) ? trim((string)$data->full_name) : 'Vamper User';
$provider = isset($data->provider) ? trim((string)$data->provider) : 'google';
$social_id = isset($data->social_id) ? trim((string)$data->social_id) : '';
$photo_url = isset($data->photo_url) ? trim((string)$data->photo_url) : null;

if (empty($email)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Email is required for social sign-in."]);
    exit();
}

try {
    // 1. Check if user already exists
    $stmt = $db->prepare("SELECT id, full_name, email, role, gender, date_of_birth, profile_photo, coins, is_active, is_verified, created_at FROM users WHERE email = :email LIMIT 1");
    $stmt->bindParam(':email', $email);
    $stmt->execute();

    if ($stmt->rowCount() > 0) {
        // User exists -> Log in
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($user['is_active'] == 0) {
            http_response_code(403);
            echo json_encode(["success" => false, "message" => "Your account has been deactivated."]);
            exit();
        }

        // Update photo if missing
        if (empty($user['profile_photo']) && !empty($photo_url)) {
            $upd = $db->prepare("UPDATE users SET profile_photo = :photo, is_verified = 1 WHERE id = :id");
            $upd->execute([':photo' => $photo_url, ':id' => $user['id']]);
            $user['profile_photo'] = $photo_url;
        }

        // User is only considered "new" if they haven't completed their gender/birthdate yet
        $is_new_user = empty($user['gender']);

        $token = base64_encode($user['id'] . ':' . time());

        http_response_code(200);
        echo json_encode([
            "success" => true,
            "is_new_user" => $is_new_user,
            "message" => "Logged in successfully via " . ucfirst($provider),
            "data" => [
                "user" => $user,
                "token" => $token
            ]
        ]);

    } else {
        // User does not exist -> Auto-Register brand NEW social user
        $randomPass = password_hash(uniqid($provider . '_', true), PASSWORD_DEFAULT);

        $ins = $db->prepare("INSERT INTO users (full_name, email, password, role, profile_photo, coins, is_active, is_verified, created_at)
                             VALUES (:name, :email, :pass, 'user', :photo, 100, 1, 1, NOW())");
        $ins->execute([
            ':name' => $full_name,
            ':email' => $email,
            ':pass' => $randomPass,
            ':photo' => $photo_url
        ]);

        $new_id = $db->lastInsertId();

        $stmt_user = $db->prepare("SELECT id, full_name, email, role, gender, profile_photo, coins, is_active, is_verified, created_at FROM users WHERE id = :id LIMIT 1");
        $stmt_user->execute([':id' => $new_id]);
        $newUser = $stmt_user->fetch(PDO::FETCH_ASSOC);

        $token = base64_encode($new_id . ':' . time());

        http_response_code(200);
        echo json_encode([
            "success" => true,
            "is_new_user" => true,
            "message" => "Account created via " . ucfirst($provider) . ". Please complete your profile!",
            "data" => [
                "user" => $newUser,
                "token" => $token
            ]
        ]);
    }

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
