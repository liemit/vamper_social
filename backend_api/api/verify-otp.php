<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

// Get posted data
$data = json_decode(file_get_contents("php://input"));

// Normalize input: trim and lowercase email, trim OTP
$email = isset($data->email) ? strtolower(trim((string)$data->email)) : '';
$otp_from_user = isset($data->otp_code) ? trim((string)$data->otp_code) : '';

// Validate input
if (empty($email) || empty($otp_from_user)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Email and OTP code are required."
    ]);
    exit();
}

// Validate email format
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Invalid email format."
    ]);
    exit();
}

// Normalize OTP for leading zero cases
$otp_normalized = sprintf("%06d", (int)$otp_from_user);

try {
    // Check for valid, unused, and non-expired OTP
    $query = "SELECT id, otp_code, is_used, expires_at
              FROM otp_codes 
              WHERE email = :email 
              AND is_used = 0
              AND expires_at > NOW()
              ORDER BY created_at DESC 
              LIMIT 1";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(":email", $email);
    $stmt->execute();
    $matched_otp_row = $stmt->fetch(PDO::FETCH_ASSOC);

    $is_match = false;
    if ($matched_otp_row) {
        $otp_in_db = trim((string)$matched_otp_row['otp_code']);
        $otp_in_db_normalized = sprintf("%06d", (int)$otp_in_db);

        // Robust comparison
        if ($otp_from_user == $otp_in_db || $otp_normalized == $otp_in_db_normalized) {
            $is_match = true;
        }
    }

    if (!$is_match) {
        $debug_info = "Verification failed. ";

        $stmt_check = $db->prepare("SELECT id FROM users WHERE email = :email LIMIT 1");
        $stmt_check->bindParam(":email", $email);
        $stmt_check->execute();
        if ($stmt_check->rowCount() == 0) {
            $debug_info .= "Email not registered.";
        } else {
            $debug_info .= "Incorrect code or expired.";
        }

        http_response_code(400);
        echo json_encode([
            "success" => false,
            "message" => "Invalid or expired OTP code. Please check again or resend.",
            "debug_info" => $debug_info
        ]);
        exit();
    }

    // ============================================
    // ✅ OTP MATCH - Xác nhận hợp lệ
    // ============================================

    // Bước 2: Mark current OTP as used
    $stmt_update_otp = $db->prepare("UPDATE otp_codes SET is_used = 1 WHERE id = :id");
    $stmt_update_otp->bindParam(":id", $matched_otp_row['id']);
    $stmt_update_otp->execute();

    // Bước 3: Update user's verified status
    try {
        $stmt_user = $db->prepare("UPDATE users SET email_verified = 1, is_verified = 1 WHERE email = :email");
        $stmt_user->bindParam(":email", $email);
        $stmt_user->execute();
    } catch (PDOException $e_verify) {
        // Fallback
        $stmt_user2 = $db->prepare("UPDATE users SET is_verified = 1 WHERE email = :email");
        $stmt_user2->bindParam(":email", $email);
        $stmt_user2->execute();
    }

    // Bước 4: Get updated user data
    try {
        $stmt_final = $db->prepare("SELECT id, full_name, email, profile_photo, is_verified, created_at FROM users WHERE email = :email LIMIT 1");
    } catch (PDOException $e_sel) {
        $stmt_final = $db->prepare("SELECT * FROM users WHERE email = :email LIMIT 1");
    }
    $stmt_final->bindParam(":email", $email);
    $stmt_final->execute();
    $user = $stmt_final->fetch(PDO::FETCH_ASSOC);

    if (!isset($user['email_verified'])) $user['email_verified'] = 1;
    if (!isset($user['is_verified']))    $user['is_verified'] = 1;

    // Generate token
    $token = base64_encode($user['id'] . ':' . time());

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Email verified successfully!",
        "data" => [
            "user" => $user,
            "token" => $token
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
