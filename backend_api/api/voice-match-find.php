<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null;
$gender_pref = isset($_GET['gender_pref']) ? trim($_GET['gender_pref']) : 'both';

if (empty($user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID is required."]);
    exit();
}

try {
    // Ensure match_queue table exists
    $db->exec("CREATE TABLE IF NOT EXISTS match_queue (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        mode VARCHAR(20) NOT NULL COMMENT 'soul or voice',
        last_ping TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY unique_queue (user_id, mode)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    // 1. Get current user's location/region
    $userStmt = $db->prepare("SELECT location FROM users WHERE id = :user_id LIMIT 1");
    $userStmt->execute([':user_id' => $user_id]);
    $currentUser = $userStmt->fetch(PDO::FETCH_ASSOC);
    $user_location = trim($currentUser['location'] ?? '');

    // 2. Gender clause
    $gender_clause = "";
    if ($gender_pref === 'male') {
        $gender_clause = "AND u.gender = 'male'";
    } elseif ($gender_pref === 'female') {
        $gender_clause = "AND u.gender = 'female'";
    }

    // 3. Build query with STRICT ONLINE QUEUE MATCHING for voice mode
    $params = [':user_id' => $user_id];
    $location_clause = "";
    if (!empty($user_location)) {
        $location_clause = "AND u.location = :user_location";
        $params[':user_location'] = $user_location;
    }

    $queryOnlineQueue = "SELECT u.id, u.full_name, u.email, u.profile_photo, u.gender, u.date_of_birth, u.bio, u.location, u.coins, u.is_verified
                         FROM users u
                         JOIN match_queue q ON u.id = q.user_id
                         WHERE u.id != :user_id
                         AND u.is_active = 1
                         AND q.mode = 'voice'
                         AND q.last_ping >= NOW() - INTERVAL 15 SECOND
                         $location_clause
                         $gender_clause
                         ORDER BY RAND()
                         LIMIT 1";

    $stmt = $db->prepare($queryOnlineQueue);
    foreach ($params as $k => $v) {
        $stmt->bindValue($k, $v);
    }
    $stmt->execute();

    // Fallback: Check queue globally if no match in same region
    if ($stmt->rowCount() == 0) {
        $queryGlobalQueue = "SELECT u.id, u.full_name, u.email, u.profile_photo, u.gender, u.date_of_birth, u.bio, u.location, u.coins, u.is_verified
                             FROM users u
                             JOIN match_queue q ON u.id = q.user_id
                             WHERE u.id != :user_id
                             AND u.is_active = 1
                             AND q.mode = 'voice'
                             AND q.last_ping >= NOW() - INTERVAL 15 SECOND
                             $gender_clause
                             ORDER BY RAND()
                             LIMIT 1";
        $stmt = $db->prepare($queryGlobalQueue);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->execute();
    }

    if ($stmt->rowCount() > 0) {
        $partner = $stmt->fetch(PDO::FETCH_ASSOC);

        $age = 22;
        if (!empty($partner['date_of_birth'])) {
            $dob = new DateTime($partner['date_of_birth']);
            $now = new DateTime();
            $age = $now->diff($dob)->y;
        }
        $partner['age'] = $age;

        http_response_code(200);
        echo json_encode([
            "success" => true,
            "data" => $partner
        ]);
    } else {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "No online users actively waiting in Voice Match right now. Please wait a moment!"
        ]);
    }

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
