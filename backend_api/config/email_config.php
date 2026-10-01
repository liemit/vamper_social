<?php
// ============================================================
// VAMPER EMAIL SMTP CONFIGURATION
// ============================================================
// Chọn MODE gửi email:
//   'smtp'       = Gửi thật qua PHPMailer SMTP (RECOMMENDED Production)
//   'phpmail'    = Dùng hàm mail() mặc định PHP (Laragon ko chạy)
//   'debug_only' = Không gửi email thật, chỉ lưu debug OTP code

define('EMAIL_MODE', 'smtp');

// ============================================================
// SMTP SERVER SETTINGS
// ============================================================
// --- Lựa chọn 1: GMAIL SMTP (CẦN App Password, xem SETUP_EMAIL_OTP.md) ---
define('SMTP_HOST', 'smtp.gmail.com');
define('SMTP_PORT', 587);                          // 465 (SSL) hoặc 587 (TLS)
define('SMTP_ENCRYPTION', 'tls');                  // 'ssl' hoặc 'tls'
define('SMTP_USERNAME', 'liembaber00@gmail.com');   // ← THAY bằng email GMAIL thật
define('SMTP_PASSWORD', 'ktpv kwxh eruf nlzc');      // ← THAY bằng GMAIL APP PASSWORD (16 ký tự, không phải mật khẩu Gmail)

// --- Lựa chọn 2: LARAGON MERCURY SMTP LOCAL (không cần internet) ---
// define('SMTP_HOST', 'localhost');
// define('SMTP_PORT', 25);
// define('SMTP_ENCRYPTION', '');
// define('SMTP_USERNAME', '');
// define('SMTP_PASSWORD', '');

// --- Lựa chọn 3: MAILTRAP.IO (Test inbox ảo, free) ---
// define('SMTP_HOST', 'sandbox.smtp.mailtrap.io');
// define('SMTP_PORT', 2525);
// define('SMTP_ENCRYPTION', 'tls');
// define('SMTP_USERNAME', 'mailtrap-username');
// define('SMTP_PASSWORD', 'mailtrap-password');

// ============================================================
// SENDER INFORMATION (Thông tin người gửi)
// ============================================================
define('EMAIL_FROM_EMAIL', 'no-reply@vamper.com');  // Khi dùng Gmail SMTP, sẽ bị Google override bằng SMTP_USERNAME
define('EMAIL_FROM_NAME',  'Vamper Dating App');
define('EMAIL_REPLY_TO',   'support@vamper.com');

// ============================================================
// EMAIL TEMPLATE COLORS (Match với Flutter App theme)
// ============================================================
define('EMAIL_COLOR_PRIMARY',   '#FF3366');
define('EMAIL_COLOR_SECONDARY', '#FF6B9D');
define('EMAIL_COLOR_ACCENT',    '#FFC444');

// ============================================================
// DEVELOPER DEBUG OPTIONS
// ============================================================
define('EMAIL_DEBUG_OUTPUT', false);   // true = echo SMTP logs (chỉ test)
define('EMAIL_ALWAYS_RETURN_DEBUG_OTP', false); // false = KHÔNG trả OTP trong response JSON (production) - user phải tự check email
?>