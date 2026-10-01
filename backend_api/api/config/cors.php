<?php
/**
 * MASTER SECURITY CONTROLLER - PHP ONLY VERSION
 * This file handles all security handshakes.
 * DELETE ALL .htaccess FILES FOR THIS TO WORK PERFECTLY.
 */

// 1. Silent mode
error_reporting(0);
ini_set('display_errors', 0);
ob_start();

// 2. Identify the requester
$origin = "*";
if (isset($_SERVER['HTTP_ORIGIN'])) {
    $origin = $_SERVER['HTTP_ORIGIN'];
}

// 3. Set Master Headers
header("Access-Control-Allow-Origin: $origin");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Origin, Accept");
header("Access-Control-Allow-Credentials: true");
header("Access-Control-Max-Age: 86400");

// 4. Handle preflight (OPTIONS) requests INSTANTLY in PHP
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    ob_end_clean();
    exit(0);
}

// 5. Clean start for the API
header("Content-Type: application/json; charset=UTF-8");
?>
