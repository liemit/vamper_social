<?php
require_once '../config/cors.php';
require_once '../config/database.php';

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

    // Ensure is_private and password columns exist safely
    try {
        $col1 = $db->query("SHOW COLUMNS FROM parties LIKE 'is_private'");
        if ($col1->rowCount() == 0) {
            $db->exec("ALTER TABLE parties ADD COLUMN is_private TINYINT(1) DEFAULT 0");
        }
        $col2 = $db->query("SHOW COLUMNS FROM parties LIKE 'password'");
        if ($col2->rowCount() == 0) {
            $db->exec("ALTER TABLE parties ADD COLUMN password VARCHAR(100) NULL");
        }
    } catch (Exception $e) {}

    $user_id = isset($_GET['user_id']) ? $_GET['user_id'] : null;

    $sql = "SELECT p.id, p.host_id, p.title, p.theme, p.participants_count, p.is_private, p.password, p.is_live, p.created_at,
                   u.full_name as host_name, u.profile_photo as host_photo
            FROM parties p
            JOIN users u ON p.host_id = u.id
            WHERE p.is_live = 1";

    if (!empty($user_id)) {
        $sql .= " AND p.host_id NOT IN (SELECT blocked_id FROM blocked_users WHERE blocker_id = :uid UNION SELECT blocker_id FROM blocked_users WHERE blocked_id = :uid)";
    }
    $sql .= " ORDER BY p.participants_count DESC";

    $stmt = $db->prepare($sql);
    if (!empty($user_id)) {
        $stmt->execute([':uid' => $user_id]);
    } else {
        $stmt->execute();
    }
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

        $stmt = $db->query("SELECT p.id, p.host_id, p.title, p.theme, p.participants_count, p.is_live, p.created_at,
                                   u.full_name as host_name, u.profile_photo as host_photo
                            FROM parties p
                            JOIN users u ON p.host_id = u.id
                            WHERE p.is_live = 1
                            ORDER BY p.participants_count DESC");
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
