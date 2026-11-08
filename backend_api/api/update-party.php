<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();
$hostId = authenticateApiUser($db);
$data = json_decode(file_get_contents('php://input'));

$partyId = filter_var($data->party_id ?? null, FILTER_VALIDATE_INT);
$title = trim((string)($data->title ?? ''));
$theme = trim((string)($data->theme ?? 'General'));
$isPrivate = !empty($data->is_private);
$password = trim((string)($data->password ?? ''));

if (!$partyId || $partyId < 1) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'A valid party ID is required.']);
    exit();
}

if ($title === '' || mb_strlen($title) > 255) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'A party title of at most 255 characters is required.']);
    exit();
}

if ($isPrivate && strlen($password) > 72) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Private room passwords must be at most 72 bytes.']);
    exit();
}

try {
    foreach ([
        'is_private' => 'TINYINT(1) DEFAULT 0',
        'password' => 'VARCHAR(255) NULL',
    ] as $column => $definition) {
        $check = $db->query("SHOW COLUMNS FROM parties LIKE " . $db->quote($column));
        if ($check->rowCount() === 0) {
            $db->exec("ALTER TABLE parties ADD COLUMN `$column` $definition");
        }
    }

    $partyQuery = $db->prepare('SELECT host_id, password FROM parties WHERE id = :id LIMIT 1');
    $partyQuery->execute([':id' => $partyId]);
    $party = $partyQuery->fetch(PDO::FETCH_ASSOC);
    if (!$party) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Party room not found.']);
        exit();
    }
    if ((int)$party['host_id'] !== $hostId) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Only the party host can edit this room.']);
        exit();
    }

    if ($isPrivate && $password === '' && empty($party['password'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Enter a password for this private room.']);
        exit();
    }

    $savedPassword = !$isPrivate
        ? null
        : ($password !== '' ? password_hash($password, PASSWORD_DEFAULT) : $party['password']);
    $update = $db->prepare(
        'UPDATE parties SET title = :title, theme = :theme, is_private = :is_private, password = :password
         WHERE id = :id AND host_id = :host_id'
    );
    $update->execute([
        ':title' => $title,
        ':theme' => $theme,
        ':is_private' => $isPrivate ? 1 : 0,
        ':password' => $savedPassword,
        ':id' => $partyId,
        ':host_id' => $hostId,
    ]);

    echo json_encode([
        'success' => true,
        'message' => 'Party room updated successfully.',
        'data' => [
            'party_id' => $partyId,
            'title' => $title,
            'theme' => $theme,
            'is_private' => $isPrivate ? 1 : 0,
        ],
    ]);
} catch (Throwable $error) {
    error_log('Unable to update party: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to update the party room.']);
}
?>
