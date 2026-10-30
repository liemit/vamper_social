<?php
require_once '../../config/cors.php';
require_once '../../config/database.php';
require_once '../../../libs/AdminTools.php';
require_once '../../libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();
$adminId = authenticateApiUser($db);
assertAdminApiPermission($db, (int)$adminId, 'users');

$data = json_decode(file_get_contents("php://input"));

if (!is_object($data) || empty($data->target_user_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Target User ID is required."]);
    exit;
}

try {
    $targetId = filter_var($data->target_user_id, FILTER_VALIDATE_INT);
    if (!$targetId) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Invalid target user ID."]);
        exit;
    }

    $db->beginTransaction();
    $target = $db->prepare("SELECT role, is_active FROM users WHERE id = :id FOR UPDATE");
    $target->execute([':id' => $targetId]);
    $targetUser = $target->fetch(PDO::FETCH_ASSOC);
    if (!$targetUser || $targetUser['role'] === 'admin' || $targetId === (int)$adminId) {
        $db->rollBack();
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Cannot change this administrator account."]);
        exit;
    }

    $newStatus = (int)!((int)$targetUser['is_active']);
    $stmt = $db->prepare("UPDATE users SET is_active = :status WHERE id = :id");
    $stmt->execute([':status' => $newStatus, ':id' => $targetId]);
    writeAdminAudit($db, (int)$adminId, $newStatus ? 'user_unblocked' : 'user_blocked', 'user', $targetId, ['reason' => 'Admin app moderation']);
    $db->commit();

    echo json_encode([
        "success" => true,
        "message" => $newStatus ? "User unbanned" : "User banned",
        "data" => ["is_active" => $newStatus]
    ]);
} catch (PDOException $e) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(500);
    error_log('Admin user status update failed: ' . $e->getMessage());
    echo json_encode(["success" => false, "message" => "Unable to update user status."]);
}
?>
