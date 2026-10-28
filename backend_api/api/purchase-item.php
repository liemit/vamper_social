<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));
$user_id = $data->user_id ?? null;
$item_id = $data->item_id ?? null;

if (empty($user_id) || empty($item_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "User ID and Item ID are required."]);
    exit();
}

try {
    $db->beginTransaction();

    // 1. Get item price & type
    $iStmt = $db->prepare("SELECT price_coins, type FROM shop_items WHERE id = :iid LIMIT 1");
    $iStmt->execute([':iid' => $item_id]);
    $item = $iStmt->fetch(PDO::FETCH_ASSOC);

    if (!$item) {
        $db->rollBack();
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Item not found."]);
        exit();
    }

    $price = (int)$item['price_coins'];

    // 2. Check user coin balance
    $uStmt = $db->prepare("SELECT coins FROM users WHERE id = :uid LIMIT 1");
    $uStmt->execute([':uid' => $user_id]);
    $userCoins = (int)$uStmt->fetchColumn();

    if ($userCoins < $price) {
        $db->rollBack();
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Insufficient VPC coins! Please recharge."]);
        exit();
    }

    // 3. Deduct coins
    $dStmt = $db->prepare("UPDATE users SET coins = coins - :price WHERE id = :uid");
    $dStmt->execute([':price' => $price, ':uid' => $user_id]);

    // 4. Insert into user_items
    $buyStmt = $db->prepare("INSERT IGNORE INTO user_items (user_id, item_id, purchased_at) VALUES (:uid, :iid, NOW())");
    $buyStmt->execute([':uid' => $user_id, ':iid' => $item_id]);

    $db->commit();

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Item purchased successfully!",
        "remaining_coins" => $userCoins - $price
    ]);

} catch (Exception $e) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database error: " . $e->getMessage()]);
}
?>
