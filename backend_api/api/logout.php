<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();

try {
    revokeApiToken($db);
    echo json_encode([
        'success' => true,
        'message' => 'Session ended successfully.',
    ]);
} catch (PDOException $error) {
    error_log('Unable to revoke API token: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Unable to end session.',
    ]);
}
