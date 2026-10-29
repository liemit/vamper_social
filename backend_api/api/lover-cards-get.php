<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null;
$gender_pref = isset($_GET['gender_pref']) ? trim($_GET['gender_pref']) : 'both';
$limit = isset($_GET['limit']) ? max(1, intval($_GET['limit'])) : 20;

if (empty($user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID is required."]);
    exit();
}

try {
    // Ensure card_swipes table exists
    $db->exec("CREATE TABLE IF NOT EXISTS card_swipes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        target_id INT NOT NULL,
        action VARCHAR(20) NOT NULL COMMENT 'pass, like, superlike',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_swipe (user_id, target_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    // Ensure conversations table exists
    $db->exec("CREATE TABLE IF NOT EXISTS conversations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user1_id INT NOT NULL,
        user2_id INT NOT NULL,
        last_message TEXT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY unique_conv (user1_id, user2_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    // 1. Get current user's location
    $userStmt = $db->prepare("SELECT location FROM users WHERE id = :user_id LIMIT 1");
    $userStmt->execute([':user_id' => $user_id]);
    $currentUser = $userStmt->fetch(PDO::FETCH_ASSOC);
    $user_location = trim($currentUser['location'] ?? '');

    // 2. Gender clause
    $gender_clause = "";
    if ($gender_pref === 'male') {
        $gender_clause = "AND gender = 'male'";
    } elseif ($gender_pref === 'female') {
        $gender_clause = "AND gender = 'female'";
    }

    // 3. Region clause
    $params = [':user_id' => $user_id];
    $location_clause = "";
    if (!empty($user_location)) {
        $location_clause = "AND location = :user_location";
        $params[':user_location'] = $user_location;
    }

    $query = "SELECT u.id, u.full_name, u.email, u.profile_photo, u.gender, u.date_of_birth,
                     u.bio, u.location, u.is_verified,
                     frame.image_url AS active_profile_frame_code
              FROM users u
              LEFT JOIN shop_items frame
                ON frame.id = u.active_profile_frame_id AND frame.type = 'profile_frame'
              WHERE id != :user_id
              AND is_active = 1
              $location_clause
              $gender_clause
              AND id NOT IN (
                  SELECT target_id FROM card_swipes WHERE user_id = :user_id
              )
              ORDER BY RAND()
              LIMIT :limit";

    $stmt = $db->prepare($query);
    foreach ($params as $k => $v) {
        $stmt->bindValue($k, $v);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();

    // Fallback to global if no candidates in region
    if ($stmt->rowCount() == 0) {
        $queryGlobal = "SELECT u.id, u.full_name, u.email, u.profile_photo, u.gender, u.date_of_birth,
                               u.bio, u.location, u.is_verified,
                               frame.image_url AS active_profile_frame_code
                        FROM users u
                        LEFT JOIN shop_items frame
                          ON frame.id = u.active_profile_frame_id AND frame.type = 'profile_frame'
                        WHERE id != :user_id
                        AND is_active = 1
                        $gender_clause
                        AND id NOT IN (
                            SELECT target_id FROM card_swipes WHERE user_id = :user_id
                        )
                        ORDER BY RAND()
                        LIMIT :limit";
        $stmt = $db->prepare($queryGlobal);
        $stmt->bindParam(':user_id', $user_id);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
    }

    $candidates = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($candidates as &$c) {
        $age = 22;
        if (!empty($c['date_of_birth'])) {
            $dob = new DateTime($c['date_of_birth']);
            $now = new DateTime();
            $age = $now->diff($dob)->y;
        }
        $c['age'] = $age;

        // Fetch user photos
        $stmt_photos = $db->prepare("SELECT photo_url FROM post_photos WHERE post_id IN (SELECT id FROM posts WHERE user_id = :uid) ORDER BY id DESC LIMIT 5");
        $stmt_photos->execute([':uid' => $c['id']]);
        $photos = $stmt_photos->fetchAll(PDO::FETCH_COLUMN);

        if (!empty($c['profile_photo'])) {
            array_unshift($photos, $c['profile_photo']);
        }
        $c['photos'] = array_unique($photos);
    }

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "data" => $candidates
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
