<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

$user_id = $data->user_id ?? null;
$target_id = $data->target_id ?? null;
$action = $data->action ?? ''; // 'pass', 'like', 'superlike'

if (empty($user_id) || empty($target_id) || empty($action)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing required swipe parameters."]);
    exit();
}

try {
    $db->beginTransaction();

    // Insert or update swipe action
    $stmt = $db->prepare("INSERT INTO card_swipes (user_id, target_id, action, created_at)
                          VALUES (:user_id, :target_id, :action, NOW())
                          ON DUPLICATE KEY UPDATE action = :action, created_at = NOW()");
    $stmt->execute([
        ':user_id' => $user_id,
        ':target_id' => $target_id,
        ':action' => $action
    ]);

    $is_match = false;

    // Check if target user previously liked or superliked current user
    if ($action === 'like' || $action === 'superlike') {
        $checkStmt = $db->prepare("SELECT id FROM card_swipes WHERE user_id = :target AND target_id = :user AND action IN ('like', 'superlike') LIMIT 1");
        $checkStmt->execute([':target' => $target_id, ':user' => $user_id]);

        if ($checkStmt->rowCount() > 0) {
            $is_match = true;

            // Create conversation in Messages tab
            $u1 = min(intval($user_id), intval($target_id));
            $u2 = max(intval($user_id), intval($target_id));

            $convStmt = $db->prepare("INSERT INTO conversations (user1_id, user2_id, updated_at) VALUES (:u1, :u2, NOW()) ON DUPLICATE KEY UPDATE updated_at = NOW()");
            $convStmt->execute([':u1' => $u1, ':u2' => $u2]);
        }
    }

    $db->commit();

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "is_match" => $is_match,
        "message" => $is_match ? "It's a Match! 🎉" : "Swipe recorded."
    ]);

} catch (Exception $e) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
