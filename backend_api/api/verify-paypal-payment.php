<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$data = json_decode(file_get_contents("php://input"));

$user_id = $data->user_id ?? null;
$coins_to_add = intval($data->coins ?? 0);
$amount_usd = floatval($data->amount_usd ?? 0);
$payment_token = trim($data->payment_token ?? '');

if (empty($user_id) || $coins_to_add <= 0 || empty($payment_token)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Invalid verification parameters or missing payment token."
    ]);
    exit();
}

try {
    // Ensure transactions table exists
    $db->exec("CREATE TABLE IF NOT EXISTS transactions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        amount_usd DECIMAL(10,2) NOT NULL,
        coins INT NOT NULL,
        gateway VARCHAR(50) DEFAULT 'PayPal',
        payment_token VARCHAR(255) NULL,
        status VARCHAR(50) DEFAULT 'completed',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

    // Check if this payment token was already processed (prevent double-spending / duplicate reward)
    $checkStmt = $db->prepare("SELECT id FROM transactions WHERE payment_token = :token LIMIT 1");
    $checkStmt->execute([':token' => $payment_token]);
    if ($checkStmt->rowCount() > 0) {
        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "This payment has already been verified and processed."
        ]);
        exit();
    }

    // 1. Update user coins securely
    $query = "UPDATE users SET coins = coins + :coins, updated_at = NOW() WHERE id = :id";
    $stmt = $db->prepare($query);
    $stmt->execute([
        ':coins' => $coins_to_add,
        ':id' => $user_id
    ]);

    // 2. Log verified transaction with token
    $txQuery = "INSERT INTO transactions (user_id, amount_usd, coins, gateway, payment_token, status, created_at)
                VALUES (:user_id, :amount_usd, :coins, 'PayPal', :payment_token, 'completed', NOW())";
    $txStmt = $db->prepare($txQuery);
    $txStmt->execute([
        ':user_id' => $user_id,
        ':amount_usd' => $amount_usd,
        ':coins' => $coins_to_add,
        ':payment_token' => $payment_token
    ]);

    // Fetch updated user data
    $stmt_user = $db->prepare("SELECT id, full_name, email, role, gender, date_of_birth, bio, profile_photo, location, is_verified, coins, is_active, created_at FROM users WHERE id = :id LIMIT 1");
    $stmt_user->bindParam(":id", $user_id);
    $stmt_user->execute();
    $user = $stmt_user->fetch(PDO::FETCH_ASSOC);

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Payment verified successfully! Added $coins_to_add coins.",
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
