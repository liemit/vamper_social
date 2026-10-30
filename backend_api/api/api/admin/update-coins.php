<?php
require_once '../../config/cors.php';
require_once '../../config/database.php';
require_once '../../../libs/AdminTools.php';
require_once '../../libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();
$adminId = authenticateApiUser($db);
assertAdminApiPermission($db, (int)$adminId, 'finance');

$data = json_decode(file_get_contents("php://input"));

if (!is_object($data) || empty($data->target_user_id) || !isset($data->coins)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Target User ID and Coin amount are required."]);
    exit;
}

try {
    $targetId = filter_var($data->target_user_id, FILTER_VALIDATE_INT);
    $coins = filter_var($data->coins, FILTER_VALIDATE_INT);
    if (!$targetId || $coins === false || $coins < 0) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Invalid user ID or balance."]);
        exit;
    }
    ensureVpcLedgerTable($db);
    $db->beginTransaction();
    $balanceQuery = $db->prepare("SELECT coins FROM users WHERE id = :id FOR UPDATE");
    $balanceQuery->execute([':id' => $targetId]);
    $before = $balanceQuery->fetchColumn();
    if ($before === false) {
        $db->rollBack();
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "User not found."]);
        exit;
    }
    $stmt = $db->prepare("UPDATE users SET coins = :c WHERE id = :id");
    $stmt->execute([':c' => $coins, ':id' => $targetId]);
    $delta = $coins - (int)$before;
    if ($delta !== 0) {
        recordVpcLedger($db, $targetId, $delta, (int)$before, $coins, 'admin_adjustment', 'Admin app balance update', null, (int)$adminId);
        writeAdminAudit($db, (int)$adminId, 'vpc_adjusted', 'user', $targetId, ['delta' => $delta]);
    }
    $db->commit();
    echo json_encode([
        "success" => true,
        "message" => "VPC Balance updated successfully."
    ]);
} catch (PDOException $e) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(500);
    error_log('Admin VPC API update failed: ' . $e->getMessage());
    echo json_encode(["success" => false, "message" => "Unable to update VPC balance."]);
}
?>
