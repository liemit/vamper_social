<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit;
}

require_once __DIR__ . '/../app/Http/Controllers/AuthController.php';
require_once __DIR__ . '/../app/Http/Controllers/AdminController.php';

$requestUri = $_SERVER['REQUEST_URI'];
$path = parse_url($requestUri, PHP_URL_PATH);

// Robustly strip common project prefixes
$path = preg_replace('#^/vamper/backend/public#', '', $path);
$path = preg_replace('#^/vamper#', '', $path);
$path = preg_replace('#^/backend/public#', '', $path);

$path = rtrim($path, '/');
if ($path === '' || $path === false) {
    $path = '/admin';
}

// API Routes
if (strpos($path, '/api') === 0) {
    header('Content-Type: application/json');
    $apiPath = str_replace('/api', '', $path);

    $authController = new AuthController();

    if ($apiPath == '/login' && $_SERVER['REQUEST_METHOD'] == 'POST') {
        echo json_encode($authController->login($_POST));
    } elseif ($apiPath == '/register' && $_SERVER['REQUEST_METHOD'] == 'POST') {
        echo json_encode($authController->register($_POST));
    } else {
        http_response_code(404);
        echo json_encode(['error' => 'API Route not found']);
    }
    exit;
}

// Web Routes (Admin Portal)
$adminController = new AdminController();

if ($path == '/admin' || $path == '/admin/login') {
    if ($_SERVER['REQUEST_METHOD'] == 'POST') {
        $adminController->login($_POST);
    } else {
        $adminController->showLoginForm();
    }
} elseif ($path == '/admin/dashboard') {
    $adminController->dashboard();
} elseif ($path == '/admin/logout') {
    $adminController->logout();
} else {
    // Fallback: Redirect to /admin
    header('Location: /vamper/admin');
    exit;
}
