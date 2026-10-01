<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

echo json_encode([
    "success" => true,
    "message" => "Vamper API is running!",
    "version" => "1.0.0",
    "timestamp" => date('Y-m-d H:i:s')
]);
?>
