<?php
require_once __DIR__ . '/../config/cors.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();

$authenticatedUserId = authenticateApiUser($db);
$userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : $authenticatedUserId;

if ($userId <= 0) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'User ID is required.'
    ]);
    exit();
}

if ($userId !== $authenticatedUserId) {
    http_response_code(403);
    echo json_encode([
        'success' => false,
        'message' => 'You are not allowed to access this user settings.'
    ]);
    exit();
}

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

$stmt = $db->prepare('SELECT setting_key, setting_value FROM user_settings WHERE user_id = :user_id');
$stmt->bindParam(':user_id', $userId, PDO::PARAM_INT);
$stmt->execute();

$settings = [];
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    $key = $row['setting_key'];
    $value = json_decode($row['setting_value'], true);
    $settings[$key] = $value;
}

$defaults = [
    'settings_push_notifications' => true,
    'settings_match_notifications' => true,
    'settings_party_notifications' => true,
    'settings_private_profile' => false,
    'settings_show_online_status' => true,
    'settings_allow_messages' => true,
    'settings_show_in_search' => true,
    'settings_dark_mode' => false,
];

foreach ($defaults as $key => $value) {
    if (!array_key_exists($key, $settings)) {
        $settings[$key] = $value;
    }
}

http_response_code(200);
echo json_encode([
    'success' => true,
    'data' => $settings
]);
