<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

// Get posted data
$data = json_decode(file_get_contents("php://input"));

// Validate input
if (empty($data->email) || empty($data->password)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Please provide email and password."
    ]);
    exit();
}

try {
    // Normalize email
    $email = strtolower(trim((string)$data->email));

    // Query user
    $query = "SELECT id, full_name, email, password, profile_photo, gender, 
                     date_of_birth, bio, location, is_verified, coins, is_active, created_at
              FROM users WHERE email = :email LIMIT 1";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(":email", $email);
    $stmt->execute();

    if ($stmt->rowCount() > 0) {
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        // Check if account is active
        if ($user['is_active'] == 0) {
            http_response_code(403);
            echo json_encode([
                "success" => false,
                "message" => "Your account has been deactivated. Please contact support."
            ]);
            exit();
        }

        // Verify password (support both hashed and plaintext matching for test accounts)
        $password_matches = password_verify($data->password, $user['password']) || ($data->password === $user['password']);
        if ($password_matches) {
            // Remove password from response
            unset($user['password']);
            
            // Generate simple token (in production, use JWT)
            $token = base64_encode($user['id'] . ':' . time());

            // Update last login (optional)
            $update_query = "UPDATE users SET updated_at = NOW() WHERE id = :id";
            $update_stmt = $db->prepare($update_query);
            $update_stmt->bindParam(":id", $user['id']);
            $update_stmt->execute();

            http_response_code(200);
            echo json_encode([
                "success" => true,
                "message" => "Login successful!",
                "data" => [
                    "user" => $user,
                    "token" => $token
                ]
            ]);
        } else {
            http_response_code(401);
            echo json_encode([
                "success" => false,
                "message" => "Invalid email or password."
            ]);
        }
    } else {
        http_response_code(401);
        echo json_encode([
            "success" => false,
            "message" => "Invalid email or password."
        ]);
    }

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
