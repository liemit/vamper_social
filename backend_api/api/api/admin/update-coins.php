<?php
require_once '../../config/cors.php';
require_once '../../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

if (empty($data->target_user_id) || !isset($data->coins)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Target User ID and Coin amount are required."]);
    exit;
}

try {
    $stmt = $db->prepare("UPDATE users SET coins = :c WHERE id = :id");
    $stmt->bindParam(':c', $data->coins);
    $stmt->bindParam(':id', $data->target_user_id);

    if ($stmt->execute()) {
        echo json_encode([
            "success" => true,
            "message" => "VPC Balance updated successfully."
        ]);
    }
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>
