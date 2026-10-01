<?php
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

echo "<h2>🛠 DEBUG - Kiểm tra cấu trúc bảng Vamper</h2>";

echo "<h3>📋 Bảng 'users' - cấu trúc cột:</h3>";
try {
    $stmt = $db->query("DESCRIBE users");
    $cols = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<table border='1' cellpadding='5'><tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th></tr>";
    foreach ($cols as $c) {
        $warn = ($c['Field'] === 'email_verified' || $c['Field'] === 'is_verified') ? " <span style='color:green'>✓</span>" : "";
        echo "<tr><td>{$c['Field']}{$warn}</td><td>{$c['Type']}</td><td>{$c['Null']}</td><td>{$c['Key']}</td><td>{$c['Default']}</td></tr>";
    }
    echo "</table>";
} catch (Exception $e) {
    echo "<p style='color:red'>❌ Lỗi: " . $e->getMessage() . "</p>";
}

echo "<h3>📋 Bảng 'otp_codes' - cấu trúc cột:</h3>";
try {
    $stmt = $db->query("DESCRIBE otp_codes");
    $cols = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "<table border='1' cellpadding='5'><tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th></tr>";
    foreach ($cols as $c) {
        $warn = "";
        if ($c['Field'] === 'otp_code' && strpos(strtolower($c['Type']), 'int') !== false) {
            $warn = " <span style='color:red'>⚠️ OTP lưu kiểu INT → dễ mất số 0 đầu! Nên là VARCHAR(6)</span>";
        }
        if ($c['Field'] === 'otp_code' && strpos(strtolower($c['Type']), 'varchar') !== false) {
            $warn = " <span style='color:green'>✓ OK - VARCHAR</span>";
        }
        if ($c['Field'] === 'is_used' && $c['Default'] != '0') {
            $warn = " <span style='color:red'>⚠️ Mặc định is_used không phải 0!</span>";
        }
        echo "<tr><td>{$c['Field']}</td><td>{$c['Type']}</td><td>{$c['Null']}</td><td>{$c['Key']}</td><td>{$c['Default']}</td><td>{$warn}</td></tr>";
    }
    echo "</table>";
} catch (Exception $e) {
    echo "<p style='color:red'>❌ Lỗi: " . $e->getMessage() . "</p>";
}

echo "<h3>📋 Dữ liệu mẫu 5 OTP gần nhất (có thể có):</h3>";
try {
    $stmt = $db->query("SELECT id, email, otp_code, is_used, created_at, expires_at, 
                               CASE WHEN expires_at > NOW() THEN '<span style=\"color:green\">Còn hạn</span>' ELSE '<span style=\"color:red\">Hết hạn</span>' END AS status
                        FROM otp_codes ORDER BY created_at DESC LIMIT 5");
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    if (count($rows) == 0) {
        echo "<p>Chưa có OTP nào trong DB.</p>";
    } else {
        echo "<table border='1' cellpadding='5'><tr><th>ID</th><th>Email</th><th>OTP</th><th>Đã dùng</th><th>Tạo lúc</th><th>Hết hạn lúc</th><th>Trạng thái</th></tr>";
        foreach ($rows as $r) {
            echo "<tr><td>{$r['id']}</td><td>{$r['email']}</td><td><b>{$r['otp_code']}</b></td><td>{$r['is_used']}</td><td>{$r['created_at']}</td><td>{$r['expires_at']}</td><td>{$r['status']}</td></tr>";
        }
        echo "</table>";
    }
} catch (Exception $e) {
    echo "<p style='color:red'>❌ Lỗi: " . $e->getMessage() . "</p>";
}

echo "<h3>⚙️ MySQL NOW() - kiểm tra giờ hệ thống:</h3>";
try {
    $stmt = $db->query("SELECT NOW() AS db_now");
    $r = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "<p>MySQL giờ hiện tại: <b>{$r['db_now']}</b></p>";
    echo "<p>PHP giờ hiện tại: <b>" . date('Y-m-d H:i:s') . "</b></p>";
    $diff = strtotime($r['db_now']) - time();
    $abs = abs($diff);
    if ($abs > 60) {
        echo "<p style='color:red'>⚠️ Lệch giờ MySQL vs PHP: <b>$diff giây ($abs giây)</b> → NGUYÊN NHÂN CHÍNH gây OTP hết hạn sớm!</p>";
    } else {
        echo "<p style='color:green'>✓ Giờ MySQL và PHP đồng bộ (chênh lệch $diff giây, dưới 60s là OK)</p>";
    }
} catch (Exception $e) {
    echo "<p style='color:red'>❌ Lỗi: " . $e->getMessage() . "</p>";
}

echo "<hr><p><i>File này để debug tạm thời. Xóa nó đi sau khi kiểm tra xong để bảo mật.</i></p>";
?>
