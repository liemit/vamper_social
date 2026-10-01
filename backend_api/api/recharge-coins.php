<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

$user_id = $data->user_id ?? null;
$coins_to_add = intval($data->coins ?? 0);

if (empty($user_id) || $coins_to_add <= 0) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Invalid user ID or coin amount."
    ]);
    exit();
}

try {
    // Auto-create transactions table if not exists
    $db->exec("CREATE TABLE IF NOT EXISTS transactions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        amount_usd DECIMAL(10,2) NOT NULL,
        coins INT NOT NULL,
        gateway VARCHAR(50) DEFAULT 'PayPal',
        status VARCHAR(50) DEFAULT 'completed',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    // Estimate USD amount based on packages (100 coins = 4.99, 500 = 19.99, 1200 = 39.99, 3000 = 89.99, or approx $0.035 per coin)
    $amount_usd = $coins_to_add * 0.035;
    if ($coins_to_add == 100) $amount_usd = 4.99;
    elseif ($coins_to_add == 500) $amount_usd = 19.99;
    elseif ($coins_to_add == 1200) $amount_usd = 39.99;
    elseif ($coins_to_add == 3000) $amount_usd = 89.99;

    // 1. Update user coins
    $query = "UPDATE users SET coins = coins + :coins, updated_at = NOW() WHERE id = :id";
    $stmt = $db->prepare($query);
    $stmt->execute([
        ':coins' => $coins_to_add,
        ':id' => $user_id
    ]);

    // 2. Log transaction
    $txQuery = "INSERT INTO transactions (user_id, amount_usd, coins, gateway, status, created_at)
                VALUES (:user_id, :amount_usd, :coins, 'PayPal', 'completed', NOW())";
    $txStmt = $db->prepare($txQuery);
    $txStmt->execute([
        ':user_id' => $user_id,
        ':amount_usd' => $amount_usd,
        ':coins' => $coins_to_add
    ]);

    // Fetch updated user data
    $stmt_user = $db->prepare("SELECT id, full_name, email, role, gender, date_of_birth, bio, profile_photo, location, is_verified, coins, is_active, created_at FROM users WHERE id = :id LIMIT 1");
    $stmt_user->bindParam(":id", $user_id);
    $stmt_user->execute();
    $user = $stmt_user->fetch(PDO::FETCH_ASSOC);

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Successfully recharged $coins_to_add coins!",
        "data" => [
            "user" => $user
        ]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
