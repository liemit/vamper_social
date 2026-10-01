<?php
require_once '../config/cors.php';
require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

try {
    // 1. Dọn dẹp các tài khoản admin cũ nếu có
    $db->exec("DELETE FROM users WHERE email = 'admin'");

    // 2. Tạo mã băm mật khẩu 'admin123' CHUẨN XÁC bằng chính engine của PHP
    $password_raw = 'admin123';
    $password_hashed = password_hash($password_raw, PASSWORD_BCRYPT);

    // 3. Chèn tài khoản Admin mới
    $query = "INSERT INTO users (full_name, email, password, role, is_verified, coins, is_active)
              VALUES ('Vamper Boss', 'admin', :pass, 'admin', 1, 999, 1)";

    $stmt = $db->prepare($query);
    $stmt->bindParam(':pass', $password_hashed);

    if ($stmt->execute()) {
        echo "<h1>✅ SUCCESS!</h1>";
        echo "<p>Admin account has been reset successfully.</p>";
        echo "<ul>
                <li><b>Email:</b> admin</li>
                <li><b>Password:</b> admin123</li>
                <li><b>Role:</b> admin</li>
              </ul>";
        echo "<p>Now you can go back to the app and login!</p>";
    }

} catch (PDOException $e) {
    echo "<h1>❌ ERROR!</h1>";
    echo "Database error: " . $e->getMessage();
}
?>
