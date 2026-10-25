<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));
$host_id = $data->host_id ?? null;
$title = $data->title ?? null;
$theme = $data->theme ?? 'General';
$is_private = !empty($data->is_private) ? 1 : 0;
$password = $data->password ?? null;

if (empty($host_id) || empty($title)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Host ID and Title are required."]);
    exit();
}

try {
    // Ensure is_private and password columns exist safely
    try {
        $col1 = $db->query("SHOW COLUMNS FROM parties LIKE 'is_private'");
        if ($col1->rowCount() == 0) {
            $db->exec("ALTER TABLE parties ADD COLUMN is_private TINYINT(1) DEFAULT 0");
        }
        $col2 = $db->query("SHOW COLUMNS FROM parties LIKE 'password'");
        if ($col2->rowCount() == 0) {
            $db->exec("ALTER TABLE parties ADD COLUMN password VARCHAR(100) NULL");
        }
    } catch (Exception $e) {}

    $stmt = $db->prepare("INSERT INTO parties (host_id, title, theme, is_private, password, participants_count, is_live, created_at)
                          VALUES (:host_id, :title, :theme, :is_private, :password, 1, 1, NOW())");
    $stmt->execute([
        ':host_id' => $host_id,
        ':title' => $title,
        ':theme' => $theme,
        ':is_private' => $is_private,
        ':password' => $password
    ]);

    $party_id = $db->lastInsertId();

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Party room created successfully!",
        "data" => ["party_id" => (int)$party_id]
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
