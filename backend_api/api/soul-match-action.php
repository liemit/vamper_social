<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

$user_id = $data->user_id ?? null;
$partner_id = $data->partner_id ?? null;
$action = $data->action ?? ''; // 'like' or 'pass'

if (empty($user_id) || empty($partner_id) || empty($action)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing required parameters."]);
    exit();
}

try {
    $db->beginTransaction();

    // Check if partner already liked user
    $checkStmt = $db->prepare("SELECT id, status FROM soul_matches WHERE user1_id = :partner AND user2_id = :user LIMIT 1");
    $checkStmt->execute([':partner' => $partner_id, ':user' => $user_id]);

    $is_mutual = false;
    $myStatus = ($action === 'like') ? 1 : 2; // 1: liked, 2: passed

    if ($checkStmt->rowCount() > 0) {
        $row = $checkStmt->fetch(PDO::FETCH_ASSOC);
        // If partner already liked (status 1) and current user also likes (action 'like')
        if ($row['status'] == 1 && $action === 'like') {
            $is_mutual = true;
            // Update partner's record to mutual_matched (3)
            $upd = $db->prepare("UPDATE soul_matches SET status = 3 WHERE id = :id");
            $upd->execute([':id' => $row['id']]);
        }
    }

    // Insert current user's match action record
    $statusToInsert = $is_mutual ? 3 : $myStatus;
    $ins = $db->prepare("INSERT INTO soul_matches (user1_id, user2_id, status, created_at) VALUES (:user, :partner, :status, NOW())");
    $ins->execute([
        ':user' => $user_id,
        ':partner' => $partner_id,
        ':status' => $statusToInsert
    ]);

    // If mutual match, create conversation for Messages inbox
    if ($is_mutual) {
        $u1 = min(intval($user_id), intval($partner_id));
        $u2 = max(intval($user_id), intval($partner_id));

        $convStmt = $db->prepare("INSERT INTO conversations (user1_id, user2_id, updated_at) VALUES (:u1, :u2, NOW()) ON DUPLICATE KEY UPDATE updated_at = NOW()");
        $convStmt->execute([':u1' => $u1, ':u2' => $u2]);
    }

    $db->commit();

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "is_mutual" => $is_mutual,
        "message" => $is_mutual ? "It's a Mutual Soul Match! Added to Messages." : "Action recorded."
    ]);

} catch (Exception $e) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
