<?php
require_once '../../config/cors.php';
require_once '../../config/database.php';

$database = new Database();
$db = $database->getConnection();

// Verify Admin Secret or ID (Optional simple check for now)
$admin_id = isset($_GET['admin_id']) ? $_GET['admin_id'] : null;

try {
    // 1. Fetch Summary Stats
    $stmt_stats = $db->prepare("SELECT
        (SELECT COUNT(*) FROM users) as total_users,
        (SELECT COUNT(*) FROM posts) as total_posts,
        (SELECT COUNT(*) FROM users WHERE is_active = 0) as banned_users");
    $stmt_stats->execute();
    $stats = $stmt_stats->fetch(PDO::FETCH_ASSOC);

    // 2. Fetch User List
    $query = "SELECT id, full_name, email, role, gender, profile_photo, location, coins, is_active, created_at
              FROM users
              ORDER BY created_at DESC";
    $stmt = $db->prepare($query);
    $stmt->execute();
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        "success" => true,
        "data" => [
            "stats" => $stats,
            "users" => $users
        ]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>
