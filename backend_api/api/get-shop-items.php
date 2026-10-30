<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();

$user_id = authenticateApiUser($db);

try {
    // Ensure tables exist
    $db->exec("CREATE TABLE IF NOT EXISTS shop_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        type ENUM('avatar','profile_frame','party_frame') NOT NULL,
        image_url VARCHAR(255) NOT NULL,
        price_coins INT NOT NULL DEFAULT 100,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    $db->exec("CREATE TABLE IF NOT EXISTS user_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        item_id INT NOT NULL,
        purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_user_item (user_id, item_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    // Ensure the selected cosmetics can be persisted for each user.
    foreach (['active_profile_frame_id', 'active_party_frame_id'] as $column) {
        $columnStmt = $db->query("SHOW COLUMNS FROM users LIKE " . $db->quote($column));
        if ($columnStmt->rowCount() === 0) {
            $db->exec("ALTER TABLE users ADD COLUMN `$column` INT NULL");
        }
    }

    // Auto-seed shop_items if empty
    $countStmt = $db->query("SELECT COUNT(*) FROM shop_items");
    if ($countStmt->fetchColumn() == 0) {
        $seedQuery = "INSERT INTO shop_items (name, type, image_url, price_coins) VALUES
        ('Khung Trắng Tối Giản', 'profile_frame', 'frame_white', 0),
        ('Khung Neon Xanh Biển', 'profile_frame', 'frame_blue', 0),
        ('Khung Lục Ngọc Minimal', 'profile_frame', 'frame_emerald', 0),
        ('Khung Cyberpunk Neon Glow', 'profile_frame', 'frame_neon', 150),
        ('Khung Hoàng Gia Vương Miện', 'profile_frame', 'frame_gold', 350),
        ('Khung Hào Quang Quỷ Lửa', 'profile_frame', 'frame_flame', 500),
        ('Khung Cổng Vũ Trụ Vamper', 'profile_frame', 'frame_galaxy', 750),
        ('Khung Rồng Đêm Huyền Thoại', 'profile_frame', 'frame_dragon', 1200),

        ('Avatar Nam Trẻ Trung', 'avatar', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200', 0),
        ('Avatar Nữ Anime Dễ Thương', 'avatar', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200', 0),
        ('Avatar Gamer Neon Boy', 'avatar', 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=200', 0),
        ('Avatar Hacker Cyberpunk', 'avatar', 'https://images.unsplash.com/photo-1566492031773-4f4e44671857?w=200', 200),
        ('Avatar Quỷ Anime Neon', 'avatar', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200', 350),
        ('Avatar Mecha Fighter Robot', 'avatar', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200', 500),
        ('Avatar Chúa Tể Vampire Vàng', 'avatar', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200', 1000),
        ('Avatar Thiên Thần Ánh Sáng', 'avatar', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200', 1500);";
        $db->exec($seedQuery);
    }

    // Fetch shop items
    $stmt = $db->query(
        "SELECT id, name, type, image_url, price_coins
         FROM shop_items
         WHERE type IN ('profile_frame', 'avatar')
         ORDER BY price_coins ASC"
    );
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $owned_item_ids = [];
    $active_profile_frame = null;
    $active_party_frame = null;
    $active_profile_frame_code = null;
    $active_party_frame_code = null;
    $active_avatar_item = null;

    if (!empty($user_id)) {
        // Fetch owned items
        $oStmt = $db->prepare("SELECT item_id FROM user_items WHERE user_id = :uid");
        $oStmt->execute([':uid' => $user_id]);
        $owned_item_ids = $oStmt->fetchAll(PDO::FETCH_COLUMN);

        // Fetch active equipped frame
        $uStmt = $db->prepare(
            "SELECT u.active_profile_frame_id, u.active_party_frame_id,
                    profile_frame.image_url AS active_profile_frame_code,
                    party_frame.image_url AS active_party_frame_code,
                    avatar.id AS active_avatar_item_id
             FROM users u
             LEFT JOIN shop_items profile_frame
               ON profile_frame.id = u.active_profile_frame_id AND profile_frame.type = 'profile_frame'
             LEFT JOIN shop_items party_frame
               ON party_frame.id = u.active_party_frame_id AND party_frame.type = 'party_frame'
             LEFT JOIN shop_items avatar ON avatar.type = 'avatar' AND avatar.image_url = u.profile_photo
             WHERE u.id = :uid LIMIT 1"
        );
        $uStmt->execute([':uid' => $user_id]);
        $activeUser = $uStmt->fetch(PDO::FETCH_ASSOC);
        if ($activeUser) {
            $active_profile_frame = $activeUser['active_profile_frame_id'];
            $active_party_frame = $activeUser['active_party_frame_id'];
            $active_profile_frame_code = $activeUser['active_profile_frame_code'];
            $active_party_frame_code = $activeUser['active_party_frame_code'];
            $active_avatar_item = $activeUser['active_avatar_item_id'];
        }
    }

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "items" => $items,
        "owned_item_ids" => array_map('intval', $owned_item_ids),
        "active_profile_frame_id" => $active_profile_frame ? (int)$active_profile_frame : null,
        "active_party_frame_id" => $active_party_frame ? (int)$active_party_frame : null,
        "active_profile_frame_code" => $active_profile_frame_code,
        "active_party_frame_code" => $active_party_frame_code,
        "active_avatar_item_id" => $active_avatar_item ? (int)$active_avatar_item : null
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
