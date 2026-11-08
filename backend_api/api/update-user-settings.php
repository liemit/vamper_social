<?php
require_once __DIR__ . '/../config/cors.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();

$authenticatedUserId = authenticateApiUser($db);

$data = json_decode(file_get_contents('php://input'));
if (!is_object($data)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Invalid request payload.'
    ]);
    exit();
}

$userId = isset($data->user_id) ? (int)$data->user_id : $authenticatedUserId;
$settings = isset($data->settings) && is_object($data->settings) ? $data->settings : null;

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
        'message' => 'You are not allowed to update this user settings.'
    ]);
    exit();
}

if (!$settings) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Settings payload is required.'
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

$allowed = [
    'settings_push_notifications',
    'settings_match_notifications',
    'settings_party_notifications',
    'settings_private_profile',
    'settings_show_online_status',
    'settings_allow_messages',
    'settings_show_in_search',
    'settings_dark_mode',
];

$upsertSql = 'INSERT INTO user_settings (user_id, setting_key, setting_value)
    VALUES (:user_id, :setting_key, :setting_value)
    ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = NOW()';

$stmt = $db->prepare($upsertSql);
$changed = [];

foreach ($allowed as $key) {
    if (!property_exists($settings, $key)) {
        continue;
    }

    $value = (bool)$settings->$key;
    $jsonValue = json_encode($value, JSON_THROW_ON_ERROR);
    $stmt->execute([
        ':user_id' => $userId,
        ':setting_key' => $key,
        ':setting_value' => $jsonValue,
    ]);
    $changed[$key] = $value;
}

http_response_code(200);
echo json_encode([
    'success' => true,
    'message' => 'Settings saved successfully.',
    'data' => $changed
]);
