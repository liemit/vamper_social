<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));
$user_id = $data->user_id ?? null;
$item_id = $data->item_id ?? null; // null to unequip
$type = $data->type ?? 'profile_frame'; // 'profile_frame', 'avatar', or 'party_frame'
$party_id = $data->party_id ?? null;

if (empty($user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID is required."]);
    exit();
}

try {
    $response = [
        "success" => true,
        "message" => "Item equipped successfully!",
        "type" => $type,
        "item_id" => $item_id ? (int)$item_id : null
    ];

    if ($type === 'profile_frame') {
        $stmt = $db->prepare("UPDATE users SET active_profile_frame_id = :iid WHERE id = :uid");
        $stmt->execute([':iid' => $item_id ? (int)$item_id : null, ':uid' => $user_id]);
        $response['active_profile_frame_id'] = $item_id ? (int)$item_id : null;
    } else if ($type === 'avatar') {
        if (!empty($item_id)) {
            $iStmt = $db->prepare("SELECT image_url FROM shop_items WHERE id = :iid LIMIT 1");
            $iStmt->execute([':iid' => $item_id]);
            $avatarUrl = $iStmt->fetchColumn();

            if ($avatarUrl) {
                $uStmt = $db->prepare("UPDATE users SET profile_photo = :photo WHERE id = :uid");
                $uStmt->execute([':photo' => $avatarUrl, ':uid' => $user_id]);
                $response['profile_photo'] = $avatarUrl;
            }
        }
    } else if ($type === 'party_frame') {
        try {
            $db->exec("ALTER TABLE users ADD COLUMN IF NOT EXISTS active_party_frame_id INT NULL;");
        } catch (Exception $e) {}

        $stmt = $db->prepare("UPDATE users SET active_party_frame_id = :iid WHERE id = :uid");
        $stmt->execute([':iid' => $item_id ? (int)$item_id : null, ':uid' => $user_id]);
        $response['active_party_frame_id'] = $item_id ? (int)$item_id : null;

        if (!empty($party_id)) {
            $pStmt = $db->prepare("UPDATE parties SET active_frame_id = :iid WHERE id = :pid AND host_id = :uid");
            $pStmt->execute([':iid' => $item_id ? (int)$item_id : null, ':pid' => $party_id, ':uid' => $user_id]);
        }
    }

    http_response_code(200);
    echo json_encode($response);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
