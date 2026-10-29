<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));
$user_id = authenticateApiUser($db);
$item_id = isset($data->item_id) && $data->item_id !== null
    ? filter_var($data->item_id, FILTER_VALIDATE_INT)
    : null;
$type = $data->type ?? 'profile_frame'; // 'profile_frame', 'avatar', or 'party_frame'

if (!in_array($type, ['profile_frame', 'avatar', 'party_frame'], true)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Valid item type is required."]);
    exit();
}

try {
    if ($type === 'party_frame') {
        $columnStmt = $db->query("SHOW COLUMNS FROM users LIKE 'active_party_frame_id'");
        if ($columnStmt->rowCount() === 0) {
            $db->exec("ALTER TABLE users ADD COLUMN active_party_frame_id INT NULL");
        }
    }

    $userStmt = $db->prepare("SELECT 1 FROM users WHERE id = :uid LIMIT 1");
    $userStmt->execute([':uid' => $user_id]);
    if (!$userStmt->fetchColumn()) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "User not found."]);
        exit();
    }

    if ($item_id !== null) {
        if (!$item_id) {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "Invalid item ID."]);
            exit();
        }

        $ownedStmt = $db->prepare(
            "SELECT s.image_url, s.type FROM shop_items s
             INNER JOIN user_items ui ON ui.item_id = s.id
             WHERE s.id = :iid AND ui.user_id = :uid LIMIT 1"
        );
        $ownedStmt->execute([':iid' => $item_id, ':uid' => $user_id]);
        $item = $ownedStmt->fetch(PDO::FETCH_ASSOC);
        if (!$item || $item['type'] !== $type) {
            http_response_code(403);
            echo json_encode(["success" => false, "message" => "You do not own an item of this type."]);
            exit();
        }
    } elseif ($type === 'avatar') {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "An avatar item is required."]);
        exit();
    }

    $response = [
        "success" => true,
        "message" => "Item equipped successfully!",
        "type" => $type,
        "item_id" => $item_id ? (int)$item_id : null
    ];

    if ($type === 'profile_frame') {
        $stmt = $db->prepare("UPDATE users SET active_profile_frame_id = :iid WHERE id = :uid");
        $stmt->execute([':iid' => $item_id, ':uid' => $user_id]);
        $response['active_profile_frame_id'] = $item_id;
    } else if ($type === 'avatar') {
        $uStmt = $db->prepare("UPDATE users SET profile_photo = :photo WHERE id = :uid");
        $uStmt->execute([':photo' => $item['image_url'], ':uid' => $user_id]);
        $response['profile_photo'] = $item['image_url'];
    } else if ($type === 'party_frame') {
        $stmt = $db->prepare("UPDATE users SET active_party_frame_id = :iid WHERE id = :uid");
        $stmt->execute([':iid' => $item_id, ':uid' => $user_id]);
        $response['active_party_frame_id'] = $item_id;
    }

    http_response_code(200);
    echo json_encode($response);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
