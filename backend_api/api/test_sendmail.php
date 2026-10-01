<?php
// ============================================================
// TEST: Gửi email OTP thử nghiệm
// ============================================================
// Cách dùng: Browser → http://localhost/vamper_api/api/test_sendmail.php?to=email_cua_ban@xxx.com
// (Thay đổi tham số ?to= thành email muốn test)

require_once '../config/database.php';
require_once '../libs/EmailSender.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST");
header("Content-Type: application/json; charset=UTF-8");

$test_mode = isset($_GET['mode']) ? $_GET['mode'] : 'full';  // full | smtp_only | phpmail_only
$to_email = isset($_GET['to']) ? filter_var($_GET['to'], FILTER_SANITIZE_EMAIL) : '';

if (!$to_email) {
    $to_email = 'test-' . time() . '@example.com';
    $info_msg = "(Thử nghiệm nội bộ - chưa chỉ định email nhận thật. Thêm ?to=email_của_bạn vào URL)";
}

// Tạo mã OTP test
$test_otp = sprintf("%06d", mt_rand(0, 999999));

echo "<h2>📧 VAMPER - TEST GỬI EMAIL OTP</h2>";
echo "<p><strong>Email nhận:</strong> $to_email " . ($info_msg ?? '') . "</p>";
echo "<p><strong>Mã OTP test:</strong> <span style='font-size:26px; color:#FF3366; font-weight:bold; letter-spacing:6px;'>$test_otp</span></p>";
echo "<hr>";

echo "<h3>🔍 Bước 1: Kiểm tra môi trường</h3>";
echo "<ul>";
echo "<li>PHP Version: <strong>" . phpversion() . "</strong></li>";
echo "<li>PHPMailer file exist: ";
$p1 = __DIR__ . '/../libs/phpmailer/PHPMailer.php';
$p2 = __DIR__ . '/../libs/phpmailer/SMTP.php';
if (file_exists($p1) && file_exists($p2)) {
    echo "<span style='color:green; font-weight:bold;'>✅ CÓ (tải xuống và đặt vào đúng thư mục rồi)</span>";
} else {
    echo "<span style='color:red; font-weight:bold;'>❌ CHƯA CÓ → Cần tải 3 file PHPMailer về:<br>
    &nbsp;&nbsp;&nbsp;→ libs/phpmailer/PHPMailer.php<br>
    &nbsp;&nbsp;&nbsp;→ libs/phpmailer/SMTP.php<br>
    &nbsp;&nbsp;&nbsp;→ libs/phpmailer/Exception.php<br><br>
    Tải tại: https://github.com/PHPMailer/PHPMailer/releases</span>";
}
echo "</li>";
echo "<li>PHP mail() function: " . (function_exists('mail') ? "✅ Đã bật" : "❌ Bị tắt") . "</li>";
echo "<li>SMTP Host (config): <strong>" . (SMTP_HOST ?: '(chưa cấu hình)') . "</strong></li>";
echo "<li>SMTP Port: <strong>" . (SMTP_PORT ?: '-') . "</strong></li>";
echo "<li>SMTP Username: <strong>" . (SMTP_USERNAME ?: '(chưa điền)') . "</strong> (<em style='color:gray'>chỉnh trong config/email_config.php</em>)</li>";
echo "<li>Current Email Mode: <strong style='color:blue;'>" . EMAIL_MODE . "</strong></li>";
echo "</ul>";

echo "<hr><h3>📤 Bước 2: Thử GỬI EMAIL</h3>";

$sender = new EmailSender();
$email_html = $sender->wrapOtpEmailHtml(
    $test_otp,
    "Vamper - Email Test Thành Công!",
    "Nếu bạn thấy email này thì cấu hình SMTP đã đúng."
);

echo "<p>Đang gửi...</p>";
$result = $sender->send($to_email, "Vamper Test - Mã OTP: $test_otp", $email_html);

echo "<h4>Kết quả:</h4>";
if ($result['success']) {
    echo "<div style='background: #d4edda; color: #155724; padding: 16px; border-radius: 10px;'>
    ✅ <strong>GỬI THÀNH CÔNG!</strong><br>
    Phương thức: " . $result['method'] . "<br>
    " . $result['message'] . "
    </div>";
} else {
    echo "<div style='background: #f8d7da; color: #721c24; padding: 16px; border-radius: 10px;'>
    ❌ <strong>GỬI THẤT BẠI (hoặc gửi chưa được trên localhost)</strong><br>
    Phương thức: " . $result['method'] . "<br>
    Thông báo: " . $result['message'] . "
    </div>";
}

echo "<h5>Debug logs:</h5>";
echo "<pre style='background:#2d2d2d; color:#eee; padding:12px; border-radius:6px; max-height: 300px; overflow:auto;'>";
if (isset($result['log']) && is_array($result['log']) && count($result['log']) > 0) {
    print_r($result['log']);
} else {
    echo "(Không có log chi tiết - PHPMailer chưa được cài đặt, đang dùng fallback PHP mail())";
}
echo "</pre>";

echo "<hr>";
echo "<h4>📌 CÁCH SỬA NẾU THẤT BẠI TRÊN LARAGON LOCALHOST</h4>";
echo "<ol>";
echo "<li><strong>Quick Test (Không cần tải gì):</strong> Đổi mode thành <code>'debug_only'</code> trong config → email không gửi thật nhưng OTP code vẫn hoạt động trong app (đã được tích hợp)</li>";
echo "<li><strong>Recommend: Gmail SMTP:</strong><br>
    1. Vào Google Account → Security → Bật 2-Step Verification<br>
    2. Vào mục 'App passwords' → Tạo app password 16 ký tự<br>
    3. Dán vào <code>email_config.php</code>: SMTP_USERNAME = gmail_của_bạn, SMTP_PASSWORD = 16 ký tự vừa tạo</li>";
echo "<li><strong>Mailtrap.io (Test chuyên nghiệp, free 1 inbox ảo):</strong><br>
    Tạo account mailtrap.io → copy credentials vào cấu hình SMTP → email sẽ đến hộp thư test của Mailtrap</li>";
echo "</ol>";
?>