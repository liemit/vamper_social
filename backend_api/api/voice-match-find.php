<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();
authenticateApiUser($db);

http_response_code(410);
echo json_encode([
    'success' => false,
    'message' => 'Voice Match now uses authenticated LiveKit sessions. Please update the app.',
]);
