<?php
require_once '../config/database.php';
require_once '../libs/EmailSender.php';

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

$database = new Database();
$db = $database->getConnection();

// Get posted data
$data = json_decode(file_get_contents("php://input"));

// Validate input
if (empty($data->full_name) || empty($data->email) || empty($data->password)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Please provide full name, email, and password."
    ]);
    exit();
}

// Validate email format
if (!filter_var($data->email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Invalid email format."
    ]);
    exit();
}

// Normalize email: trim and lowercase
$email = strtolower(trim((string)$data->email));

// Check if email already exists
try {
    $query = "SELECT id FROM users WHERE email = :email LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":email", $email);
    $stmt->execute();

    if ($stmt->rowCount() > 0) {
        http_response_code(409);
        echo json_encode([
            "success" => false,
            "message" => "Email already exists. Please use a different email."
        ]);
        exit();
    }

    // Insert new user
    $query = "INSERT INTO users (full_name, email, password, created_at) 
              VALUES (:full_name, :email, :password, NOW())";
    
    $stmt = $db->prepare($query);
    
    // Hash password
    $hashed_password = password_hash($data->password, PASSWORD_DEFAULT);
    
    // Bind values
    $stmt->bindParam(":full_name", $data->full_name);
    $stmt->bindParam(":email", $email);
    $stmt->bindParam(":password", $hashed_password);

    if ($stmt->execute()) {
        $user_id = $db->lastInsertId();
        
        // Get user data
        $query = "SELECT id, full_name, email, profile_photo, is_verified, created_at 
                  FROM users WHERE id = :id";
        $stmt = $db->prepare($query);
        $stmt->bindParam(":id", $user_id);
        $stmt->execute();
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        // Generate simple token (in production, use JWT)
        $token = base64_encode($user['id'] . ':' . time());

        // ============================================
        // AUTO-SEND OTP AFTER REGISTRATION - VIA EMAIL SENDER CLASS
        // ============================================
        $otp_sent = false;
        $otp_code = null;
        $email_send_result = null;

        try {
            // Generate 6-digit OTP
            $otp_code = sprintf("%06d", mt_rand(0, 999999));

            // ⚠️ KHÔNG XÓA / KHÔNG MARK is_used OTP CŨ NỮA
            // Vì email cũ có thể chưa đến user (đặc biệt temp-mail)
            // → User được phép dùng OTP nào cũng được, miễn là: chưa dùng + chưa hết giờ
            // Insert new OTP - Tăng thời gian hiệu lực lên 30 PHÚT (temp-mail đôi khi nhận chậm)
            $query = "INSERT INTO otp_codes (email, otp_code, expires_at) 
                      VALUES (:email, :otp_code, DATE_ADD(NOW(), INTERVAL 30 MINUTE))";
            $stmt_otp = $db->prepare($query);
            $stmt_otp->bindParam(":email", $email);
            $stmt_otp->bindParam(":otp_code", $otp_code);
            $stmt_otp->execute();

            // ===== GỬI EMAIL BẰNG EmailSender class (PHPMailer/SMTP) =====
            $emailSender = new EmailSender();
            $email_html = $emailSender->wrapOtpEmailHtml(
                $otp_code,
                "Welcome to Vamper!",
                "Cảm ơn bạn đã đăng ký. Mã xác thực email của bạn là:"
            );
            $email_send_result = $emailSender->send(
                $email,
                "Vamper - Your Verification Code: $otp_code",
                $email_html,
                "Vamper verification code: $otp_code (expires in 30 minutes)"
            );
            $otp_sent = $email_send_result['success'];

        } catch (Exception $e) {
            // OTP generation failed, but user is registered
            $otp_sent = false;
        }

        // ===== Message trả về =====
        $response_message = "Registration successful! ";
        if ($otp_sent) {
            $response_message .= "Mã OTP đã được gửi đến email của bạn.";
        } else {
            // Nếu localhost chưa cấu hình SMTP thì báo rõ ràng
            if (EMAIL_MODE === 'debug_only') {
                $response_message .= "(DEBUG MODE: Email sẽ không gửi thật, vui lòng kiểm tra inbox hoặc dùng debug OTP.)";
            } else {
                $response_message .= "Vui lòng kiểm tra email (kể cả thư rác) để lấy mã OTP xác thực.";
            }
        }

        http_response_code(201);
        echo json_encode([
            "success" => true,
            "message" => $response_message,
            "data" => [
                "user" => $user,
                "token" => $token,
                "otp_sent" => $otp_sent,
                "email_info" => [
                    "mode"   => EMAIL_MODE,
                    "method" => $email_send_result ? $email_send_result['method'] : 'unknown',
                    "note"   => $email_send_result ? $email_send_result['message'] : ''
                ],
                "debug" => EMAIL_ALWAYS_RETURN_DEBUG_OTP ? [
                    "otp_code" => $otp_code,
                    "dev_note" => "DEV ONLY - OTP code dành cho developer test khi SMTP không gửi được email. Không show cái này cho user."
                ] : null
            ]
        ]);
    } else {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Unable to register user. Please try again."
        ]);
    }

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Database error: " . $e->getMessage()
    ]);
}
?>
