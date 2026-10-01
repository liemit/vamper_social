<?php

require_once __DIR__ . '/../config/email_config.php';

class EmailSender {
    private $phpmailer_available = false;
    private $mail = null;
    private $last_error = '';
    private $debug_log = [];

    public function __construct() {
        // Nạp PHPMailer nếu có trong thư mục libs/phpmailer/
        $phpmailer_path = __DIR__ . '/phpmailer/PHPMailer.php';
        $smtp_path      = __DIR__ . '/phpmailer/SMTP.php';
        $exception_path = __DIR__ . '/phpmailer/Exception.php';

        if (file_exists($phpmailer_path) && file_exists($smtp_path)) {
            require_once $phpmailer_path;
            require_once $smtp_path;
            if (file_exists($exception_path)) require_once $exception_path;
            $this->phpmailer_available = class_exists('PHPMailer\\PHPMailer\\PHPMailer') || class_exists('PHPMailer');
            $this->log("PHPMailer found: " . ($this->phpmailer_available ? "YES" : "NO (class name mismatch)"));
        } else {
            $this->log("PHPMailer files NOT FOUND at: $phpmailer_path");
            $this->log("Expected 3 files: PHPMailer.php, SMTP.php, Exception.php");
            $this->phpmailer_available = false;
        }

        if ($this->phpmailer_available) {
            if (class_exists('PHPMailer\\PHPMailer\\PHPMailer')) {
                $this->mail = new PHPMailer\PHPMailer\PHPMailer(true);
            } else {
                $this->mail = new PHPMailer(true);
            }
            $this->configureSmtp();
        }
    }

    private function configureSmtp() {
        try {
            if (EMAIL_DEBUG_OUTPUT) {
                $this->mail->SMTPDebug = 3; // 3 = full debug
                $this->mail->Debugoutput = function($str, $level) {
                    $this->debug_log[] = "[$level] $str";
                };
            }

            if (defined('SMTP_HOST') && SMTP_HOST !== '' && EMAIL_MODE === 'smtp') {
                $this->mail->isSMTP();
                $this->mail->Host       = SMTP_HOST;
                $this->mail->SMTPAuth   = (SMTP_USERNAME !== '');
                $this->mail->Username   = SMTP_USERNAME;
                $this->mail->Password   = SMTP_PASSWORD;
                $this->mail->SMTPSecure = SMTP_ENCRYPTION; // 'ssl' or 'tls' or ''
                $this->mail->Port       = SMTP_PORT;
                $this->mail->Timeout    = 30;

                // SSL options for localhost self-signed certs (Laragon)
                $this->mail->SMTPOptions = [
                    'ssl' => [
                        'verify_peer'       => false,
                        'verify_peer_name'  => false,
                        'allow_self_signed' => true
                    ]
                ];

                $this->log("SMTP Configured: " . SMTP_HOST . ":" . SMTP_PORT . " (" . SMTP_ENCRYPTION . ")");
            }

            // Sender info
            $from_email = (SMTP_USERNAME && strpos(SMTP_USERNAME, '@') !== false) ? SMTP_USERNAME : EMAIL_FROM_EMAIL;
            $this->mail->setFrom($from_email, EMAIL_FROM_NAME);
            if (EMAIL_REPLY_TO) $this->mail->addReplyTo(EMAIL_REPLY_TO, EMAIL_FROM_NAME);

            // Email format
            $this->mail->isHTML(true);
            $this->mail->CharSet = 'UTF-8';
            $this->mail->WordWrap = 78;

        } catch (Exception $e) {
            $this->last_error = "SMTP Config Error: " . $e->getMessage();
            $this->log($this->last_error);
        }
    }

    // ==========================================================
    // Main send function
    // ==========================================================
    public function send($to, $subject, $html_body, $plain_body = null) {
        $result = [
            'success' => false,
            'mode'    => EMAIL_MODE,
            'method'  => 'unknown',
            'message' => '',
            'log'     => $this->debug_log
        ];

        if (EMAIL_MODE === 'debug_only') {
            $result['success'] = true;
            $result['method']  = 'debug_only (email not sent)';
            $result['message'] = 'Debug mode - Email sẽ không gửi thật';
            return $result;
        }

        // MODE 1: PHPMailer SMTP
        if (EMAIL_MODE === 'smtp' && $this->phpmailer_available && $this->mail !== null) {
            try {
                $this->mail->clearAddresses();
                $this->mail->addAddress($to);
                $this->mail->Subject = $subject;
                $this->mail->Body    = $html_body;
                if ($plain_body) $this->mail->AltBody = $plain_body;

                $sent = $this->mail->send();
                if ($sent) {
                    $result['success'] = true;
                    $result['method']  = 'PHPMailer/SMTP';
                    $result['message'] = 'Email gửi thành công qua SMTP';
                } else {
                    throw new Exception($this->mail->ErrorInfo);
                }
            } catch (Exception $e) {
                $this->last_error = $e->getMessage();
                $this->log("PHPMailer FAILED: " . $e->getMessage());
                // Fallback sang PHP mail() nếu SMTP lỗi
                $fallback = $this->sendNativeMail($to, $subject, $html_body);
                if ($fallback['success']) return $fallback;
                $result['message'] = 'SMTP Lỗi: ' . $e->getMessage() . '. Fallback cũng thất bại.';
            }
            $result['log'] = $this->debug_log;
            return $result;
        }

        // MODE 2: Native PHP mail()
        return $this->sendNativeMail($to, $subject, $html_body);
    }

    // ==========================================================
    // FALLBACK: Native PHP mail() function
    // ==========================================================
    private function sendNativeMail($to, $subject, $html_body) {
        $result = ['success' => false, 'mode' => EMAIL_MODE, 'method' => 'php_mail()', 'message' => ''];

        if (EMAIL_MODE === 'phpmail' || true) { // luôn dùng làm fallback cuối
            $headers  = "MIME-Version: 1.0" . "\r\n";
            $headers .= "Content-type:text/html;charset=UTF-8" . "\r\n";
            $headers .= "From: " . EMAIL_FROM_NAME . " <" . EMAIL_FROM_EMAIL . ">" . "\r\n";
            if (EMAIL_REPLY_TO) $headers .= "Reply-To: " . EMAIL_REPLY_TO . "\r\n";
            $headers .= "X-Mailer: PHP/" . phpversion();

            if (@mail($to, '=?UTF-8?B?'.base64_encode($subject).'?=', $html_body, $headers)) {
                $result['success'] = true;
                $result['message'] = 'Đã gửi bằng PHP mail()';
            } else {
                $result['success'] = false; // trên localhost 99% là false
                $result['message'] = 'PHP mail() trả về FALSE (localhost thiếu SMTP server)';
            }
        }
        return $result;
    }

    // ==========================================================
    // TEMPLATES - Có thể tái sử dụng
    // ==========================================================
    public function wrapOtpEmailHtml($otp_code, $title = "Welcome to Vamper!", $subtitle = "Your verification code is:") {
        $c1 = EMAIL_COLOR_PRIMARY;
        $c2 = EMAIL_COLOR_SECONDARY;
        $c3 = EMAIL_COLOR_ACCENT;

        return "
        <html>
        <head>
            <style>
                body { font-family: 'Segoe UI', Arial, sans-serif; background-color: #f5f5f5; margin: 0; padding: 0; }
                .container { max-width: 600px; margin: 40px auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 16px rgba(0,0,0,0.1); }
                .header { background: linear-gradient(135deg, $c1 0%, $c2 50%, $c3 100%); padding: 40px 20px; text-align: center; }
                .header h1 { color: white; margin: 0; font-size: 32px; font-weight: 700; }
                .heart { font-size: 52px; margin-bottom: 8px; }
                .content { padding: 40px 32px; text-align: center; }
                .content h2 { margin: 0 0 12px 0; font-size: 22px; color: #2D3436; }
                .content p { color: #636E72; font-size: 15px; margin: 8px 0; }
                .otp-box { background: linear-gradient(135deg, $c1 0%, $c2 50%, $c3 100%); color: white; font-size: 52px; font-weight: 800; letter-spacing: 14px; padding: 26px 20px; border-radius: 14px; margin: 28px auto; display: inline-block; box-shadow: 0 6px 16px rgba(255,51,102,0.25); }
                .info { color: #666; font-size: 13px; margin-top: 24px; line-height: 1.6; }
                .footer { background: #f8f8f8; padding: 22px; text-align: center; color: #999; font-size: 12px; }
                .warning { color: $c1; font-weight: 700; margin-top: 18px; font-size: 13px; }
                .code-label { font-size: 12px; text-transform: uppercase; letter-spacing: 2px; color: #B2BEC3; margin-bottom: -10px; }
            </style>
        </head>
        <body>
            <div class='container'>
                <div class='header'>
                    <div class='heart'>❤️</div>
                    <h1>Vamper</h1>
                </div>
                <div class='content'>
                    <h2>$title</h2>
                    <p>$subtitle</p>
                    <p class='code-label'>One-Time Password</p>
                    <div class='otp-box'>$otp_code</div>
                    <p class='info'>Mã này sẽ hết hạn sau <strong>10 phút</strong><br>
                    Nhập mã này trong ứng dụng Vamper để xác thực email.</p>
                    <p class='warning'>⚠️ KHÔNG CHIA SẺ MÃ NÀY VỚI AI KHÁC!</p>
                </div>
                <div class='footer'>
                    <p>Nếu bạn không tạo tài khoản Vamper, vui lòng bỏ qua email này.</p>
                    <p>&copy; 2026 Vamper. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>";
    }

    public function getLastError() { return $this->last_error; }
    public function getDebugLog()  { return $this->debug_log; }

    private function log($msg) {
        $this->debug_log[] = date('[H:i:s] ') . $msg;
    }
}
?>