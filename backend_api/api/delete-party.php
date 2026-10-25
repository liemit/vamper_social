<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));
$party_id = $data->party_id ?? null;
$host_id = $data->host_id ?? null;

if (empty($party_id) || empty($host_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Party ID and Host ID are required."]);
    exit();
}

try {
    // Delete or mark as closed
    $stmt = $db->prepare("DELETE FROM parties WHERE id = :id AND host_id = :hid");
    $stmt->execute([':id' => $party_id, ':hid' => $host_id]);

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Party room deleted successfully!"
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
