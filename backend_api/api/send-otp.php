<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once '../libs/EmailSender.php';

$database = new Database();
$db = $database->getConnection();

// Get posted data
$data = json_decode(file_get_contents("php://input"));

// Normalize email: trim and lowercase
$email = strtolower(trim((string)($data->email ?? '')));

// Validate input
if (empty($email)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Email is required."
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

try {
    // Check if user exists
    $query = "SELECT id FROM users WHERE email = :email LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":email", $email);
    $stmt->execute();

    if ($stmt->rowCount() == 0) {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "message" => "Email not found."
        ]);
        exit();
    }

    // Generate 6-digit OTP
    $otp_code = sprintf("%06d", mt_rand(0, 999999));

    $query = "INSERT INTO otp_codes (email, otp_code, expires_at)
              VALUES (:email, :otp_code, DATE_ADD(NOW(), INTERVAL 30 MINUTE))";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":email", $email);
    $stmt->bindParam(":otp_code", $otp_code);

    if ($stmt->execute()) {
        $emailSender = new EmailSender();
        $email_html = $emailSender->wrapOtpEmailHtml(
            $otp_code,
            "Email Verification",
            "Mã OTP xác thực tài khoản Vamper của bạn là:"
        );
        $email_result = $emailSender->send(
            $email,
            "Vamper - Mã OTP: $otp_code",
            $email_html,
            "Vamper OTP code: $otp_code (expires in 30 minutes)"
        );
        $email_sent = $email_result['success'];

        if ($email_sent) {
            $message = "Mã OTP đã gửi thành công đến " . maskEmail($email) . ". Vui lòng kiểm tra email (kể cả thư rác) và nhập mã trong vòng 30 phút.";
        } else {
            $message = "Vui lòng kiểm tra email để lấy mã OTP (30 phút).";
        }

        http_response_code(200);
        echo json_encode([
            "success" => true,
            "message" => $message,
            "email_info" => [
                "mode"       => EMAIL_MODE,
                "method"     => $email_result['method'],
                "sent"       => $email_sent,
                "smtp_note"  => $email_result['message']
            ]
        ]);

    } else {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Unable to generate OTP. Please try again."
        ]);
    }

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}

function maskEmail($email) {
    $parts = explode("@", $email);
    $name = $parts[0];
    $domain = $parts[1] ?? 'email.com';
    
    $masked_name = substr($name, 0, 2) . str_repeat("*", max(1, strlen($name) - 2));
    return $masked_name . "@" . $domain;
}
?>
