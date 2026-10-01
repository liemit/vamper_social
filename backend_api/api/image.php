<?php
/**
 * ARMORED IMAGE SERVING PROXY - DIAGNOSTIC VERSION
 * Inherits security headers from cors.php.
 */

require_once '../config/cors.php';

// 1. Validate Path
if (!isset($_GET['path']) || empty($_GET['path'])) {
    http_response_code(400);
    echo "Error: Path is required.";
    exit;
}

// 2. Normalize and Locate
$requested_path = str_replace(['/', '\\'], DIRECTORY_SEPARATOR, $_GET['path']);
$base_dir = realpath(dirname(__DIR__)); // Laragon/www/vamper_api
$full_path = $base_dir . DIRECTORY_SEPARATOR . $requested_path;

// 3. Serve or Diagnose
if (file_exists($full_path) && is_file($full_path)) {
    // Detect Mime Type
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mime_type = finfo_file($finfo, $full_path);
    finfo_close($finfo);

    if (!$mime_type) {
        $ext = strtolower(pathinfo($full_path, PATHINFO_EXTENSION));
        $types = ['jpg'=>'image/jpeg', 'jpeg'=>'image/jpeg', 'png'=>'image/png', 'webp'=>'image/webp', 'gif'=>'image/gif'];
        $mime_type = isset($types[$ext]) ? $types[$ext] : 'application/octet-stream';
    }

    ob_clean();
    header("Content-Type: $mime_type");
    header("Content-Length: " . filesize($full_path));
    header("Cache-Control: public, max-age=86400");
    readfile($full_path);
    ob_end_flush();
} else {
    // AGGRESSIVE DEBUGGING - Only for development
    http_response_code(404);
    header("Content-Type: text/plain");
    echo "Error 404: Image not found.\n\n";
    echo "=== SYSTEM DIAGNOSTICS ===\n";
    echo "Current Script: " . __FILE__ . "\n";
    echo "Server Root (base_dir): " . $base_dir . "\n";
    echo "Requested Relative Path: " . $_GET['path'] . "\n";
    echo "Attempted Absolute Path: " . $full_path . "\n";
    echo "\n=== DIRECTORY CHECK ===\n";
    $uploads_dir = $base_dir . DIRECTORY_SEPARATOR . 'uploads';
    echo "Uploads dir exists: " . (is_dir($uploads_dir) ? "YES" : "NO") . " ($uploads_dir)\n";
    if (is_dir($uploads_dir)) {
        $posts_dir = $uploads_dir . DIRECTORY_SEPARATOR . 'posts';
        echo "Posts dir exists: " . (is_dir($posts_dir) ? "YES" : "NO") . " ($posts_dir)\n";
    }
}
?>
