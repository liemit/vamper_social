# 📧 SETUP EMAIL OTP - HƯỚNG DẪN CHI TIẾT

## ✅ ĐÃ HOÀN THÀNH

### 1. **Database Table**
- ✅ Created `otp_codes` table
- ✅ Added `email_verified` column to users

### 2. **Backend APIs**
- ✅ `/api/send-otp.php` - Gửi OTP code
- ✅ `/api/verify-otp.php` - Xác thực OTP code
- ✅ Updated `/api/register.php` - Auto-send OTP sau khi đăng ký

### 3. **Flutter Integration**
- ✅ AuthService: `sendOtp()` và `verifyOtp()` methods
- ✅ VerificationScreen: Kết nối với API thực tế
- ✅ Resend OTP với countdown

---

## 🚀 CÀI ĐẶT (5 BƯỚC)

### **BƯỚC 1: Import Database Schema**

```bash
# Mở HeidiSQL hoặc phpMyAdmin
# Select database: vamper_social
# Import file: database_otp.sql
```

Hoặc chạy SQL:
```sql
CREATE TABLE IF NOT EXISTS otp_codes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    otp_code VARCHAR(6) NOT NULL,
    expires_at DATETIME NOT NULL,
    is_used TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS email_verified TINYINT(1) DEFAULT 0 AFTER is_verified;
```

---

### **BƯỚC 2: Copy Backend Files**

Đảm bảo các file sau đã có trong `C:\laragon\www\vamper_api\api\`:

```
vamper_api/
├── api/
│   ├── register.php      (đã cập nhật - auto send OTP)
│   ├── send-otp.php      (mới tạo)
│   └── verify-otp.php    (mới tạo)
```

---

### **BƯỚC 3: Test Backend API**

#### Test 1: Send OTP
```bash
# URL: http://localhost/vamper_api/api/send-otp.php
# Method: POST
# Body:
{
  "email": "test@gmail.com"
}

# Response:
{
  "success": true,
  "message": "OTP sent successfully to t***@gmail.com",
  "debug": {
    "otp_code": "123456",  // Hiển thị trong development
    "expires_at": "2026-08-14 12:30:00",
    "email_sent": false,   // false trên localhost
    "note": "PHP mail() may not work on localhost"
  }
}
```

#### Test 2: Verify OTP
```bash
# URL: http://localhost/vamper_api/api/verify-otp.php
# Method: POST
# Body:
{
  "email": "test@gmail.com",
  "otp_code": "123456"
}

# Response:
{
  "success": true,
  "message": "Email verified successfully!",
  "data": {
    "user": {...},
    "token": "..."
  }
}
```

---

### **BƯỚC 4: Chạy Flutter App**

```bash
cd C:\Users\liemb\StudioProjects\vamper
flutter pub get
flutter run -d chrome
```

---

### **BƯỚC 5: Test Flow Hoàn Chỉnh**

1. **Register** với email thật
2. Backend tự động:
   - Tạo user trong database
   - Generate OTP 6 số
   - Lưu OTP vào `otp_codes` table
   - **Thử gửi email** (có thể fail trên localhost)
   - Return OTP code trong response (debug mode)
3. **Check Console** → Xem OTP code
4. **Nhập OTP** trong app
5. API verify OTP → Mark as used → Update `email_verified = 1`
6. Chuyển sang Complete Profile

---

## 📧 TẠI SAO EMAIL KHÔNG GỬI?

### Vấn đề: PHP mail() không hoạt động trên localhost

**Nguyên nhân:**
- Laragon mặc định **KHÔNG** cấu hình SMTP server
- PHP `mail()` function cần mail server để gửi email
- Localhost không có mail server

### ✅ GIẢI PHÁP (3 Options):

---

### **OPTION 1: Dùng DEBUG MODE (Recommended cho development)**

**Hiện tại đang dùng cách này!**

- Backend vẫn generate OTP và lưu vào database
- OTP code hiển thị trong response (debug field)
- Console log ra OTP code
- Copy OTP và test trong app

**Ưu điểm:**
- ✅ Không cần setup gì thêm
- ✅ Test được ngay lập tức
- ✅ Không tốn tiền

**Nhược điểm:**
- ❌ Không test được email template
- ❌ Không có email thật

---

### **OPTION 2: Setup Gmail SMTP với PHPMailer** ⭐ **RECOMMENDED**

#### Step 1: Install PHPMailer
```bash
cd C:\laragon\www\vamper_api
composer require phpmailer/phpmailer
```

#### Step 2: Setup Gmail App Password

1. Đăng nhập Gmail
2. Vào: https://myaccount.google.com/apppasswords
3. Tạo App Password cho "Vamper App"
4. Copy password (16 ký tự)

#### Step 3: Tạo file config
`backend_api/config/email.php`:
```php
<?php
return [
    'smtp_host' => 'smtp.gmail.com',
    'smtp_port' => 587,
    'smtp_username' => 'your-email@gmail.com', // Thay email của bạn
    'smtp_password' => 'xxxx xxxx xxxx xxxx',  // App password
    'from_email' => 'your-email@gmail.com',
    'from_name' => 'Vamper',
];
```

#### Step 4: Update send-otp.php
```php
<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require '../vendor/autoload.php';
$emailConfig = require '../config/email.php';

// ... existing code ...

// Replace mail() function with PHPMailer
$mail = new PHPMailer(true);
try {
    $mail->isSMTP();
    $mail->Host = $emailConfig['smtp_host'];
    $mail->SMTPAuth = true;
    $mail->Username = $emailConfig['smtp_username'];
    $mail->Password = $emailConfig['smtp_password'];
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    $mail->Port = $emailConfig['smtp_port'];

    $mail->setFrom($emailConfig['from_email'], $emailConfig['from_name']);
    $mail->addAddress($to);

    $mail->isHTML(true);
    $mail->Subject = $subject;
    $mail->Body = $message;

    $mail->send();
    $email_sent = true;
} catch (Exception $e) {
    $email_sent = false;
}
```

**Ưu điểm:**
- ✅ Gửi email thật được
- ✅ Gmail miễn phí
- ✅ Test được email template
- ✅ Professional hơn

**Nhược điểm:**
- ⚠️ Cần setup App Password
- ⚠️ Gmail có giới hạn (500 emails/day)

---

### **OPTION 3: Dùng SendGrid / Mailgun / AWS SES** (Production)

**Khi deploy production:**

1. Đăng ký SendGrid (100 emails/day miễn phí)
2. Get API key
3. Install SendGrid PHP library
4. Update send-otp.php

**Ưu điểm:**
- ✅ Professional
- ✅ High deliverability
- ✅ Email analytics
- ✅ No spam issues

**Nhược điểm:**
- ❌ Cần đăng ký account
- ❌ Trả phí khi scale

---

## 🧪 TEST HIỆN TẠI (DEBUG MODE)

### Flow Test:

1. **Register** account mới
2. Backend response:
```json
{
  "success": true,
  "message": "Registration successful! Please check your email...",
  "data": {
    "user": {...},
    "token": "...",
    "debug": {
      "otp_code": "123456",  // <-- LẤY CODE NÀY!
      "note": "Check console for OTP code"
    }
  }
}
```

3. **Console log** cũng show:
```
🔑 DEBUG OTP: 123456
```

4. **Nhập code** vào app: `123456`

5. **Verify success** → Chuyển sang Complete Profile

---

## ⚙️ CẤU HÌNH KHUYẾN NGHỊ

### Development (Localhost):
- ✅ **Option 1: Debug Mode** (đang dùng)
- Console log OTP code
- Không cần setup email

### Staging/Testing:
- ⭐ **Option 2: Gmail SMTP**
- Test email template
- Test deliverability

### Production:
- 🚀 **Option 3: SendGrid/AWS SES**
- Professional email service
- High deliverability
- Email analytics

---

## 🎯 ĐIỂM QUAN TRỌNG

### ✅ Đã hoạt động:
1. Generate OTP (6 số random)
2. Lưu OTP vào database
3. OTP expires sau 10 phút
4. Verify OTP code từ app
5. Mark OTP as used
6. Update user `email_verified = 1`
7. Resend OTP

### ⏳ Cần setup (optional):
1. Gửi email thật (PHPMailer + Gmail)
2. Beautiful HTML email template (đã có)
3. Production email service (SendGrid)

---

## 🔐 BẢO MẬT

### Đã implement:
- ✅ OTP chỉ dùng 1 lần (`is_used` flag)
- ✅ OTP expire sau 10 phút
- ✅ Xóa OTP cũ khi tạo mới
- ✅ Email verification tracking

### TODO (Production):
- ⏳ Rate limiting (max 3 attempts)
- ⏳ IP tracking
- ⏳ Account lockout sau 5 failed attempts
- ⏳ Remove debug OTP code from response

---

## 📊 DATABASE STRUCTURE

### Table: `otp_codes`
```sql
+------------+--------------+
| Field      | Type         |
+------------+--------------+
| id         | INT(11)      |
| email      | VARCHAR(255) |
| otp_code   | VARCHAR(6)   |  <-- 6 số random
| expires_at | DATETIME     |  <-- NOW() + 10 phút
| is_used    | TINYINT(1)   |  <-- 0/1 flag
| created_at | TIMESTAMP    |
+------------+--------------+
```

### Table: `users` (updated)
```sql
+----------------+--------------+
| Field          | Type         |
+----------------+--------------+
| ...            | ...          |
| is_verified    | TINYINT(1)   |  <-- General verification
| email_verified | TINYINT(1)   |  <-- Email OTP verified
+----------------+--------------+
```

---

## 🎉 KẾT LUẬN

**HỆ THỐNG OTP ĐÃ HOÀN CHỈNH!**

### Có thể test ngay:
1. ✅ Register → Nhận OTP trong console
2. ✅ Nhập OTP → Verify thành công
3. ✅ Resend OTP → Get new code
4. ✅ Expired OTP → Show error
5. ✅ Invalid OTP → Show error

### Setup email thật (optional):
- Follow **Option 2** để dùng Gmail SMTP
- 10 phút setup
- Test được email template

---

**Created:** August 14, 2026  
**Last Updated:** August 14, 2026  
**Status:** ✅ Fully Functional (Debug Mode)
