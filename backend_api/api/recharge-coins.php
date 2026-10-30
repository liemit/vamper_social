<?php
require_once '../config/cors.php';

http_response_code(410);
echo json_encode([
    'success' => false,
    'message' => 'Direct coin crediting is disabled. Use the supported checkout flow.',
]);
