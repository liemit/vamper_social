<?php
header("Content-Type: text/plain");
echo "=== SERVER ENVIRONMENT ===\n";
echo "REQUEST_METHOD: " . $_SERVER['REQUEST_METHOD'] . "\n";
echo "HTTP_ORIGIN: " . (isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : 'NOT SET') . "\n";
echo "\n=== RESPONSE HEADERS ===\n";
$headers = headers_list();
foreach ($headers as $header) {
    echo $header . "\n";
}
?>
