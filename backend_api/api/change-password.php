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

$userId = isset($data->user_id) ? (int)$data->user_id : 0;
$currentPassword = isset($data->current_password) ? trim((string)$data->current_password) : '';
$newPassword = isset($data->new_password) ? trim((string)$data->new_password) : '';

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
        'message' => 'You are not allowed to update this account.'
    ]);
    exit();
}

if ($currentPassword === '' || $newPassword === '') {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Current password and new password are required.'
    ]);
    exit();
}

if (strlen($newPassword) < 6) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'New password must be at least 6 characters long.'
    ]);
    exit();
}

$stmt = $db->prepare('SELECT id, password FROM users WHERE id = :id LIMIT 1');
$stmt->bindParam(':id', $userId, PDO::PARAM_INT);
$stmt->execute();
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    http_response_code(404);
    echo json_encode([
        'success' => false,
        'message' => 'User not found.'
    ]);
    exit();
}

$storedPassword = (string)($user['password'] ?? '');
$validCurrentPassword = password_verify($currentPassword, $storedPassword);
if (!$validCurrentPassword && $currentPassword !== $storedPassword) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Current password is incorrect.'
    ]);
    exit();
}

if (password_verify($newPassword, $storedPassword)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'New password must be different from the current password.'
    ]);
    exit();
}

$newHashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);
$updateStmt = $db->prepare('UPDATE users SET password = :password, updated_at = NOW() WHERE id = :id');
$updateStmt->bindParam(':password', $newHashedPassword);
$updateStmt->bindParam(':id', $userId, PDO::PARAM_INT);

if (!$updateStmt->execute()) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Unable to update password. Please try again.'
    ]);
    exit();
}

http_response_code(200);
echo json_encode([
    'success' => true,
    'message' => 'Password updated successfully.'
]);
