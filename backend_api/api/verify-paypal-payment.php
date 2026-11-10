<?php
require_once '../config/cors.php';
http_response_code(410);
echo json_encode([
    'success' => false,
    'message' => 'Mock PayPal credits have been disabled. Use the PayPal order and capture checkout.',
]);
