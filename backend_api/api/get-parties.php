<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();

try {
    $db->exec("CREATE TABLE IF NOT EXISTS parties (
        id INT AUTO_INCREMENT PRIMARY KEY,
        host_id INT NOT NULL,
        title VARCHAR(255) NOT NULL,
        theme VARCHAR(100) DEFAULT 'General',
        participants_count INT DEFAULT 1,
        is_live TINYINT(1) DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");
    $db->exec("CREATE TABLE IF NOT EXISTS shop_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        type ENUM('avatar','profile_frame','party_frame') NOT NULL,
        image_url VARCHAR(255) NOT NULL,
        price_coins INT NOT NULL DEFAULT 100,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");
    if ($db->query("SHOW TABLES LIKE 'party_members'")->fetchColumn() === false) {
        $db->exec("CREATE TABLE party_members (
            party_id INT NOT NULL,
            user_id INT NOT NULL,
            seat_index TINYINT NULL,
            is_hand_raised TINYINT(1) NOT NULL DEFAULT 0,
            is_cohost TINYINT(1) NOT NULL DEFAULT 0,
            last_seen DATETIME NOT NULL,
            PRIMARY KEY (party_id, user_id),
            UNIQUE KEY uq_party_member_seat (party_id, seat_index),
            KEY idx_party_member_last_seen (party_id, last_seen)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    }

    // Ensure is_private and password columns exist safely
    try {
        $col1 = $db->query("SHOW COLUMNS FROM parties LIKE 'is_private'");
        if ($col1->rowCount() == 0) {
            $db->exec("ALTER TABLE parties ADD COLUMN is_private TINYINT(1) DEFAULT 0");
        }
        $col2 = $db->query("SHOW COLUMNS FROM parties LIKE 'password'");
        if ($col2->rowCount() == 0) {
            $db->exec("ALTER TABLE parties ADD COLUMN password VARCHAR(255) NULL");
        }
    } catch (Exception $e) {}

    $user_id = authenticateApiUser($db);

    foreach (['active_profile_frame_id', 'active_party_frame_id'] as $column) {
        $userColumns = $db->query("SHOW COLUMNS FROM users LIKE " . $db->quote($column));
        if ($userColumns->rowCount() === 0) {
            $db->exec("ALTER TABLE users ADD COLUMN `$column` INT NULL");
        }
    }

    $sql = "SELECT p.id, p.host_id, p.title, p.theme,
                   (SELECT COUNT(*) FROM party_members pm
                    WHERE pm.party_id = p.id AND pm.last_seen >= UTC_TIMESTAMP() - INTERVAL 30 SECOND) AS participants_count,
                   p.is_private, p.is_live, p.created_at,
                   u.full_name as host_name, u.profile_photo as host_photo,
           u.active_profile_frame_id AS host_profile_frame_id,
           u.active_party_frame_id AS host_party_frame_id, party_item.image_url AS host_party_frame_code
            FROM parties p
            JOIN users u ON p.host_id = u.id
            LEFT JOIN shop_items party_item ON party_item.id = u.active_party_frame_id AND party_item.type = 'party_frame'
            WHERE p.is_live = 1";

    $sql .= " AND p.host_id NOT IN (
        SELECT blocked_id FROM blocked_users WHERE blocker_id = :blocker_uid
        UNION SELECT blocker_id FROM blocked_users WHERE blocked_id = :blocked_uid
    )";
    $sql .= " ORDER BY participants_count DESC";

    $stmt = $db->prepare($sql);
    $stmt->execute([':blocker_uid' => $user_id, ':blocked_uid' => $user_id]);
    $parties = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Auto-seed active party rooms for existing users if table is empty
    if (empty($parties)) {
        $uStmt = $db->query("SELECT id FROM users LIMIT 4");
        $users = $uStmt->fetchAll(PDO::FETCH_COLUMN);

        $sampleParties = [
            ['title' => 'Late Night Chill & Lofi Beats 🎧', 'theme' => '☕ Chill', 'count' => 12],
            ['title' => 'Speed Dating & Voice Match 💕', 'theme' => '💕 Dating', 'count' => 28],
            ['title' => 'Singing Contest & EDM Party 🎤', 'theme' => '🎵 Music', 'count' => 45],
            ['title' => 'Confessions & Deep Soul Talks 💬', 'theme' => '☕ Chill', 'count' => 18],
        ];

        foreach ($sampleParties as $i => $sp) {
            if (isset($users[$i])) {
                $ins = $db->prepare("INSERT INTO parties (host_id, title, theme, participants_count, is_live, created_at)
                                      VALUES (:hid, :title, :theme, :count, 1, NOW())");
                $ins->execute([
                    ':hid' => $users[$i],
                    ':title' => $sp['title'],
                    ':theme' => $sp['theme'],
                    ':count' => $sp['count']
                ]);
            }
        }

        $stmt = $db->prepare("SELECT p.id, p.host_id, p.title, p.theme,
                                   (SELECT COUNT(*) FROM party_members pm
                                    WHERE pm.party_id = p.id AND pm.last_seen >= UTC_TIMESTAMP() - INTERVAL 30 SECOND) AS participants_count,
                                   p.is_private, p.is_live, p.created_at,
                                   u.full_name as host_name, u.profile_photo as host_photo,
                                   u.active_profile_frame_id AS host_profile_frame_id,
                                   u.active_party_frame_id AS host_party_frame_id, party_item.image_url AS host_party_frame_code
                            FROM parties p
                            JOIN users u ON p.host_id = u.id
                            LEFT JOIN shop_items party_item ON party_item.id = u.active_party_frame_id AND party_item.type = 'party_frame'
                            WHERE p.is_live = 1
                              AND p.host_id NOT IN (
                                  SELECT blocked_id FROM blocked_users WHERE blocker_id = :blocker_uid
                                  UNION SELECT blocker_id FROM blocked_users WHERE blocked_id = :blocked_uid
                              )
                            ORDER BY participants_count DESC");
        $stmt->execute([':blocker_uid' => $user_id, ':blocked_uid' => $user_id]);
        $parties = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "data" => $parties
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
