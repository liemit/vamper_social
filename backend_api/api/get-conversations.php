<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/libs/ChatPresence.php';

$database = new Database();
$db = $database->getConnection();

$user_id = authenticateApiUser($db);

try {
    ensureChatPresenceTable($db);

    // Ensure conversations table exists
    $db->exec("CREATE TABLE IF NOT EXISTS conversations (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user1_id INT NOT NULL,
        user2_id INT NOT NULL,
        last_message TEXT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY unique_conv (user1_id, user2_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    $db->exec("CREATE TABLE IF NOT EXISTS user_settings (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        setting_key VARCHAR(100) NOT NULL,
        setting_value JSON NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY unique_user_setting (user_id, setting_key),
        KEY idx_user_id (user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    // Ensure messages table exists
    $db->exec("CREATE TABLE IF NOT EXISTS messages (
        id INT AUTO_INCREMENT PRIMARY KEY,
        conversation_id INT NOT NULL,
        sender_id INT NOT NULL,
        receiver_id INT NOT NULL,
        message_type VARCHAR(20) DEFAULT 'text' COMMENT 'text, image',
        content TEXT NULL,
        media_url VARCHAR(255) NULL,
        is_read INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_conv (conversation_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    $query = "SELECT c.id as conversation_id, c.last_message, c.updated_at,
                     CASE WHEN c.user1_id = :uid THEN c.user2_id ELSE c.user1_id END as partner_id
              FROM conversations c
              WHERE c.user1_id = :uid OR c.user2_id = :uid
              ORDER BY c.updated_at DESC";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':uid', $user_id);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $conversations = [];

    foreach ($rows as $row) {
        $partner_id = $row['partner_id'];

        // Fetch partner details
        $pStmt = $db->prepare(
            "SELECT u.id, u.full_name, u.profile_photo, u.gender, u.date_of_birth, u.is_verified,
                    frame.image_url AS active_profile_frame_code,
                    CASE
                        WHEN presence.is_active = 1
                         AND presence.last_seen >= UTC_TIMESTAMP() - INTERVAL 45 SECOND
                         AND COALESCE(
                             CAST(JSON_UNQUOTE(JSON_EXTRACT(online_setting.setting_value, '$')) AS UNSIGNED),
                             1
                         ) = 1
                        THEN 1 ELSE 0
                    END AS partner_is_online
             FROM users u
             LEFT JOIN shop_items frame
               ON frame.id = u.active_profile_frame_id AND frame.type = 'profile_frame'
             LEFT JOIN user_presence presence ON presence.user_id = u.id
             LEFT JOIN user_settings online_setting
               ON online_setting.user_id = u.id
              AND online_setting.setting_key = 'settings_show_online_status'
             WHERE u.id = :pid LIMIT 1"
        );
        $pStmt->execute([':pid' => $partner_id]);
        $partner = $pStmt->fetch(PDO::FETCH_ASSOC);

        if ($partner) {
            $age = 22;
            if (!empty($partner['date_of_birth'])) {
                $dob = new DateTime($partner['date_of_birth']);
                $now = new DateTime();
                $age = $now->diff($dob)->y;
            }

            // Unread count
            $uStmt = $db->prepare("SELECT COUNT(*) FROM messages WHERE conversation_id = :cid AND receiver_id = :uid AND is_read = 0");
            $uStmt->execute([':cid' => $row['conversation_id'], ':uid' => $user_id]);
            $unread_count = $uStmt->fetchColumn();

            $conversations[] = [
                "conversation_id" => $row['conversation_id'],
                "partner_id" => $partner['id'],
                "partner_name" => $partner['full_name'],
                "partner_photo" => $partner['profile_photo'],
                "partner_profile_frame_code" => $partner['active_profile_frame_code'],
                "partner_gender" => $partner['gender'] ?? 'other',
                "partner_age" => $age,
                "partner_verified" => (int)$partner['is_verified'] === 1,
                "partner_is_online" => (int)$partner['partner_is_online'] === 1,
                "last_message" => $row['last_message'] ?? 'Matched! Say hi 👋',
                "unread_count" => (int)$unread_count,
                "updated_at" => $row['updated_at']
            ];
        }
    }

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "data" => $conversations
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
