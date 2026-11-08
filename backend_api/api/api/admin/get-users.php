<?php
require_once '../../config/cors.php';
require_once '../../config/database.php';
require_once '../../../libs/AdminTools.php';
require_once '../../libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();

$admin_id = authenticateApiUser($db);
assertAdminApiPermission($db, (int)$admin_id, 'users');

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
    $stmt = $db->prepare($query . ' LIMIT 200');
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
    error_log('Admin user list failed: ' . $e->getMessage());
    echo json_encode(["success" => false, "message" => "Unable to load admin user data."]);
}
?>
