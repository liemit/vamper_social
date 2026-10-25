<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));
$party_id = $data->party_id ?? null;
$user_id = $data->user_id ?? null;
$action = $data->action ?? 'join'; // 'join' or 'leave'

if (empty($party_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Party ID is required."]);
    exit();
}

try {
    if ($action === 'join' && !empty($user_id)) {
        try {
            $pStmt = $db->prepare("SELECT host_id FROM parties WHERE id = :pid LIMIT 1");
            $pStmt->execute([':pid' => $party_id]);
            $host_id = $pStmt->fetchColumn();

            if ($host_id && $host_id != $user_id) {
                $bStmt = $db->prepare("SELECT id FROM blocked_users WHERE (blocker_id = :h AND blocked_id = :u) OR (blocker_id = :u AND blocked_id = :h) LIMIT 1");
                $bStmt->execute([':h' => $host_id, ':u' => $user_id]);
                if ($bStmt->rowCount() > 0) {
                    http_response_code(403);
                    echo json_encode(["success" => false, "is_blocked" => true, "message" => "You cannot join this party room due to user blocking."]);
                    exit();
                }
            }
        } catch (Exception $e) {}
    }

    if ($action === 'join') {
        $stmt = $db->prepare("UPDATE parties SET participants_count = participants_count + 1 WHERE id = :id");
    } else {
        $stmt = $db->prepare("UPDATE parties SET participants_count = GREATEST(1, participants_count - 1) WHERE id = :id");
    }
    $stmt->execute([':id' => $party_id]);

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Party updated!"
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
