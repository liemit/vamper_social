<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/libs/LiveKit.php';

$database = new Database();
$db = $database->getConnection();
$hostId = authenticateApiUser($db);

$data = json_decode(file_get_contents("php://input"));
$party_id = $data->party_id ?? null;

if (empty($party_id) || !filter_var($party_id, FILTER_VALIDATE_INT)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "A valid party ID is required."]);
    exit();
}

try {
    $partyQuery = $db->prepare('SELECT host_id FROM parties WHERE id = :id LIMIT 1');
    $partyQuery->execute([':id' => $party_id]);
    $partyHostId = $partyQuery->fetchColumn();
    if ($partyHostId === false) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Party room not found."]);
        exit();
    }
    if ((int)$partyHostId !== $hostId) {
        http_response_code(403);
        echo json_encode(["success" => false, "message" => "Only the party host can end this room."]);
        exit();
    }

    $settings = liveKitSettings();
    if ($settings !== null) {
        liveKitAdminRequest($settings, 'DeleteRoom', ['room' => 'vamper-party-' . (int)$party_id]);
    }

    $db->beginTransaction();
    foreach (['party_members', 'party_messages', 'party_events'] as $table) {
        $tableExists = $db->query('SHOW TABLES LIKE ' . $db->quote($table))->fetchColumn();
        if ($tableExists !== false) {
            $deleteRelated = $db->prepare("DELETE FROM `$table` WHERE party_id = :party_id");
            $deleteRelated->execute([':party_id' => $party_id]);
        }
    }
    $closeParty = $db->prepare('UPDATE parties SET is_live = 0, participants_count = 0 WHERE id = :id AND host_id = :host_id');
    $closeParty->execute([':id' => $party_id, ':host_id' => $hostId]);
    $db->commit();

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Party room ended successfully."
    ]);

} catch (Throwable $error) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    error_log('Unable to end party: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Unable to end the party room."]);
}
?>
