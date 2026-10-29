<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();
$hostId = authenticateApiUser($db);
$data = json_decode(file_get_contents("php://input"));
$title = trim((string)($data->title ?? ''));
$theme = trim((string)($data->theme ?? 'General'));
$isPrivate = !empty($data->is_private);
$password = trim((string)($data->password ?? ''));

if ($title === '' || mb_strlen($title) > 255) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "A party title of at most 255 characters is required."]);
    exit();
}

if ($isPrivate && ($password === '' || strlen($password) > 72)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Private room passwords must contain 1 to 72 bytes."]);
    exit();
}

try {
    foreach ([
        'is_private' => "TINYINT(1) DEFAULT 0",
        'password' => "VARCHAR(255) NULL",
    ] as $column => $definition) {
        $check = $db->query("SHOW COLUMNS FROM parties LIKE " . $db->quote($column));
        if ($check->rowCount() === 0) {
            $db->exec("ALTER TABLE parties ADD COLUMN `$column` $definition");
        }
    }
    $passwordColumn = $db->query("SHOW COLUMNS FROM parties LIKE 'password'")->fetch(PDO::FETCH_ASSOC);
    if ($passwordColumn && preg_match('/^varchar\\((\\d+)\\)$/i', $passwordColumn['Type'], $matches) && (int)$matches[1] < 255) {
        $db->exec('ALTER TABLE parties MODIFY COLUMN password VARCHAR(255) NULL');
    }

    $stmt = $db->prepare(
        "INSERT INTO parties (host_id, title, theme, is_private, password, participants_count, is_live, created_at)
         VALUES (:host_id, :title, :theme, :is_private, :password, 1, 1, NOW())"
    );
    $stmt->execute([
        ':host_id' => $hostId,
        ':title' => $title,
        ':theme' => $theme,
        ':is_private' => $isPrivate ? 1 : 0,
        ':password' => $isPrivate ? password_hash($password, PASSWORD_DEFAULT) : null,
    ]);

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Party room created successfully!",
        "data" => ["party_id" => (int)$db->lastInsertId()],
    ]);
} catch (PDOException $error) {
    error_log('Unable to create party: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Unable to create the party room."]);
}
?>
