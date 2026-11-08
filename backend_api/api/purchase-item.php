<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/ApiAuth.php';
require_once __DIR__ . '/../libs/AdminTools.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));
$user_id = authenticateApiUser($db);
$item_id = filter_var($data->item_id ?? null, FILTER_VALIDATE_INT);

if (!$item_id) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Item ID is required."]);
    exit();
}

try {
    ensureShopActiveColumn($db);
    ensureVpcLedgerTable($db);
    $db->beginTransaction();

    // Lock the account balance so concurrent purchases cannot overspend.
    $uStmt = $db->prepare("SELECT coins FROM users WHERE id = :uid FOR UPDATE");
    $uStmt->execute([':uid' => $user_id]);
    $userCoins = $uStmt->fetchColumn();
    if ($userCoins === false) {
        $db->rollBack();
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "User not found."]);
        exit();
    }

    $ownedStmt = $db->prepare("SELECT 1 FROM user_items WHERE user_id = :uid AND item_id = :iid LIMIT 1");
    $ownedStmt->execute([':uid' => $user_id, ':iid' => $item_id]);
    if ($ownedStmt->fetchColumn()) {
        $db->commit();
        echo json_encode([
            "success" => true,
            "message" => "Item already owned.",
            "already_owned" => true,
            "remaining_coins" => (int)$userCoins
        ]);
        exit();
    }

    $iStmt = $db->prepare("SELECT price_coins, type, is_active FROM shop_items WHERE id = :iid LIMIT 1");
    $iStmt->execute([':iid' => $item_id]);
    $item = $iStmt->fetch(PDO::FETCH_ASSOC);

    if (!$item) {
        $db->rollBack();
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Item not found."]);
        exit();
    }
    if ($item['type'] === 'party_frame') {
        $db->rollBack();
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Party frames are no longer available in the shop."]);
        exit();
    }
    if (!(int)$item['is_active']) {
        $db->rollBack();
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "This item is no longer available."]);
        exit();
    }
    $price = (int)$item['price_coins'];
    if ($price < 0) {
        $db->rollBack();
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Item price is invalid."]);
        exit();
    }

    if ((int)$userCoins < $price) {
        $db->rollBack();
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Insufficient VPC coins! Please recharge."]);
        exit();
    }

    if ($price > 0) {
        $dStmt = $db->prepare("UPDATE users SET coins = coins - :price WHERE id = :uid AND coins >= :minimum");
        $dStmt->execute([':price' => $price, ':minimum' => $price, ':uid' => $user_id]);
        if ($dStmt->rowCount() !== 1) {
            $db->rollBack();
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "Insufficient VPC coins! Please recharge."]);
            exit();
        }
        recordVpcLedger(
            $db,
            (int)$user_id,
            -$price,
            (int)$userCoins,
            (int)$userCoins - $price,
            'shop_purchase',
            'Shop item purchase',
            (string)$item_id
        );
    }

    $buyStmt = $db->prepare("INSERT INTO user_items (user_id, item_id, purchased_at) VALUES (:uid, :iid, NOW())");
    $buyStmt->execute([':uid' => $user_id, ':iid' => $item_id]);

    $db->commit();

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Item purchased successfully!",
        "type" => $item['type'],
        "remaining_coins" => (int)$userCoins - $price
    ]);

} catch (Exception $e) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
