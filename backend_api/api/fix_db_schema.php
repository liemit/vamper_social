<?php
/**
 * ============================================================
 *  AUTO-FIX DATABASE SCHEMA - VAMPER OTP
 * ============================================================
 * File này sẽ TỰ KIỂM TRA và TỰ SỬA cấu trúc bảng:
 *   - Bảng users: tự thêm cột email_verified nếu thiếu, sửa is_verified nếu sai
 *   - Bảng otp_codes: đổi otp_code sang VARCHAR(6), set is_used default = 0,
 *                    thêm expires_at nếu thiếu, sửa kiểu DATETIME nếu sai
 *
 * CÁCH DÙNG: Mở trình duyệt vào: http://localhost/vamper/api/fix_db_schema.php
 *           (hoặc đường dẫn tương ứng của bạn)
 *           Sau khi xong thì XÓA FILE NÀY ĐI để bảo mật.
 * ============================================================
 */

require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

echo "<h2>🛠 AUTO-FIX VAMPER DATABASE SCHEMA</h2><pre style='background:#f5f5f5;padding:15px;border-radius:8px'>";

function run_sql($db, $sql, $desc) {
    try {
        $db->exec($sql);
        echo "<span style='color:green'>✓ OK</span>  $desc\n";
        return true;
    } catch (PDOException $e) {
        $msg = $e->getMessage();
        if (strpos($msg, 'Duplicate column name') !== false ||
            strpos($msg, 'Duplicate key name') !== false) {
            echo "<span style='color:#999'>~ Đã tồn tại, bỏ qua</span>  $desc\n";
            return true;
        }
        echo "<span style='color:red'>✗ LỖI</span>  $desc  →  " . htmlspecialchars($msg) . "\n";
        return false;
    }
}

echo "\n============================\n";
echo "📋 BẢNG `users`\n";
echo "============================\n\n";

// 1. Kiểm tra bảng users tồn tại?
try {
    $db->query("SELECT 1 FROM users LIMIT 1");
    echo "<span style='color:green'>✓</span>  Bảng users tồn tại\n";
} catch (PDOException $e) {
    die("<span style='color:red'>✗ Bảng users KHÔNG TỒN TẠI! Cần chạy migrate trước.</span>");
}

// 2. Thêm cột email_verified nếu thiếu
run_sql($db, "ALTER TABLE users ADD COLUMN email_verified TINYINT(1) NOT NULL DEFAULT 0 AFTER is_verified",
    "Thêm cột `users.email_verified` TINYINT(1) DEFAULT 0 (nếu thiếu)");

// 3. Đảm bảo is_verified có default 0
run_sql($db, "ALTER TABLE users MODIFY COLUMN is_verified TINYINT(1) NOT NULL DEFAULT 0",
    "Sửa `users.is_verified` → TINYINT(1) NOT NULL DEFAULT 0");

// 4. Đảm bảo email là UNIQUE (tránh duplicate)
run_sql($db, "ALTER TABLE users ADD UNIQUE KEY idx_users_email (email)",
    "Thêm UNIQUE index cho `users.email`");

echo "\n============================\n";
echo "📋 BẢNG `otp_codes`\n";
echo "============================\n\n";

// Kiểm tra bảng otp_codes tồn tại chưa - nếu chưa thì tạo
try {
    $db->query("SELECT 1 FROM otp_codes LIMIT 1");
    echo "<span style='color:green'>✓</span>  Bảng otp_codes tồn tại\n";
} catch (PDOException $e) {
    echo "Tạo mới bảng `otp_codes`...\n";
    $create = "
    CREATE TABLE otp_codes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email VARCHAR(255) NOT NULL,
        otp_code VARCHAR(6) NOT NULL,
        is_used TINYINT(1) NOT NULL DEFAULT 0,
        expires_at DATETIME NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_otp_email (email),
        INDEX idx_otp_code (otp_code),
        INDEX idx_otp_combined (email, otp_code, is_used, expires_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;";
    run_sql($db, $create, "Tạo bảng `otp_codes` với cấu trúc chuẩn");
}

// 1. Quan trọng nhất: Đảm bảo otp_code là VARCHAR(6) (KHÔNG được là INT - sẽ mất số 0 đầu)
run_sql($db, "ALTER TABLE otp_codes MODIFY COLUMN otp_code VARCHAR(6) NOT NULL",
    "Sửa `otp_codes.otp_code` → VARCHAR(6) NOT NULL (nếu trước đây là INT sẽ mất số 0 đầu)");

// 2. is_used default = 0
run_sql($db, "ALTER TABLE otp_codes MODIFY COLUMN is_used TINYINT(1) NOT NULL DEFAULT 0",
    "Sửa `otp_codes.is_used` → TINYINT(1) NOT NULL DEFAULT 0");

// 3. expires_at phải là DATETIME NOT NULL
run_sql($db, "ALTER TABLE otp_codes MODIFY COLUMN expires_at DATETIME NOT NULL",
    "Sửa `otp_codes.expires_at` → DATETIME NOT NULL");

// 4. email VARCHAR(255)
run_sql($db, "ALTER TABLE otp_codes MODIFY COLUMN email VARCHAR(255) NOT NULL",
    "Sửa `otp_codes.email` → VARCHAR(255) NOT NULL");

// 5. Thêm cột created_at nếu chưa có
run_sql($db, "ALTER TABLE otp_codes ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP AFTER expires_at",
    "Thêm cột `otp_codes.created_at` (nếu thiếu)");

// 6. Index để query nhanh
run_sql($db, "ALTER TABLE otp_codes ADD INDEX idx_otp_email (email)",
    "Thêm INDEX idx_otp_email (email)");
run_sql($db, "ALTER TABLE otp_codes ADD INDEX idx_otp_combined (email, otp_code, is_used, expires_at)",
    "Thêm INDEX idx_otp_combined (4 cột query OTP - tốc độ hơn 10x)");

echo "\n============================\n";
echo "🧪 TESTING - Tạo & Verify thử 1 OTP giả\n";
echo "============================\n\n";

$test_email = "__test_otp_" . time() . "@test.com";
$test_otp   = "048398";  // Số 0 ĐẦU - test kỹ trường hợp leading zero!

try {
    // Tạo OTP test
    $stmt = $db->prepare("INSERT INTO otp_codes (email, otp_code, expires_at)
                          VALUES (:e, :o, DATE_ADD(NOW(), INTERVAL 30 MINUTE))");
    $stmt->bindParam(':e', $test_email);
    $stmt->bindParam(':o', $test_otp);
    $stmt->execute();
    echo "✓ Đã tạo OTP giả: [$test_otp] cho email: $test_email\n";

    // Bây giờ query giống như verify-otp.php (PHP side comparison - NEW LOGIC)
    $stmt = $db->prepare("SELECT id, otp_code, is_used, expires_at, created_at
                          FROM otp_codes
                          WHERE email = :email
                          AND (is_used = 0 OR is_used IS NULL)
                          AND expires_at > NOW()
                          ORDER BY created_at DESC");
    $stmt->bindParam(':email', $test_email);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "✓ Query OK, có " . count($rows) . " OTP hợp lệ\n";

    $otp_from_user = "048398"; // user nhập
    $otp_normalized = sprintf("%06d", (int)trim((string)$otp_from_user));
    $matched = false;
    foreach ($rows as $r) {
        $db_otp = trim((string)$r['otp_code']);
        $db_otp_norm = sprintf("%06d", (int)$db_otp);
        echo "   — So sánh: user [$otp_from_user] (norm: $otp_normalized) vs DB [$db_otp] (norm: $db_otp_norm)  =  ";
        if ($otp_from_user === $db_otp || $otp_normalized === $db_otp_norm ||
            $otp_from_user === $db_otp_norm || $otp_normalized === $db_otp) {
            $matched = true;
            echo "<span style='color:green'>MATCH ✅</span>\n";
        } else {
            echo "<span style='color:red'>KHÔNG TRÙNG ❌</span>\n";
        }
    }

    if ($matched) {
        echo "\n<span style='color:green;font-weight:bold'>✅ TẤT CẢ OK. OTP MATCH HOÀN TOÀN</span>\n";
    } else {
        echo "\n<span style='color:red'>⚠️ CÓ LỖI - không match được dù DB có mã</span>\n";
    }

    // Dọn dẹp test
    $db->exec("DELETE FROM otp_codes WHERE email = '$test_email'");
    echo "✓ Đã xóa dữ liệu test\n";

} catch (PDOException $e) {
    echo "<span style='color:red'>⚠️ Test LỖI: " . htmlspecialchars($e->getMessage()) . "</span>\n";
}

echo "\n============================\n";
echo "⚙️ KIỂM TRA GIỜ HỆ THỐNG\n";
echo "============================\n\n";
$r = $db->query("SELECT NOW() as mysql_now")->fetch(PDO::FETCH_ASSOC);
$mysql_t = $r['mysql_now'];
$php_t = date('Y-m-d H:i:s');
echo "MySQL NOW(): $mysql_t\n";
echo "PHP  time():   $php_t\n";
$diff = strtotime($mysql_t) - time();
$abs_diff = abs($diff);
if ($abs_diff > 60) {
    echo "<span style='color:red;font-weight:bold'>⚠️ LỆCH GIỜ: $diff giây ($abs_diff giây) → nguy cơ OTP hết hạn sớm! Cần đặt lại giờ cho PHP / MySQL.</span>\n";
    echo "   Giải pháp: Trong file config/database.php thêm dòng: \$this->conn->exec(\"SET time_zone = '+07:00'\");\n";
} else {
    echo "<span style='color:green'>✓ Giờ đồng bộ (chênh $diff giây, dưới 60s là OK)</span>\n";
}

echo "</pre>";
echo "<hr><p style='color:red;font-weight:bold'>⚠️ XÓA FILE `fix_db_schema.php` NÀY ĐI KHI ĐÃ XONG để bảo mật!</p>";
?>
