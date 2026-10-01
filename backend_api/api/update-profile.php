<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

// Get posted data
$data = json_decode(file_get_contents("php://input"));

// Validate input
if (empty($data->user_id)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "User ID is required."
    ]);
    exit();
}

try {
    // Start building the query
    $fields = [];
    $params = [];

    if (isset($data->full_name)) {
        $fields[] = "full_name = :full_name";
        $params[":full_name"] = trim($data->full_name);
    }
    if (isset($data->phone)) {
        $fields[] = "phone = :phone";
        $params[":phone"] = trim($data->phone);
    }
    if (isset($data->gender)) {
        $fields[] = "gender = :gender";
        $params[":gender"] = $data->gender;
    }
    if (isset($data->date_of_birth)) {
        $fields[] = "date_of_birth = :date_of_birth";
        $params[":date_of_birth"] = $data->date_of_birth;
    }
    if (isset($data->bio)) {
        $fields[] = "bio = :bio";
        $params[":bio"] = trim($data->bio);
    }
    if (isset($data->location)) {
        $fields[] = "location = :location";
        $params[":location"] = trim($data->location);
    }
    if (isset($data->latitude)) {
        $fields[] = "latitude = :latitude";
        $params[":latitude"] = $data->latitude;
    }
    if (isset($data->longitude)) {
        $fields[] = "longitude = :longitude";
        $params[":longitude"] = $data->longitude;
    }

    if (empty($fields)) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "No fields to update."
        ]);
        exit();
    }

    $query = "UPDATE users SET " . implode(", ", $fields) . ", updated_at = NOW() WHERE id = :id";
    $params[":id"] = $data->user_id;

    $stmt = $db->prepare($query);

    if ($stmt->execute($params)) {
        // Fetch updated user data including coordinates
        $stmt_user = $db->prepare("SELECT id, full_name, email, phone, gender, date_of_birth, bio, profile_photo, location, latitude, longitude, is_verified, coins, created_at, updated_at FROM users WHERE id = :id LIMIT 1");
        $stmt_user->bindParam(":id", $data->user_id);
        $stmt_user->execute();
        $user = $stmt_user->fetch(PDO::FETCH_ASSOC);

        http_response_code(200);
        echo json_encode([
            "success" => true,
            "message" => "Profile updated successfully!",
            "data" => [
                "user" => $user
            ]
        ]);
    } else {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Unable to update profile. Please try again."
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
