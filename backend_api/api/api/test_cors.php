<?php
require_once '../config/cors.php';

echo json_encode([
    "success" => true,
    "message" => "CORS Check Successful!",
    "server_time" => date('Y-m-d H:i:s'),
    "request_method" => $_SERVER['REQUEST_METHOD'],
    "php_version" => phpversion()
]);
?>
