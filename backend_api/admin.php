<?php
require_once __DIR__ . '/libs/AdminTools.php';

function adminQueryString(string $key, string $default = ''): string
{
    return isset($_GET[$key]) && is_string($_GET[$key]) ? $_GET[$key] : $default;
}

ini_set('session.use_strict_mode', '1');
session_name('vamper_admin');
session_set_cookie_params([
    'httponly' => true,
    'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
    'samesite' => 'Lax',
]);
session_start();

$host = getenv('VAMPER_DB_HOST') ?: 'localhost';
$db_name = getenv('VAMPER_DB_NAME') ?: 'vamper_social';
$username = getenv('VAMPER_DB_USER') ?: 'root';
$password = getenv('VAMPER_DB_PASSWORD') ?: '';

try {
    $db = new PDO(
        "mysql:host=$host;dbname=$db_name;charset=utf8mb4",
        $username,
        $password,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    if ($_SERVER['REQUEST_METHOD'] === 'POST' || !empty($_SESSION['admin_logged_in'])) {
        ensureAdminToolsSchema($db);
    }
} catch (Throwable $e) {
    error_log('Admin database initialization failed: ' . $e->getMessage());
    http_response_code(500);
    exit('Admin database initialization failed. Check database access and migration permissions.');
}

if (empty($_SESSION['admin_csrf'])) {
    $_SESSION['admin_csrf'] = bin2hex(random_bytes(32));
}
$csrfToken = $_SESSION['admin_csrf'];
$postInputInvalid = false;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    foreach ($_POST as $value) {
        if (!is_string($value)) {
            $postInputInvalid = true;
            break;
        }
    }
}

$tab = adminQueryString('tab', 'users');
$search = trim(adminQueryString('search'));
$page = min(100000, max(1, intval(adminQueryString('page', '1'))));
$limit = 10;
$offset = ($page - 1) * $limit;

// Posts pagination
$postPage = min(100000, max(1, intval(adminQueryString('post_page', '1'))));
$postLimit = 10;
$postOffset = ($postPage - 1) * $postLimit;

// Transactions pagination
$txPage = min(100000, max(1, intval(adminQueryString('tx_page', '1'))));
$txLimit = 10;
$txOffset = ($txPage - 1) * $txLimit;
$userStatus = adminQueryString('status');
$dateFrom = adminQueryString('date_from', date('Y-m-01'));
$dateTo = adminQueryString('date_to', date('Y-m-d'));
$txSearch = trim(adminQueryString('tx_search'));
$txStatus = adminQueryString('tx_status');
$txDateFrom = adminQueryString('tx_from');
$txDateTo = adminQueryString('tx_to');

$error = '';
$success = '';

// Handle Login POST
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['login'])) {
    $email = is_string($_POST['email'] ?? null) ? trim($_POST['email']) : '';
    $pass = is_string($_POST['password'] ?? null) ? $_POST['password'] : '';

    if ($postInputInvalid || !is_string($_POST['csrf_token'] ?? null) || !hash_equals($csrfToken, $_POST['csrf_token'])) {
        $error = "Phiên đăng nhập không hợp lệ. Vui lòng tải lại trang.";
    } elseif (empty($email) || empty($pass)) {
        $error = "Vui lòng nhập đầy đủ email và mật khẩu.";
    } else {
        $stmt = $db->prepare(
            "SELECT u.id, u.full_name, u.email, u.password, u.role, u.is_active,
                    a.admin_role
             FROM users u
             INNER JOIN admin_accounts a ON a.user_id = u.id
             WHERE u.email = :email AND u.role = 'admin' LIMIT 1"
        );
        $stmt->execute([':email' => strtolower($email)]);

        if ($stmt->rowCount() > 0) {
            $user = $stmt->fetch(PDO::FETCH_ASSOC);
            if (password_verify($pass, $user['password'])) {
                if ($user['is_active'] == 0) {
                    $error = "Tài khoản admin này đã bị khóa.";
                } else {
                    session_regenerate_id(true);
                    $_SESSION['admin_logged_in'] = true;
                    $_SESSION['admin_id'] = (int)$user['id'];
                    $_SESSION['admin_name'] = $user['full_name'];
                    $_SESSION['admin_role'] = $user['admin_role'];
                    $_SESSION['admin_csrf'] = bin2hex(random_bytes(32));
                    header('Location: admin.php');
                    exit;
                }
            } else {
                $error = "Sai thông tin đăng nhập hoặc không có quyền admin.";
            }
        } else {
            $error = "Sai thông tin đăng nhập hoặc không có quyền admin.";
        }
    }
}

// Rotate stale or revoked admin sessions.
$isAdminLoggedIn = isset($_SESSION['admin_logged_in'], $_SESSION['admin_id'])
    && $_SESSION['admin_logged_in'] === true;
if ($isAdminLoggedIn) {
    $sessionAdmin = $db->prepare(
        "SELECT u.full_name, a.admin_role FROM users u
         INNER JOIN admin_accounts a ON a.user_id = u.id
         WHERE u.id = :id AND u.role = 'admin' AND u.is_active = 1"
    );
    $sessionAdmin->execute([':id' => $_SESSION['admin_id']]);
    $currentAdmin = $sessionAdmin->fetch(PDO::FETCH_ASSOC);
    if (!$currentAdmin) {
        $_SESSION = [];
        session_destroy();
        $isAdminLoggedIn = false;
        $error = 'Tài khoản quản trị không còn quyền truy cập.';
    } else {
        $_SESSION['admin_name'] = $currentAdmin['full_name'];
        $_SESSION['admin_role'] = $currentAdmin['admin_role'];
    }
}

// Handle CRUD & Dashboard Actions
if ($isAdminLoggedIn && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $postAction = is_string($_POST['action'] ?? null) ? $_POST['action'] : '';
    $requiredPermission = match ($postAction) {
        'set_user_status', 'create_user', 'edit_user' => 'users',
        'adjust_coins', 'save_settings' => 'finance',
        'set_post_status', 'review_report' => 'reports',
        'create_shop_item', 'save_shop_item', 'toggle_shop_item' => 'shop',
        'set_admin_role' => 'admins',
        'logout' => 'dashboard',
        default => null,
    };

    if ($postInputInvalid) {
        $error = 'Form data is invalid.';
    } elseif (!is_string($_POST['csrf_token'] ?? null) || !hash_equals($csrfToken, $_POST['csrf_token'])) {
        $error = 'Yêu cầu không hợp lệ hoặc đã hết hạn. Vui lòng tải lại trang.';
    } elseif ($postAction === 'logout') {
        $_SESSION = [];
        session_destroy();
        header('Location: admin.php');
        exit;
    } elseif ($requiredPermission === null) {
        $error = 'Thao tác không được hỗ trợ.';
    } elseif (!adminHasPermission($_SESSION['admin_role'], $requiredPermission)) {
        http_response_code(403);
        $error = 'Tài khoản của bạn không được cấp quyền cho thao tác này.';
    } elseif ($postAction === 'set_user_status') {
        $userId = filter_var($_POST['user_id'] ?? null, FILTER_VALIDATE_INT);
        $newStatus = filter_var($_POST['is_active'] ?? null, FILTER_VALIDATE_INT);
        $reason = trim($_POST['reason'] ?? '');
        if (!$userId || !in_array($newStatus, [0, 1], true) || $reason === '') {
            $error = 'Cần chọn tài khoản, trạng thái và nhập lý do.';
        } else {
            $target = $db->prepare('SELECT role, is_active FROM users WHERE id = :id FOR UPDATE');
            $db->beginTransaction();
            $target->execute([':id' => $userId]);
            $oldStatus = $target->fetch(PDO::FETCH_ASSOC);
            if (!$oldStatus || $oldStatus['role'] === 'admin' || $userId === (int)$_SESSION['admin_id']) {
                $db->rollBack();
                $error = 'Không thể thay đổi trạng thái tài khoản quản trị hoặc tài khoản không tồn tại.';
            } else {
                $update = $db->prepare('UPDATE users SET is_active = :status WHERE id = :id');
                $update->execute([':status' => $newStatus, ':id' => $userId]);
                writeAdminAudit($db, (int)$_SESSION['admin_id'], $newStatus ? 'user_unblocked' : 'user_blocked', 'user', $userId, ['reason' => $reason]);
                $db->commit();
                $success = 'Đã cập nhật trạng thái tài khoản và ghi nhật ký.';
            }
        }
    } elseif ($postAction === 'adjust_coins') {
        $userId = filter_var($_POST['user_id'] ?? null, FILTER_VALIDATE_INT);
        $delta = filter_var($_POST['amount_delta'] ?? null, FILTER_VALIDATE_INT);
        $reason = trim($_POST['reason'] ?? '');
        if (!$userId || $delta === false || $delta === 0 || $reason === '' || strlen($reason) > 500) {
            $error = 'Số xu điều chỉnh và lý do là bắt buộc.';
        } else {
            try {
                $db->beginTransaction();
                $balanceQuery = $db->prepare('SELECT coins FROM users WHERE id = :id FOR UPDATE');
                $balanceQuery->execute([':id' => $userId]);
                $balance = $balanceQuery->fetchColumn();
                if ($balance === false || (int)$balance + $delta < 0) {
                    throw new DomainException('Tài khoản không tồn tại hoặc số dư không đủ để trừ.');
                }
                $newBalance = (int)$balance + $delta;
                $db->prepare('UPDATE users SET coins = :coins WHERE id = :id')
                    ->execute([':coins' => $newBalance, ':id' => $userId]);
                $db->prepare(
                    "INSERT INTO vpc_ledger
                        (user_id, amount_delta, balance_before, balance_after, source_type, reason, actor_id)
                     VALUES (:uid, :delta, :before, :after, 'admin_adjustment', :reason, :actor)"
                )->execute([
                    ':uid' => $userId, ':delta' => $delta, ':before' => (int)$balance,
                    ':after' => $newBalance, ':reason' => $reason, ':actor' => (int)$_SESSION['admin_id'],
                ]);
                writeAdminAudit($db, (int)$_SESSION['admin_id'], 'vpc_adjusted', 'user', $userId, ['delta' => $delta, 'reason' => $reason]);
                $db->commit();
                $success = 'Đã điều chỉnh VPC và ghi vào sổ cái.';
            } catch (DomainException $e) {
                if ($db->inTransaction()) $db->rollBack();
                $error = $e->getMessage();
            } catch (Throwable $e) {
                if ($db->inTransaction()) $db->rollBack();
                error_log('Admin VPC adjustment failed: ' . $e->getMessage());
                $error = 'Không thể điều chỉnh VPC. Chưa có thay đổi nào được lưu.';
            }
        }
    } elseif ($postAction === 'create_user') {
        $fullName = trim($_POST['full_name'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $pass = $_POST['password'] ?? '';
        $role = $_POST['role'] ?? 'user';
        $gender = $_POST['gender'] ?? 'other';
        $coins = intval($_POST['coins'] ?? 0);

        if (empty($fullName) || strlen($fullName) > 100 || strlen($email) > 100
            || !filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($pass) < 10
            || !in_array($role, ['user', 'admin'], true) || $coins < 0
            || !in_array($gender, ['male', 'female', 'other'], true)) {
            $error = "Vui lòng điền đầy đủ Họ tên, Email và Mật khẩu.";
        } elseif ($role === 'admin' && !adminHasPermission($_SESSION['admin_role'], 'admins')) {
            $error = 'Chỉ quản trị viên cấp cao mới được tạo tài khoản admin.';
        } else {
            $hashedPass = password_hash($pass, PASSWORD_DEFAULT);
            try {
                $db->beginTransaction();
                $stmt = $db->prepare("INSERT INTO users (full_name, email, password, role, gender, coins, is_active, created_at) VALUES (:name, :email, :pass, :role, :gender, :coins, 1, NOW())");
                $stmt->execute([
                    ':name' => $fullName,
                    ':email' => strtolower(trim($email)),
                    ':pass' => $hashedPass,
                    ':role' => $role,
                    ':gender' => $gender,
                    ':coins' => $coins
                ]);
                $newUserId = (int)$db->lastInsertId();
                if ($role === 'admin') {
                    $db->prepare("INSERT INTO admin_accounts (user_id, admin_role) VALUES (:id, 'support')")
                        ->execute([':id' => $newUserId]);
                }
                if ($coins !== 0) {
                    $db->prepare(
                        "INSERT INTO vpc_ledger (user_id, amount_delta, balance_before, balance_after, source_type, reason, actor_id)
                         VALUES (:uid, :delta, 0, :after, 'admin_initial_balance', 'Initial balance on account creation', :actor)"
                    )->execute([':uid' => $newUserId, ':delta' => $coins, ':after' => $coins, ':actor' => (int)$_SESSION['admin_id']]);
                }
                writeAdminAudit($db, (int)$_SESSION['admin_id'], 'user_created', 'user', $newUserId);
                $db->commit();
                $success = "Đã thêm người dùng mới thành công!";
            } catch (PDOException $e) {
                if ($db->inTransaction()) $db->rollBack();
                error_log('Admin user creation failed: ' . $e->getMessage());
                $error = "Không thể tạo tài khoản. Hãy kiểm tra email và dữ liệu nhập.";
            }
        }
    } elseif ($postAction === 'edit_user') {
        $userId = $_POST['user_id'] ?? null;
        $fullName = trim($_POST['full_name'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $gender = $_POST['gender'] ?? 'other';

        if ($userId && !empty($fullName) && strlen($fullName) <= 100 && strlen($email) <= 100
            && filter_var($email, FILTER_VALIDATE_EMAIL) && in_array($gender, ['male', 'female', 'other'], true)) {
            $stmt = $db->prepare("UPDATE users SET full_name = :name, email = :email, gender = :gender WHERE id = :id");
            $stmt->execute([
                ':name' => $fullName, ':email' => strtolower(trim($email)),
                ':gender' => $gender, ':id' => $userId,
            ]);
            writeAdminAudit($db, (int)$_SESSION['admin_id'], 'user_updated', 'user', $userId);
            $success = "Đã cập nhật thông tin người dùng thành công!";
        } else {
            $error = 'Thông tin người dùng không hợp lệ.';
        }
    } elseif ($postAction === 'set_post_status') {
        $postId = filter_var($_POST['post_id'] ?? null, FILTER_VALIDATE_INT);
        $status = filter_var($_POST['status'] ?? null, FILTER_VALIDATE_INT);
        if ($postId && in_array($status, [0, 1], true)) {
            $db->beginTransaction();
            $db->prepare('UPDATE posts SET status = :status WHERE id = :id')
                ->execute([':status' => $status, ':id' => $postId]);
            writeAdminAudit($db, (int)$_SESSION['admin_id'], $status ? 'post_restored' : 'post_hidden', 'post', $postId);
            $db->commit();
            $success = $status ? 'Đã khôi phục bài viết.' : 'Đã ẩn bài viết; dữ liệu vẫn được giữ lại.';
        } else {
            $error = 'Bài viết hoặc trạng thái không hợp lệ.';
        }
    } elseif ($postAction === 'review_report') {
        $reportId = filter_var($_POST['report_id'] ?? null, FILTER_VALIDATE_INT);
        $status = $_POST['status'] ?? '';
        $note = trim($_POST['review_note'] ?? '');
        if (!$reportId || !in_array($status, ['reviewing', 'resolved', 'dismissed'], true) || strlen($note) > 500) {
            $error = 'Trạng thái xử lý tố cáo không hợp lệ.';
        } else {
            $reportQuery = $db->prepare('SELECT target_type, target_id FROM reports WHERE id = :id');
            $reportQuery->execute([':id' => $reportId]);
            $report = $reportQuery->fetch(PDO::FETCH_ASSOC);
            if (!$report) {
                $error = 'Không tìm thấy tố cáo.';
            } else {
                $db->beginTransaction();
                if ($status === 'resolved' && $report['target_type'] === 'post') {
                    $db->prepare('UPDATE posts SET status = 0 WHERE id = :id')->execute([':id' => $report['target_id']]);
                } elseif ($status === 'resolved' && $report['target_type'] === 'user') {
                    $db->prepare('UPDATE users SET is_active = 0 WHERE id = :id AND role <> \'admin\'')
                        ->execute([':id' => $report['target_id']]);
                }
                $db->prepare(
                    'UPDATE reports SET status = :status, reviewed_by = :admin, reviewed_at = NOW(), review_note = :note WHERE id = :id'
                )->execute([
                    ':status' => $status, ':admin' => (int)$_SESSION['admin_id'],
                    ':note' => $note, ':id' => $reportId,
                ]);
                writeAdminAudit($db, (int)$_SESSION['admin_id'], 'report_' . $status, 'report', $reportId, ['note' => $note]);
                $db->commit();
                $success = 'Đã cập nhật kết quả xử lý tố cáo.';
            }
        }
    } elseif ($postAction === 'create_shop_item') {
        $type = $_POST['type'] ?? '';
        $name = trim($_POST['name'] ?? '');
        $imageUrl = trim($_POST['image_url'] ?? '');
        $price = filter_var($_POST['price_coins'] ?? null, FILTER_VALIDATE_INT);
        $supportedFrameCodes = [
            'frame_white', 'frame_blue', 'frame_emerald', 'frame_neon', 'frame_gold',
            'frame_flame', 'frame_galaxy', 'frame_dragon', 'frame_rose', 'frame_ice',
            'frame_sakura', 'frame_ocean', 'frame_sunset', 'frame_mint', 'frame_obsidian',
            'frame_holo', 'frame_rainbow', 'frame_solar',
        ];
        $validImage = $type === 'avatar'
            ? filter_var($imageUrl, FILTER_VALIDATE_URL) && str_starts_with(strtolower($imageUrl), 'https://')
            : ($type === 'profile_frame' && in_array($imageUrl, $supportedFrameCodes, true));
        if (!in_array($type, ['avatar', 'profile_frame'], true) || $name === '' || strlen($name) > 255 || strlen($imageUrl) > 255
            || !$validImage || $price === false || $price < 0) {
            $error = 'Tên, loại, ảnh hoặc giá vật phẩm không hợp lệ.';
        } else {
            $exists = $db->prepare('SELECT id FROM shop_items WHERE type = :type AND image_url = :image LIMIT 1');
            $exists->execute([':type' => $type, ':image' => $imageUrl]);
            if ($exists->fetchColumn()) {
                $error = 'Vật phẩm này đã có trong catalog.';
            } else {
                $db->beginTransaction();
                $db->prepare('INSERT INTO shop_items (name, type, image_url, price_coins, is_active) VALUES (:name, :type, :image, :price, 1)')
                    ->execute([':name' => $name, ':type' => $type, ':image' => $imageUrl, ':price' => $price]);
                $newItemId = (int)$db->lastInsertId();
                writeAdminAudit($db, (int)$_SESSION['admin_id'], 'shop_item_created', 'shop_item', $newItemId, ['type' => $type, 'price_coins' => $price]);
                $db->commit();
                $success = 'Đã thêm vật phẩm vào shop.';
            }
        }
    } elseif ($postAction === 'save_shop_item') {
        $itemId = filter_var($_POST['item_id'] ?? null, FILTER_VALIDATE_INT);
        $name = trim($_POST['name'] ?? '');
        $price = filter_var($_POST['price_coins'] ?? null, FILTER_VALIDATE_INT);
        if (!$itemId || $name === '' || strlen($name) > 255 || $price === false || $price < 0) {
            $error = 'Tên vật phẩm và giá VPC hợp lệ là bắt buộc.';
        } else {
            $db->beginTransaction();
            $db->prepare('UPDATE shop_items SET name = :name, price_coins = :price WHERE id = :id')
                ->execute([':name' => $name, ':price' => $price, ':id' => $itemId]);
            writeAdminAudit($db, (int)$_SESSION['admin_id'], 'shop_item_updated', 'shop_item', $itemId, ['price_coins' => $price]);
            $db->commit();
            $success = 'Đã cập nhật vật phẩm shop.';
        }
    } elseif ($postAction === 'toggle_shop_item') {
        $itemId = filter_var($_POST['item_id'] ?? null, FILTER_VALIDATE_INT);
        if ($itemId) {
            $db->beginTransaction();
            $db->prepare('UPDATE shop_items SET is_active = 1 - is_active WHERE id = :id')->execute([':id' => $itemId]);
            writeAdminAudit($db, (int)$_SESSION['admin_id'], 'shop_item_toggled', 'shop_item', $itemId);
            $db->commit();
            $success = 'Đã cập nhật trạng thái vật phẩm shop.';
        } else {
            $error = 'ID vật phẩm không hợp lệ.';
        }
    } elseif ($postAction === 'set_admin_role') {
        $userId = filter_var($_POST['user_id'] ?? null, FILTER_VALIDATE_INT);
        $role = $_POST['admin_role'] ?? '';
        if (!$userId || $userId === (int)$_SESSION['admin_id'] || !in_array($role, ['super_admin', 'moderator', 'finance', 'support', 'remove'], true)) {
            $error = 'Không thể đổi vai trò của tài khoản này.';
        } else {
            $currentRole = $db->prepare('SELECT admin_role FROM admin_accounts WHERE user_id = :id');
            $currentRole->execute([':id' => $userId]);
            $oldRole = $currentRole->fetchColumn();
            $removingSuperAdmin = $oldRole === 'super_admin' && $role !== 'super_admin';
            $superAdminCount = (int)$db->query("SELECT COUNT(*) FROM admin_accounts WHERE admin_role = 'super_admin'")->fetchColumn();
            if ($oldRole === false) {
                $error = 'Không tìm thấy tài khoản quản trị.';
            } elseif ($removingSuperAdmin && $superAdminCount <= 1) {
                $error = 'Không thể hạ quyền của quản trị viên cấp cao cuối cùng.';
            } elseif ($role === 'remove') {
                $db->beginTransaction();
                $db->prepare('DELETE FROM admin_accounts WHERE user_id = :id')->execute([':id' => $userId]);
                $db->prepare("UPDATE users SET role = 'user' WHERE id = :id")->execute([':id' => $userId]);
                writeAdminAudit($db, (int)$_SESSION['admin_id'], 'admin_role_removed', 'admin', $userId);
                $db->commit();
                $success = 'Đã thu hồi quyền quản trị.';
            } else {
                $db->beginTransaction();
                $db->prepare("UPDATE admin_accounts SET admin_role = :role WHERE user_id = :id")
                    ->execute([':role' => $role, ':id' => $userId]);
                writeAdminAudit($db, (int)$_SESSION['admin_id'], 'admin_role_changed', 'admin', $userId, ['role' => $role]);
                $db->commit();
                $success = 'Đã cập nhật quyền quản trị.';
            }
        }
    } elseif ($postAction === 'save_settings') {
        $paypalEmail = trim($_POST['paypal_email'] ?? '');
        $paypalMode = $_POST['paypal_mode'] ?? 'sandbox';
        if (!filter_var($paypalEmail, FILTER_VALIDATE_EMAIL) || !in_array($paypalMode, ['sandbox', 'live'], true)) {
            $error = 'Cài đặt ví không hợp lệ.';
        } else {
        $db->beginTransaction();
        $upsert = $db->prepare("INSERT INTO settings (`key`, `value`) VALUES (:k, :v) ON DUPLICATE KEY UPDATE `value` = :v");
        $upsert->execute([':k' => 'paypal_email', ':v' => $paypalEmail]);
        $upsert->execute([':k' => 'paypal_mode', ':v' => $paypalMode]);
        writeAdminAudit($db, (int)$_SESSION['admin_id'], 'payment_settings_updated', 'settings', 'paypal', ['mode' => $paypalMode]);
        $db->commit();
        $success = "Đã lưu cài đặt ví PayPal thành công!";
        }
    }
}
?>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vamper Admin Dashboard</title>
    <!-- Tailwind CSS CDN -->
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
</head>
<body class="bg-gray-100 font-sans">

<?php if (!$isAdminLoggedIn): ?>
    <!-- LOGIN SCREEN -->
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-pink-500 to-red-600 px-4">
        <div class="bg-white p-8 rounded-2xl shadow-2xl w-full max-w-md">
            <div class="text-center mb-8">
                <div class="inline-block p-3 bg-red-100 rounded-full text-red-500 text-3xl mb-3">
                    <i class="fa-solid fa-heart-pulse"></i>
                </div>
                <h1 class="text-2xl font-bold text-gray-800">Vamper Admin Portal</h1>
                <p class="text-gray-500 text-sm mt-1">Đăng nhập để quản lý hệ thống</p>
            </div>

            <?php if ($error): ?>
                <div class="mb-4 p-3 bg-red-50 border-l-4 border-red-500 text-red-700 text-sm rounded">
                    <?= htmlspecialchars($error) ?>
                </div>
            <?php endif; ?>

            <form method="POST" class="space-y-4">
                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                <div>
                    <label class="block text-gray-700 text-sm font-semibold mb-2">Email Admin</label>
                    <input type="email" name="email" required class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-red-500 text-sm" placeholder="admin@vamper.com">
                </div>
                <div>
                    <label class="block text-gray-700 text-sm font-semibold mb-2">Mật khẩu</label>
                    <input type="password" name="password" required class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-red-500 text-sm" placeholder="••••••••">
                </div>
                <button type="submit" name="login" class="w-full py-3 bg-red-500 text-white font-semibold rounded-lg shadow-md hover:bg-red-600 transition duration-200">
                    Đăng Nhập Quản Trị
                </button>
            </form>
        </div>
    </div>
<?php else:
    if (!adminTableExists($db, 'settings')) {
        $db->exec("CREATE TABLE IF NOT EXISTS settings (
            `key` VARCHAR(255) PRIMARY KEY,
            `value` TEXT NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    }
    if (!adminTableExists($db, 'transactions')) {
        $db->exec("CREATE TABLE IF NOT EXISTS transactions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            amount_usd DECIMAL(10,2) NOT NULL,
            coins INT NOT NULL,
            gateway VARCHAR(50) DEFAULT 'PayPal',
            status VARCHAR(50) DEFAULT 'completed',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    }

    $adminRole = $_SESSION['admin_role'];
    $tabPermissions = [
        'dashboard' => 'dashboard', 'users' => 'users', 'posts' => 'reports',
        'reports' => 'reports', 'wallet' => 'finance', 'ledger' => 'finance',
        'shop' => 'shop', 'admins' => 'admins', 'audit' => 'audit',
    ];
    if (!isset($tabPermissions[$tab]) || !adminHasPermission($adminRole, $tabPermissions[$tab])) {
        $tab = 'dashboard';
    }

    $dateFrom = preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateFrom) ? $dateFrom : date('Y-m-01');
    $dateTo = preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateTo) ? $dateTo : date('Y-m-d');
    if ($dateFrom > $dateTo) {
        [$dateFrom, $dateTo] = [$dateTo, $dateFrom];
    }

    // Fetch stats
    $statsStmt = $db->query("SELECT
        (SELECT COUNT(*) FROM users) as total_users,
        (SELECT COUNT(*) FROM posts) as total_posts,
        (SELECT COUNT(*) FROM users WHERE is_active = 0) as banned_users,
        (SELECT COUNT(*) FROM users WHERE role = 'admin') as total_admins,
        (SELECT COUNT(*) FROM reports WHERE status IN ('pending', 'reviewing')) as pending_reports,
        (SELECT COALESCE(SUM(amount_usd), 0) FROM transactions WHERE status = 'completed') as total_revenue,
        (SELECT COALESCE(SUM(coins), 0) FROM transactions WHERE status = 'completed') as total_coins_sold,
        (SELECT COUNT(*) FROM transactions WHERE status = 'completed') as total_transactions");
    $stats = $statsStmt->fetch(PDO::FETCH_ASSOC);
    $periodStatsStmt = $db->prepare(
        "SELECT
            (SELECT COUNT(*) FROM users WHERE created_at >= :users_from AND created_at < DATE_ADD(:users_to, INTERVAL 1 DAY)) AS new_users,
            (SELECT COUNT(*) FROM posts WHERE created_at >= :posts_from AND created_at < DATE_ADD(:posts_to, INTERVAL 1 DAY)) AS new_posts,
            (SELECT COUNT(*) FROM reports WHERE status IN ('pending', 'reviewing') AND created_at >= :reports_from AND created_at < DATE_ADD(:reports_to, INTERVAL 1 DAY)) AS new_reports,
            (SELECT COALESCE(SUM(amount_usd), 0) FROM transactions WHERE status = 'completed' AND created_at >= :tx_from AND created_at < DATE_ADD(:tx_to, INTERVAL 1 DAY)) AS period_revenue"
    );
    $periodStatsStmt->execute([
        ':users_from' => $dateFrom, ':users_to' => $dateTo,
        ':posts_from' => $dateFrom, ':posts_to' => $dateTo,
        ':reports_from' => $dateFrom, ':reports_to' => $dateTo,
        ':tx_from' => $dateFrom, ':tx_to' => $dateTo,
    ]);
    $periodStats = $periodStatsStmt->fetch(PDO::FETCH_ASSOC);

    // Fetch settings
    $settingsStmt = $db->query("SELECT * FROM settings");
    $settingsMap = [];
    while ($row = $settingsStmt->fetch(PDO::FETCH_ASSOC)) {
        $settingsMap[$row['key']] = $row['value'];
    }
    $paypalEmail = $settingsMap['paypal_email'] ?? 'admin@vamper.com';
    $paypalMode = $settingsMap['paypal_mode'] ?? 'sandbox';

    // Search, status filter, and pagination for user operations.
    $userConditions = [];
    $userParams = [];
    if ($search !== '') {
        $userConditions[] = '(full_name LIKE :name_search OR email LIKE :email_search)';
        $userParams[':name_search'] = '%' . $search . '%';
        $userParams[':email_search'] = '%' . $search . '%';
    }
    if (in_array($userStatus, ['active', 'banned'], true)) {
        $userConditions[] = 'is_active = :active';
        $userParams[':active'] = $userStatus === 'active' ? 1 : 0;
    } else {
        $userStatus = '';
    }
    $userWhere = $userConditions ? ' WHERE ' . implode(' AND ', $userConditions) : '';
    $userCount = $db->prepare('SELECT COUNT(*) FROM users' . $userWhere);
    $userCount->execute($userParams);
    $totalUsers = (int)$userCount->fetchColumn();
    $totalPages = max(1, (int)ceil($totalUsers / $limit));
    $page = min($page, $totalPages);
    $offset = ($page - 1) * $limit;
    $stmtUsers = $db->prepare(
        'SELECT id, full_name, email, role, gender, coins, is_active, created_at FROM users' .
        $userWhere . ' ORDER BY created_at DESC LIMIT :limit OFFSET :offset'
    );
    foreach ($userParams as $key => $value) {
        $stmtUsers->bindValue($key, $value, is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR);
    }
    $stmtUsers->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmtUsers->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmtUsers->execute();
    $users = $stmtUsers->fetchAll(PDO::FETCH_ASSOC);

    // Fetch posts for moderation with pagination
    $totalPosts = $db->query("SELECT COUNT(*) FROM posts")->fetchColumn();
    $totalPostPages = max(1, (int)ceil($totalPosts / $postLimit));
    $postPage = min($postPage, $totalPostPages);
    $postOffset = ($postPage - 1) * $postLimit;

    $postsStmt = $db->prepare("SELECT p.id, p.content, p.image_url, p.status, p.created_at, u.full_name, u.email FROM posts p LEFT JOIN users u ON p.user_id = u.id ORDER BY p.created_at DESC LIMIT :limit OFFSET :offset");
    $postsStmt->bindValue(':limit', $postLimit, PDO::PARAM_INT);
    $postsStmt->bindValue(':offset', $postOffset, PDO::PARAM_INT);
    $postsStmt->execute();
    $posts = $postsStmt->fetchAll(PDO::FETCH_ASSOC);

    // Fetch reports
    $reportsStmt = $db->query("SELECT r.*, u.full_name as reporter_name, u.email as reporter_email,
                                      p.content as post_content, p.image_url AS post_image,
                                      author.full_name as author_name,
                                      target_user.full_name AS reported_user_name,
                                      target_user.email AS reported_user_email
                               FROM reports r
                               LEFT JOIN users u ON r.reporter_id = u.id
                               LEFT JOIN posts p ON r.target_id = p.id AND r.target_type = 'post'
                               LEFT JOIN users author ON p.user_id = author.id
                               LEFT JOIN users target_user ON r.target_id = target_user.id AND r.target_type = 'user'
                               ORDER BY r.created_at DESC");
    $reports = $reportsStmt->fetchAll(PDO::FETCH_ASSOC);

    // Fetch searchable transactions with pagination.
    $txConditions = [];
    $txParams = [];
    if ($txSearch !== '') {
        $txConditions[] = '(u.full_name LIKE :tx_name OR u.email LIKE :tx_email)';
        $txParams[':tx_name'] = '%' . $txSearch . '%';
        $txParams[':tx_email'] = '%' . $txSearch . '%';
    }
    if (in_array($txStatus, ['completed', 'pending', 'failed', 'sandbox_mock'], true)) {
        $txConditions[] = 't.status = :tx_status';
        $txParams[':tx_status'] = $txStatus;
    } else {
        $txStatus = '';
    }
    if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $txDateFrom)) {
        $txConditions[] = 't.created_at >= :tx_from';
        $txParams[':tx_from'] = $txDateFrom;
    } else {
        $txDateFrom = '';
    }
    if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $txDateTo)) {
        $txConditions[] = 't.created_at < DATE_ADD(:tx_to, INTERVAL 1 DAY)';
        $txParams[':tx_to'] = $txDateTo;
    } else {
        $txDateTo = '';
    }
    $txWhere = $txConditions ? ' WHERE ' . implode(' AND ', $txConditions) : '';
    $txCount = $db->prepare('SELECT COUNT(*) FROM transactions t LEFT JOIN users u ON u.id = t.user_id' . $txWhere);
    $txCount->execute($txParams);
    $totalTx = (int)$txCount->fetchColumn();
    $totalTxPages = max(1, (int)ceil($totalTx / $txLimit));
    $txPage = min($txPage, $totalTxPages);
    $txOffset = ($txPage - 1) * $txLimit;

    $txStmt = $db->prepare("SELECT t.*, u.full_name, u.email FROM transactions t LEFT JOIN users u ON t.user_id = u.id $txWhere ORDER BY t.created_at DESC LIMIT :limit OFFSET :offset");
    foreach ($txParams as $key => $value) {
        $txStmt->bindValue($key, $value, PDO::PARAM_STR);
    }
    $txStmt->bindValue(':limit', $txLimit, PDO::PARAM_INT);
    $txStmt->bindValue(':offset', $txOffset, PDO::PARAM_INT);
    $txStmt->execute();
    $transactions = $txStmt->fetchAll(PDO::FETCH_ASSOC);

    $ledgerStmt = $db->query("SELECT l.*, u.full_name, u.email, a.full_name AS admin_name
        FROM vpc_ledger l LEFT JOIN users u ON u.id = l.user_id
        LEFT JOIN users a ON a.id = l.actor_id ORDER BY l.id DESC LIMIT 100");
    $ledgerEntries = $ledgerStmt->fetchAll(PDO::FETCH_ASSOC);
    $shopItems = $db->query("SELECT id, name, type, image_url, price_coins, is_active FROM shop_items ORDER BY type, price_coins, id")
        ->fetchAll(PDO::FETCH_ASSOC);
    $adminRows = $db->query("SELECT u.id, u.full_name, u.email, u.is_active, a.admin_role
        FROM users u JOIN admin_accounts a ON a.user_id = u.id
        WHERE u.role = 'admin' ORDER BY a.admin_role, u.id")->fetchAll(PDO::FETCH_ASSOC);
    $auditRows = $db->query("SELECT l.*, u.full_name AS admin_name
        FROM admin_audit_log l LEFT JOIN users u ON u.id = l.actor_id
        ORDER BY l.id DESC LIMIT 100")->fetchAll(PDO::FETCH_ASSOC);
?>
    <!-- RESPONSIVE DASHBOARD LAYOUT -->
    <div class="flex h-screen overflow-hidden bg-gray-100">
        <!-- Sidebar Backdrop for Mobile -->
        <div id="sidebarBackdrop" onclick="toggleSidebar()" class="fixed inset-0 bg-black bg-opacity-50 z-40 hidden md:hidden"></div>

        <!-- Sidebar -->
        <div id="sidebar" class="fixed inset-y-0 left-0 z-50 w-64 bg-gray-900 text-white flex flex-col shadow-xl transform -translate-x-full md:translate-x-0 md:static md:inset-auto transition duration-300 ease-in-out">
            <div class="p-5 text-center border-b border-gray-800 flex justify-between items-center md:block">
                <h2 class="text-xl font-bold text-red-500 flex items-center justify-center gap-2">
                    <i class="fa-solid fa-fire"></i> Vamper Admin
                </h2>
                <button onclick="toggleSidebar()" class="md:hidden text-gray-400 hover:text-white focus:outline-none">
                    <i class="fa-solid fa-xmark text-xl"></i>
                </button>
                <span class="text-xs text-gray-400 hidden md:block mt-1">Management Panel</span>
            </div>
            <nav class="flex-1 p-4 space-y-2 overflow-y-auto">
                <?php
                $navItems = [
                    'dashboard' => ['dashboard', 'fa-chart-line', 'Tổng Quan'],
                    'users' => ['users', 'fa-users', 'Quản Lý Người Dùng'],
                    'posts' => ['reports', 'fa-newspaper', 'Kiểm Duyệt Bài Đăng'],
                    'reports' => ['reports', 'fa-flag', 'Quản Lý Tố Cáo'],
                    'wallet' => ['finance', 'fa-wallet', 'Ví & Giao Dịch'],
                    'ledger' => ['finance', 'fa-book', 'Sổ Cái VPC'],
                    'shop' => ['shop', 'fa-store', 'Quản Lý Shop'],
                    'admins' => ['admins', 'fa-user-shield', 'Phân Quyền Admin'],
                    'audit' => ['audit', 'fa-clipboard-list', 'Nhật Ký Quản Trị'],
                ];
                foreach ($navItems as $navTab => [$permission, $icon, $label]):
                    if (!adminHasPermission($adminRole, $permission)) continue;
                ?>
                    <a href="admin.php?tab=<?= $navTab ?>" class="flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition <?= $tab === $navTab ? 'bg-red-500 text-white shadow-lg' : 'text-gray-400 hover:bg-gray-800 hover:text-white' ?>">
                        <i class="fa-solid <?= $icon ?> w-5"></i> <?= $label ?>
                    </a>
                <?php endforeach; ?>
            </nav>
            <div class="p-4 border-t border-gray-800">
                <form method="POST">
                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                    <input type="hidden" name="action" value="logout">
                    <button class="w-full text-left flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium text-red-400 hover:bg-red-500 hover:text-white transition">
                        <i class="fa-solid fa-right-from-bracket w-5"></i> Đăng Xuất
                    </button>
                </form>
            </div>
        </div>

        <!-- Main Content Area -->
        <div class="flex-1 flex flex-col overflow-y-auto">
            <!-- Top Header -->
            <header class="bg-white shadow-sm px-4 md:px-8 py-4 flex justify-between items-center sticky top-0 z-30">
                <div class="flex items-center gap-3">
                    <button onclick="toggleSidebar()" class="md:hidden text-gray-700 focus:outline-none text-xl p-1">
                        <i class="fa-solid fa-bars"></i>
                    </button>
                    <h1 class="text-base md:text-xl font-bold text-gray-800 truncate">
                        <?= htmlspecialchars([
                            'dashboard' => 'Tổng Quan',
                            'users' => 'Quản Lý Người Dùng',
                            'posts' => 'Kiểm Duyệt Bài Đăng',
                            'reports' => 'Quản Lý Tố Cáo',
                            'wallet' => 'Ví & Giao Dịch Tài Chính',
                            'ledger' => 'Sổ Cái VPC',
                            'shop' => 'Quản Lý Shop',
                            'admins' => 'Phân Quyền Admin',
                            'audit' => 'Nhật Ký Quản Trị',
                        ][$tab] ?? 'Tổng Quan') ?>
                    </h1>
                </div>
                <div class="flex items-center gap-3">
                    <div class="text-right hidden sm:block">
                        <p class="text-sm font-semibold text-gray-800"><?= htmlspecialchars($_SESSION['admin_name']) ?></p>
                        <p class="text-xs text-gray-500"><?= htmlspecialchars(str_replace('_', ' ', $adminRole)) ?></p>
                    </div>
                    <div class="w-9 h-9 md:w-10 md:h-10 rounded-full bg-red-500 text-white flex items-center justify-center font-bold text-sm md:text-base">
                        <?= strtoupper(substr($_SESSION['admin_name'], 0, 1)) ?>
                    </div>
                </div>
            </header>

            <!-- Content Body -->
            <main class="p-4 md:p-8 flex-1">
                <?php if ($success): ?>
                    <div class="mb-6 p-4 bg-green-50 border-l-4 border-green-500 text-green-700 text-sm rounded shadow-sm flex items-center justify-between">
                        <span><?= htmlspecialchars($success) ?></span>
                        <button onclick="this.parentElement.style.display='none'" class="text-green-700 font-bold">&times;</button>
                    </div>
                <?php endif; ?>
                <?php if ($error): ?>
                    <div class="mb-6 p-4 bg-red-50 border-l-4 border-red-500 text-red-700 text-sm rounded shadow-sm flex items-center justify-between">
                        <span><?= htmlspecialchars($error) ?></span>
                        <button onclick="this.parentElement.style.display='none'" class="text-red-700 font-bold">&times;</button>
                    </div>
                <?php endif; ?>

                <?php if ($tab === 'dashboard'): ?>
                    <form method="GET" class="bg-white rounded-xl shadow-sm p-4 mb-6 flex flex-wrap items-end gap-3">
                        <input type="hidden" name="tab" value="dashboard">
                        <label class="text-sm">Từ ngày<input class="block border rounded px-3 py-2" type="date" name="date_from" value="<?= htmlspecialchars($dateFrom) ?>"></label>
                        <label class="text-sm">Đến ngày<input class="block border rounded px-3 py-2" type="date" name="date_to" value="<?= htmlspecialchars($dateTo) ?>"></label>
                        <button class="px-4 py-2 bg-gray-800 text-white rounded">Lọc thống kê</button>
                    </form>
                    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
                        <?php
                        $dashboardCards = [
                            'Người dùng mới' => $periodStats['new_users'],
                            'Bài đăng mới' => $periodStats['new_posts'],
                            'Tố cáo mới' => $periodStats['new_reports'],
                            'Tổng người dùng' => $stats['total_users'],
                            'Tổng bài đăng' => $stats['total_posts'],
                            'Tố cáo đang chờ' => $stats['pending_reports'],
                        ];
                        if (adminHasPermission($adminRole, 'finance')) {
                            $dashboardCards['Doanh thu kỳ này'] = '$' . number_format((float)$periodStats['period_revenue'], 2);
                            $dashboardCards['Tổng VPC đã bán'] = number_format((int)$stats['total_coins_sold']);
                        }
                        foreach ($dashboardCards as $label => $value): ?>
                            <div class="bg-white rounded-xl shadow-sm p-5">
                                <p class="text-sm text-gray-500"><?= htmlspecialchars($label) ?></p>
                                <p class="text-2xl font-bold text-gray-800 mt-2"><?= htmlspecialchars((string)$value) ?></p>
                            </div>
                        <?php endforeach; ?>
                    </div>
                <?php elseif ($tab === 'users'): ?>
                    <!-- Stats Grid -->
                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6 mb-8">
                        <div class="bg-white p-5 md:p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                            <div>
                                <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tổng Người Dùng</p>
                                <h3 class="text-xl md:text-2xl font-bold text-gray-800 mt-1"><?= $stats['total_users'] ?></h3>
                            </div>
                            <div class="p-3 bg-blue-50 text-blue-500 rounded-xl text-lg md:text-xl"><i class="fa-solid fa-users"></i></div>
                        </div>
                        <div class="bg-white p-5 md:p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                            <div>
                                <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tổng Bài Đăng</p>
                                <h3 class="text-xl md:text-2xl font-bold text-gray-800 mt-1"><?= $stats['total_posts'] ?></h3>
                            </div>
                            <div class="p-3 bg-green-50 text-green-500 rounded-xl text-lg md:text-xl"><i class="fa-solid fa-newspaper"></i></div>
                        </div>
                        <div class="bg-white p-5 md:p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                            <div>
                                <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tố Cáo Chưa Xử Lý</p>
                                <h3 class="text-xl md:text-2xl font-bold text-red-600 mt-1"><?= $stats['pending_reports'] ?></h3>
                            </div>
                            <div class="p-3 bg-red-50 text-red-500 rounded-xl text-lg md:text-xl"><i class="fa-solid fa-flag"></i></div>
                        </div>
                        <div class="bg-white p-5 md:p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                            <div>
                                <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Quản Trị Viên</p>
                                <h3 class="text-xl md:text-2xl font-bold text-gray-800 mt-1"><?= $stats['total_admins'] ?></h3>
                            </div>
                            <div class="p-3 bg-purple-50 text-purple-500 rounded-xl text-lg md:text-xl"><i class="fa-solid fa-shield-halved"></i></div>
                        </div>
                    </div>

                    <!-- USERS TAB -->
                    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden mb-8">
                        <div class="p-4 md:p-6 border-b border-gray-100 flex flex-col md:flex-row justify-between items-center gap-4">
                            <div class="flex items-center gap-3 w-full md:w-auto">
                                <h3 class="text-base md:text-lg font-bold text-gray-800">Danh Sách Người Dùng</h3>
                                <button onclick="openAddModal()" class="px-3.5 py-2 bg-red-500 text-white rounded-lg text-xs md:text-sm font-semibold hover:bg-red-600 transition flex items-center gap-2 whitespace-nowrap">
                                    <i class="fa-solid fa-user-plus"></i> Thêm Người Dùng
                                </button>
                            </div>
                            <form method="GET" class="flex flex-wrap gap-2 w-full md:w-auto">
                                <input type="hidden" name="tab" value="users">
                                <input type="text" name="search" value="<?= htmlspecialchars($search) ?>" placeholder="Tìm kiếm tên hoặc email..." class="px-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500 w-full md:w-72">
                                <select name="status" class="px-3 py-2 border rounded-lg text-sm">
                                    <option value="">Mọi trạng thái</option>
                                    <option value="active" <?= $userStatus === 'active' ? 'selected' : '' ?>>Đang hoạt động</option>
                                    <option value="banned" <?= $userStatus === 'banned' ? 'selected' : '' ?>>Đã khóa</option>
                                </select>
                                <button type="submit" class="px-4 py-2 bg-gray-800 text-white rounded-lg text-sm font-semibold hover:bg-gray-700 transition">Tìm</button>
                                <?php if ($search): ?>
                                    <a href="admin.php?tab=users" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg text-sm font-semibold hover:bg-gray-300 transition flex items-center">Reset</a>
                                <?php endif; ?>
                            </form>
                        </div>
                        <div class="overflow-x-auto">
                            <table class="w-full text-left border-collapse min-w-[800px]">
                                <thead>
                                    <tr class="bg-gray-50 text-gray-600 text-xs uppercase font-semibold tracking-wider">
                                        <th class="py-3 px-4 md:px-6">ID</th>
                                        <th class="py-3 px-4 md:px-6">Họ Tên</th>
                                        <th class="py-3 px-4 md:px-6">Email</th>
                                        <th class="py-3 px-4 md:px-6">Vai Trò</th>
                                        <th class="py-3 px-4 md:px-6">Giới Tính</th>
                                        <th class="py-3 px-4 md:px-6">Số Xu</th>
                                        <th class="py-3 px-4 md:px-6">Trạng Thái</th>
                                        <th class="py-3 px-4 md:px-6">Ngày Tạo</th>
                                        <th class="py-3 px-4 md:px-6 text-center">Thao Tác</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-gray-200 text-sm">
                                    <?php if (empty($users)): ?>
                                        <tr><td colspan="9" class="py-6 text-center text-gray-400">Không tìm thấy người dùng nào.</td></tr>
                                    <?php else: foreach ($users as $u):
                                        $statusBadge = $u['is_active'] == 1 ? '<span class="px-2.5 py-1 bg-green-100 text-green-800 rounded-full text-xs font-semibold">Active</span>' : '<span class="px-2.5 py-1 bg-red-100 text-red-800 rounded-full text-xs font-semibold">Banned</span>';
                                        $roleBadge = $u['role'] === 'admin' ? '<span class="px-2.5 py-1 bg-purple-100 text-purple-800 rounded-full text-xs font-semibold">Admin</span>' : '<span class="text-gray-600">User</span>';
                                        $toggleText = $u['is_active'] == 1 ? 'Khóa' : 'Mở Khóa';
                                        $toggleClass = $u['is_active'] == 1 ? 'bg-red-500 hover:bg-red-600' : 'bg-green-500 hover:bg-green-600';
                                    ?>
                                    <tr class="hover:bg-gray-50 transition">
                                        <td class="py-4 px-4 md:px-6 text-gray-500">#<?= $u['id'] ?></td>
                                        <td class="py-4 px-4 md:px-6 font-semibold text-gray-800"><?= htmlspecialchars($u['full_name'] ?? '') ?></td>
                                        <td class="py-4 px-4 md:px-6 text-gray-600"><?= htmlspecialchars($u['email']) ?></td>
                                        <td class="py-4 px-4 md:px-6"><?= $roleBadge ?></td>
                                        <td class="py-4 px-4 md:px-6 text-gray-600"><?= htmlspecialchars($u['gender'] ?? '-') ?></td>
                                        <td class="py-4 px-4 md:px-6">
                                            <?php if (adminHasPermission($adminRole, 'finance')): ?>
                                            <form method="POST" class="flex items-center gap-1.5">
                                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                                                <input type="hidden" name="action" value="adjust_coins">
                                                <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                                                <input type="number" name="amount_delta" required placeholder="+/- VPC" class="w-20 px-2 py-1 border border-gray-300 rounded text-sm" title="Số dương để cộng, số âm để trừ">
                                                <input type="text" name="reason" required maxlength="500" placeholder="Lý do" class="w-24 px-2 py-1 border border-gray-300 rounded text-sm">
                                                <button type="submit" class="px-2.5 py-1 bg-blue-500 text-white rounded text-xs font-semibold hover:bg-blue-600 transition">Điều chỉnh</button>
                                            </form>
                                            <?php else: ?>
                                                <?= number_format((int)$u['coins']) ?> VPC
                                            <?php endif; ?>
                                        </td>
                                        <td class="py-4 px-4 md:px-6"><?= $statusBadge ?></td>
                                        <td class="py-4 px-4 md:px-6 text-gray-500 text-xs"><?= substr($u['created_at'], 0, 10) ?></td>
                                        <td class="py-4 px-4 md:px-6 text-center space-x-1 whitespace-nowrap">
                                            <button onclick='openEditModal(<?= json_encode($u) ?>)' class="px-2.5 py-1.5 bg-yellow-500 text-white rounded text-xs font-semibold hover:bg-yellow-600 transition" title="Sửa">
                                                <i class="fa-solid fa-pen"></i>
                                            </button>
                                            <?php if ($u['role'] !== 'admin'): ?><form method="POST" class="inline" onsubmit="return confirm('Bạn có chắc chắn muốn thay đổi trạng thái tài khoản này?');">
                                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                                                <input type="hidden" name="action" value="set_user_status">
                                                <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                                                <input type="hidden" name="is_active" value="<?= $u['is_active'] ? 0 : 1 ?>">
                                                <input type="text" name="reason" required maxlength="500" placeholder="Lý do khóa/mở" class="w-24 px-2 py-1 border rounded text-xs">
                                                <button type="submit" class="px-2.5 py-1.5 text-white rounded text-xs font-semibold shadow-sm transition <?= $toggleClass ?>" title="<?= $toggleText ?>"><?= $toggleText ?></button>
                                            </form><?php else: ?><span class="text-xs text-gray-400">Admin protected</span><?php endif; ?>
                                        </td>
                                    </tr>
                                    <?php endforeach; endif; ?>
                                </tbody>
                            </table>
                        </div>

                        <!-- Pagination -->
                        <?php if ($totalPages > 1): ?>
                            <div class="p-4 md:p-6 border-t border-gray-100 flex flex-col sm:flex-row justify-between items-center gap-4">
                                <span class="text-xs md:text-sm text-gray-500">Trang <?= $page ?> / <?= $totalPages ?> (Tổng <?= $totalUsers ?> người dùng)</span>
                                <div class="flex flex-wrap gap-1">
                                    <?php if ($page > 1): ?>
                                        <a href="admin.php?<?= htmlspecialchars(http_build_query(['tab' => 'users', 'page' => $page - 1, 'search' => $search, 'status' => $userStatus])) ?>" class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300">Trước</a>
                                    <?php endif; ?>
                                    <span class="px-3 py-1.5 text-sm font-semibold"><?= $page ?> / <?= $totalPages ?></span>
                                    <?php if ($page < $totalPages): ?>
                                        <a href="admin.php?<?= htmlspecialchars(http_build_query(['tab' => 'users', 'page' => $page + 1, 'search' => $search, 'status' => $userStatus])) ?>" class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300">Sau</a>
                                    <?php endif; ?>
                                </div>
                            </div>
                        <?php endif; ?>
                    </div>
                <?php elseif ($tab === 'posts'): ?>
                    <!-- POSTS MODERATION TAB -->
                    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                        <div class="p-4 md:p-6 border-b border-gray-100">
                            <h3 class="text-base md:text-lg font-bold text-gray-800">Kiểm Duyệt Bài Đăng</h3>
                        </div>
                        <div class="overflow-x-auto">
                            <table class="w-full text-left border-collapse min-w-[700px]">
                                <thead>
                                    <tr class="bg-gray-50 text-gray-600 text-xs uppercase font-semibold tracking-wider">
                                        <th class="py-3 px-4 md:px-6">ID</th>
                                        <th class="py-3 px-4 md:px-6">Tác Giả</th>
                                        <th class="py-3 px-4 md:px-6">Nội Dung</th>
                                        <th class="py-3 px-4 md:px-6">Hình Ảnh</th>
                                        <th class="py-3 px-4 md:px-6">Ngày Đăng</th>
                                        <th class="py-3 px-4 md:px-6 text-center">Thao Tác</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-gray-200 text-sm">
                                    <?php if (empty($posts)): ?>
                                        <tr><td colspan="6" class="py-6 text-center text-gray-400">Không có bài đăng nào.</td></tr>
                                    <?php else: foreach ($posts as $p): ?>
                                    <tr class="hover:bg-gray-50 transition">
                                        <td class="py-4 px-4 md:px-6 text-gray-500">#<?= $p['id'] ?></td>
                                        <td class="py-4 px-4 md:px-6 font-semibold text-gray-800">
                                            <?= htmlspecialchars($p['full_name']) ?>
                                            <div class="text-xs text-gray-400 font-normal"><?= htmlspecialchars($p['email']) ?></div>
                                        </td>
                                        <td class="py-4 px-4 md:px-6 text-gray-700 max-w-xs truncate"><?= htmlspecialchars($p['content'] ?? '') ?></td>
                                        <td class="py-4 px-4 md:px-6">
                                            <?php if (!empty($p['image_url'])): ?>
                                                <a href="<?= htmlspecialchars($p['image_url']) ?>" target="_blank" class="text-blue-500 underline text-xs">Xem ảnh</a>
                                            <?php else: ?>
                                                <span class="text-gray-400 text-xs">Không có</span>
                                            <?php endif; ?>
                                        </td>
                                        <td class="py-4 px-4 md:px-6 text-gray-500 text-xs"><?= $p['created_at'] ?></td>
                                        <td class="py-4 px-4 md:px-6 text-center">
                                            <form method="POST" onsubmit="return confirm('Bạn có chắc chắn muốn xóa bài đăng này?');">
                                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                                                <input type="hidden" name="action" value="set_post_status">
                                                <input type="hidden" name="post_id" value="<?= $p['id'] ?>">
                                                <input type="hidden" name="status" value="<?= $p['status'] ? 0 : 1 ?>">
                                                <button type="submit" class="px-3 py-1.5 <?= $p['status'] ? 'bg-red-500' : 'bg-green-600' ?> text-white rounded text-xs font-semibold shadow-sm"><?= $p['status'] ? 'Ẩn Bài' : 'Khôi Phục' ?></button>
                                            </form>
                                        </td>
                                    </tr>
                                    <?php endforeach; endif; ?>
                                </tbody>
                            </table>
                        </div>

                        <!-- Posts Pagination -->
                        <?php if ($totalPostPages > 1): ?>
                            <div class="p-4 md:p-6 border-t border-gray-100 flex flex-col sm:flex-row justify-between items-center gap-4">
                                <span class="text-xs md:text-sm text-gray-500">Trang <?= $postPage ?> / <?= $totalPostPages ?> (Tổng <?= $totalPosts ?> bài viết)</span>
                                <div class="flex flex-wrap gap-1">
                                    <?php if ($postPage > 1): ?>
                                        <a href="admin.php?tab=posts&post_page=<?= $postPage - 1 ?>" class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300">Trước</a>
                                    <?php endif; ?>

                                    <span class="px-3 py-1.5 text-sm font-semibold"><?= $postPage ?> / <?= $totalPostPages ?></span>

                                    <?php if ($postPage < $totalPostPages): ?>
                                        <a href="admin.php?tab=posts&post_page=<?= $postPage + 1 ?>" class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300">Sau</a>
                                    <?php endif; ?>
                                </div>
                            </div>
                        <?php endif; ?>
                    </div>
                <?php elseif ($tab === 'reports'): ?>
                    <!-- REPORTS TAB -->
                    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                        <div class="p-4 md:p-6 border-b border-gray-100">
                            <h3 class="text-base md:text-lg font-bold text-gray-800">Quản Lý Tố Cáo (Reports)</h3>
                        </div>
                        <div class="overflow-x-auto">
                            <table class="w-full text-left border-collapse min-w-[800px]">
                                <thead>
                                    <tr class="bg-gray-50 text-gray-600 text-xs uppercase font-semibold tracking-wider">
                                        <th class="py-3 px-4 md:px-6">ID</th>
                                        <th class="py-3 px-4 md:px-6">Người Tố Cáo</th>
                                        <th class="py-3 px-4 md:px-6">Nội Dung Bị Tố Cáo</th>
                                        <th class="py-3 px-4 md:px-6">Lý Do</th>
                                        <th class="py-3 px-4 md:px-6">Mô Tả</th>
                                        <th class="py-3 px-4 md:px-6">Trạng Thái</th>
                                        <th class="py-3 px-4 md:px-6">Thời Gian</th>
                                        <th class="py-3 px-4 md:px-6 text-center">Thao Tác</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-gray-200 text-sm">
                                    <?php if (empty($reports)): ?>
                                        <tr><td colspan="8" class="py-6 text-center text-gray-400">Không có tố cáo nào.</td></tr>
                                    <?php else: foreach ($reports as $r):
                                        $statusBadge = $r['status'] === 'pending'
                                            ? '<span class="px-2.5 py-1 bg-yellow-100 text-yellow-800 rounded-full text-xs font-semibold">Pending</span>'
                                            : ($r['status'] === 'reviewing'
                                                ? '<span class="px-2.5 py-1 bg-blue-100 text-blue-800 rounded-full text-xs font-semibold">Reviewing</span>'
                                                : ($r['status'] === 'resolved'
                                                    ? '<span class="px-2.5 py-1 bg-green-100 text-green-800 rounded-full text-xs font-semibold">Resolved</span>'
                                                    : '<span class="px-2.5 py-1 bg-gray-100 text-gray-800 rounded-full text-xs font-semibold">Dismissed</span>'));
                                    ?>
                                    <tr class="hover:bg-gray-50 transition">
                                        <td class="py-4 px-4 md:px-6 text-gray-500">#<?= $r['id'] ?></td>
                                        <td class="py-4 px-4 md:px-6 font-semibold text-gray-800">
                                            <?= htmlspecialchars($r['reporter_name'] ?? 'Tài khoản không còn tồn tại') ?>
                                            <div class="text-xs text-gray-400 font-normal"><?= htmlspecialchars($r['reporter_email'] ?? '') ?></div>
                                        </td>
                                        <td class="py-4 px-4 md:px-6 text-gray-700 max-w-xs">
                                            <?php if ($r['target_type'] === 'post' && $r['post_content'] !== null): ?>
                                                <div class="font-semibold text-xs text-gray-500 mb-1">Tác giả: <?= htmlspecialchars($r['author_name'] ?? 'Unknown') ?></div>
                                                <div class="truncate"><?= htmlspecialchars($r['post_content']) ?></div>
                                            <?php elseif ($r['target_type'] === 'user' && $r['reported_user_name']): ?>
                                                <div><?= htmlspecialchars($r['reported_user_name']) ?></div>
                                                <div class="text-xs text-gray-400"><?= htmlspecialchars($r['reported_user_email']) ?></div>
                                            <?php else: ?>
                                                <span class="text-red-500 text-xs font-semibold">Đối tượng không còn tồn tại hoặc loại chưa hỗ trợ: <?= htmlspecialchars($r['target_type']) ?></span>
                                            <?php endif; ?>
                                        </td>
                                        <td class="py-4 px-4 md:px-6 font-semibold text-red-600"><?= htmlspecialchars($r['reason']) ?></td>
                                        <td class="py-4 px-4 md:px-6 text-gray-600 text-xs"><?= htmlspecialchars($r['description'] ?? '-') ?></td>
                                        <td class="py-4 px-4 md:px-6"><?= $statusBadge ?></td>
                                        <td class="py-4 px-4 md:px-6 text-gray-500 text-xs"><?= $r['created_at'] ?></td>
                                        <td class="py-4 px-4 md:px-6 text-center space-x-2 whitespace-nowrap">
                                            <?php if (in_array($r['status'], ['pending', 'reviewing'], true)): ?>
                                                <form method="POST" class="inline-flex items-center gap-1">
                                                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                                                    <input type="hidden" name="action" value="review_report">
                                                    <input type="hidden" name="report_id" value="<?= $r['id'] ?>">
                                                    <select name="status" class="border rounded px-1 py-1 text-xs">
                                                        <option value="reviewing" <?= $r['status'] === 'reviewing' ? 'selected' : '' ?>>Đang xem</option>
                                                        <option value="resolved">Giải quyết</option>
                                                        <option value="dismissed">Bỏ qua</option>
                                                    </select>
                                                    <input name="review_note" maxlength="500" placeholder="Ghi chú" class="border rounded px-1 py-1 text-xs w-20">
                                                    <button type="submit" class="px-2 py-1 bg-gray-800 text-white rounded text-xs">Lưu</button>
                                                </form>
                                                <?php if (!empty($r['reviewed_by'])): ?>
                                                    <div class="text-xs text-gray-500 mt-1">Đã xem bởi #<?= (int)$r['reviewed_by'] ?>: <?= htmlspecialchars($r['review_note'] ?? '') ?></div>
                                                <?php endif; ?>
                                            <?php endif; ?>
                                            <?php if (!in_array($r['status'], ['pending', 'reviewing'], true)): ?>
                                                <span class="text-xs text-gray-400 italic">Đã xử lý</span>
                                            <?php endif; ?>
                                        </td>
                                    </tr>
                                    <?php endforeach; endif; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                <?php elseif ($tab === 'wallet'): ?>
                    <!-- WALLET & TRANSACTIONS TAB -->
                    <div class="space-y-8">
                        <!-- Stats Grid -->
                        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 md:gap-6">
                            <div class="bg-white p-5 md:p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                                <div>
                                    <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tổng Doanh Thu</p>
                                    <h3 class="text-xl md:text-2xl font-bold text-green-600 mt-1">$<?= number_format($stats['total_revenue'], 2) ?></h3>
                                </div>
                                <div class="p-3 bg-green-50 text-green-500 rounded-xl text-lg md:text-xl"><i class="fa-solid fa-dollar-sign"></i></div>
                            </div>
                            <div class="bg-white p-5 md:p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                                <div>
                                    <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tổng Số Xu Đã Bán</p>
                                    <h3 class="text-xl md:text-2xl font-bold text-amber-500 mt-1"><?= number_format($stats['total_coins_sold']) ?> Coins</h3>
                                </div>
                                <div class="p-3 bg-amber-50 text-amber-500 rounded-xl text-lg md:text-xl"><i class="fa-solid fa-coins"></i></div>
                            </div>
                            <div class="bg-white p-5 md:p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                                <div>
                                    <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Giao Dịch Thành Công</p>
                                    <h3 class="text-xl md:text-2xl font-bold text-blue-600 mt-1"><?= number_format($stats['total_transactions']) ?></h3>
                                </div>
                                <div class="p-3 bg-blue-50 text-blue-500 rounded-xl text-lg md:text-xl"><i class="fa-solid fa-receipt"></i></div>
                            </div>
                        </div>

                        <!-- Admin Wallet Settings Form -->
                        <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4 md:p-6">
                            <h3 class="text-base md:text-lg font-bold text-gray-800 mb-4 flex items-center gap-2">
                                <i class="fa-solid fa-gear text-red-500"></i> Cài Đặt Ví Thanh Toán Admin (PayPal)
                            </h3>
                            <form method="POST" class="space-y-4 max-w-xl">
                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                                <input type="hidden" name="action" value="save_settings">
                                <div>
                                    <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Email Ví PayPal Business / Merchant</label>
                                    <input type="email" name="paypal_email" value="<?= htmlspecialchars($paypalEmail) ?>" required class="w-full px-4 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500">
                                </div>
                                <div>
                                    <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Môi Trường Thanh Toán</label>
                                    <select name="paypal_mode" class="w-full px-4 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500">
                                        <option value="sandbox" <?= $paypalMode === 'sandbox' ? 'selected' : '' ?>>Sandbox (Thử nghiệm)</option>
                                        <option value="live" disabled <?= $paypalMode === 'live' ? 'selected' : '' ?>>Live (chưa tích hợp xác minh server)</option>
                                    </select>
                                </div>
                                <button type="submit" class="px-6 py-2.5 bg-red-500 text-white rounded-lg text-sm font-semibold hover:bg-red-600 transition shadow-md">
                                    Lưu Cài Đặt Ví
                                </button>
                            </form>
                        </div>

                        <!-- Transaction Logs Table -->
                        <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                            <div class="p-4 md:p-6 border-b border-gray-100">
                                <h3 class="text-base md:text-lg font-bold text-gray-800">Lịch Sử Giao Dịch Nạp Xu Của Người Chơi</h3>
                                <form method="GET" class="mt-4 flex flex-wrap gap-2">
                                    <input type="hidden" name="tab" value="wallet">
                                    <input name="tx_search" value="<?= htmlspecialchars($txSearch) ?>" placeholder="Email hoặc tên người dùng" class="border rounded px-3 py-2 text-sm">
                                    <select name="tx_status" class="border rounded px-3 py-2 text-sm">
                                        <option value="">Mọi trạng thái</option>
                                        <?php foreach (['completed', 'pending', 'failed', 'sandbox_mock'] as $status): ?>
                                            <option value="<?= $status ?>" <?= $txStatus === $status ? 'selected' : '' ?>><?= htmlspecialchars($status) ?></option>
                                        <?php endforeach; ?>
                                    </select>
                                    <input type="date" name="tx_from" value="<?= htmlspecialchars($txDateFrom) ?>" class="border rounded px-3 py-2 text-sm">
                                    <input type="date" name="tx_to" value="<?= htmlspecialchars($txDateTo) ?>" class="border rounded px-3 py-2 text-sm">
                                    <button class="px-4 py-2 bg-gray-800 text-white rounded text-sm">Lọc</button>
                                </form>
                            </div>
                            <div class="overflow-x-auto">
                                <table class="w-full text-left border-collapse min-w-[700px]">
                                    <thead>
                                        <tr class="bg-gray-50 text-gray-600 text-xs uppercase font-semibold tracking-wider">
                                            <th class="py-3 px-4 md:px-6">ID Giao Dịch</th>
                                            <th class="py-3 px-6">Người Chơi</th>
                                            <th class="py-3 px-4 md:px-6">Số Tiền (USD)</th>
                                            <th class="py-3 px-4 md:px-6">Số Xu Nhận</th>
                                            <th class="py-3 px-4 md:px-6">Cổng Thanh Toán</th>
                                            <th class="py-3 px-4 md:px-6">Trạng Thái</th>
                                            <th class="py-3 px-4 md:px-6">Thời Gian</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-gray-200 text-sm">
                                        <?php if (empty($transactions)): ?>
                                            <tr><td colspan="7" class="py-6 text-center text-gray-400">Không có giao dịch nạp tiền nào.</td></tr>
                                        <?php else: foreach ($transactions as $tx): ?>
                                        <tr class="hover:bg-gray-50 transition">
                                            <td class="py-4 px-4 md:px-6 text-gray-500">#TX-<?= $tx['id'] ?></td>
                                            <td class="py-4 px-4 md:px-6 font-semibold text-gray-800">
                                                <?= htmlspecialchars($tx['full_name']) ?>
                                                <div class="text-xs text-gray-400 font-normal"><?= htmlspecialchars($tx['email']) ?></div>
                                            </td>
                                            <td class="py-4 px-4 md:px-6 font-bold text-green-600">$<?= number_format($tx['amount_usd'], 2) ?></td>
                                            <td class="py-4 px-4 md:px-6 font-bold text-amber-500">+<?= number_format($tx['coins']) ?> Coins</td>
                                            <td class="py-4 px-4 md:px-6 text-gray-700"><?= htmlspecialchars($tx['gateway']) ?></td>
                                            <td class="py-4 px-4 md:px-6"><span class="px-2.5 py-1 <?= $tx['status'] === 'completed' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800' ?> rounded-full text-xs font-semibold"><?= htmlspecialchars($tx['status']) ?></span></td>
                                            <td class="py-4 px-4 md:px-6 text-gray-500 text-xs"><?= $tx['created_at'] ?></td>
                                        </tr>
                                        <?php endforeach; endif; ?>
                                    </tbody>
                                </table>
                            </div>
                            <?php if ($totalTxPages > 1): ?>
                                <div class="p-4 border-t flex justify-between items-center text-sm">
                                    <span>Trang <?= $txPage ?> / <?= $totalTxPages ?> (<?= $totalTx ?> giao dịch)</span>
                                    <div class="flex gap-2">
                                        <?php if ($txPage > 1): ?>
                                            <a class="px-3 py-1 bg-gray-200 rounded" href="admin.php?<?= htmlspecialchars(http_build_query(['tab' => 'wallet', 'tx_page' => $txPage - 1, 'tx_search' => $txSearch, 'tx_status' => $txStatus, 'tx_from' => $txDateFrom, 'tx_to' => $txDateTo])) ?>">Trước</a>
                                        <?php endif; ?>
                                        <?php if ($txPage < $totalTxPages): ?>
                                            <a class="px-3 py-1 bg-gray-200 rounded" href="admin.php?<?= htmlspecialchars(http_build_query(['tab' => 'wallet', 'tx_page' => $txPage + 1, 'tx_search' => $txSearch, 'tx_status' => $txStatus, 'tx_from' => $txDateFrom, 'tx_to' => $txDateTo])) ?>">Sau</a>
                                        <?php endif; ?>
                                    </div>
                                </div>
                            <?php endif; ?>
                        </div>
                    </div>
                <?php elseif ($tab === 'ledger'): ?>
                    <div class="bg-white rounded-xl shadow-sm border overflow-x-auto">
                        <div class="p-5 border-b">
                            <h2 class="font-bold text-lg">Sổ cái điều chỉnh VPC của quản trị viên</h2>
                            <p class="text-sm text-gray-500 mt-1">Các giao dịch cũ chưa được dựng lại vào sổ cái vì không có đủ lịch sử số dư đáng tin cậy.</p>
                        </div>
                        <table class="w-full text-left min-w-[900px]">
                            <thead class="bg-gray-50 text-xs uppercase text-gray-500"><tr>
                                <th class="p-3">Thời gian</th><th class="p-3">Người dùng</th><th class="p-3">Biến động</th>
                                <th class="p-3">Số dư trước/sau</th><th class="p-3">Lý do</th><th class="p-3">Admin</th>
                            </tr></thead>
                            <tbody class="divide-y">
                            <?php foreach ($ledgerEntries as $entry): ?>
                                <tr>
                                    <td class="p-3 text-xs"><?= htmlspecialchars($entry['created_at']) ?></td>
                                    <td class="p-3"><?= htmlspecialchars($entry['full_name'] ?? 'Deleted user') ?><div class="text-xs text-gray-500"><?= htmlspecialchars($entry['email'] ?? '') ?></div></td>
                                    <td class="p-3 font-bold <?= (int)$entry['amount_delta'] < 0 ? 'text-red-600' : 'text-green-600' ?>"><?= (int)$entry['amount_delta'] > 0 ? '+' : '' ?><?= number_format((int)$entry['amount_delta']) ?> VPC</td>
                                    <td class="p-3"><?= number_format((int)$entry['balance_before']) ?> → <?= number_format((int)$entry['balance_after']) ?></td>
                                    <td class="p-3"><?= htmlspecialchars($entry['reason']) ?></td>
                                    <td class="p-3"><?= htmlspecialchars($entry['admin_name'] ?? 'System') ?></td>
                                </tr>
                            <?php endforeach; ?>
                            <?php if (!$ledgerEntries): ?><tr><td class="p-5 text-gray-500" colspan="6">Chưa có điều chỉnh nào.</td></tr><?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                <?php elseif ($tab === 'shop'): ?>
                    <div class="bg-white rounded-xl shadow-sm border overflow-x-auto">
                        <div class="p-5 border-b"><h2 class="font-bold text-lg">Catalog vật phẩm</h2><p class="text-sm text-gray-500">Tắt vật phẩm sẽ ẩn khỏi shop; đồ đã mua của người dùng không bị xóa.</p></div>
                        <form method="POST" class="p-5 border-b flex flex-wrap gap-3 items-end">
                            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                            <input type="hidden" name="action" value="create_shop_item">
                            <label class="text-xs">Tên<input name="name" required maxlength="255" class="block border rounded px-2 py-2"></label>
                            <label class="text-xs">Loại<select name="type" class="block border rounded px-2 py-2"><option value="profile_frame">Khung</option><option value="avatar">Avatar</option></select></label>
                            <label class="text-xs">Mã khung hoặc HTTPS URL ảnh<input name="image_url" required maxlength="255" class="block border rounded px-2 py-2 min-w-64"></label>
                            <label class="text-xs">Giá VPC<input type="number" min="0" name="price_coins" value="100" required class="block border rounded px-2 py-2 w-28"></label>
                            <button class="px-4 py-2 rounded bg-red-500 text-white">Thêm vật phẩm</button>
                        </form>
                        <table class="w-full text-left min-w-[850px]">
                            <thead class="bg-gray-50 text-xs uppercase text-gray-500"><tr><th class="p-3">ID</th><th class="p-3">Tên</th><th class="p-3">Loại</th><th class="p-3">Giá VPC</th><th class="p-3">Trạng thái</th><th class="p-3">Lưu</th></tr></thead>
                            <tbody class="divide-y">
                            <?php foreach ($shopItems as $item): ?>
                                <tr>
                                    <td class="p-3">#<?= (int)$item['id'] ?></td>
                                    <td class="p-3">
                                        <form id="shop-edit-<?= (int)$item['id'] ?>" method="POST">
                                            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                                            <input type="hidden" name="action" value="save_shop_item">
                                            <input type="hidden" name="item_id" value="<?= (int)$item['id'] ?>">
                                        </form>
                                        <input form="shop-edit-<?= (int)$item['id'] ?>" name="name" required maxlength="255" value="<?= htmlspecialchars($item['name']) ?>" class="border rounded px-2 py-1">
                                    </td>
                                    <td class="p-3"><?= htmlspecialchars($item['type']) ?></td>
                                    <td class="p-3"><input form="shop-edit-<?= (int)$item['id'] ?>" type="number" min="0" name="price_coins" value="<?= (int)$item['price_coins'] ?>" class="w-24 border rounded px-2 py-1"></td>
                                    <td class="p-3">
                                        <form id="shop-toggle-<?= (int)$item['id'] ?>" method="POST">
                                            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                                            <input type="hidden" name="action" value="toggle_shop_item">
                                            <input type="hidden" name="item_id" value="<?= (int)$item['id'] ?>">
                                            <button class="px-3 py-1 rounded text-xs text-white <?= $item['is_active'] ? 'bg-green-600' : 'bg-gray-500' ?>"><?= $item['is_active'] ? 'Đang bán' : 'Đã tắt' ?></button>
                                        </form>
                                    </td>
                                    <td class="p-3"><button form="shop-edit-<?= (int)$item['id'] ?>" class="px-3 py-1 rounded bg-blue-600 text-white text-xs">Lưu</button></td>
                                </tr>
                            <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php elseif ($tab === 'admins'): ?>
                    <div class="bg-white rounded-xl shadow-sm border overflow-x-auto">
                        <div class="p-5 border-b"><h2 class="font-bold text-lg">Quản trị viên và vai trò</h2><p class="text-sm text-gray-500">Mỗi vai trò chỉ được phép truy cập các khu vực cần thiết.</p></div>
                        <table class="w-full text-left min-w-[700px]">
                            <thead class="bg-gray-50 text-xs uppercase text-gray-500"><tr><th class="p-3">Admin</th><th class="p-3">Vai trò</th><th class="p-3">Trạng thái</th><th class="p-3">Cập nhật quyền</th></tr></thead>
                            <tbody class="divide-y">
                            <?php foreach ($adminRows as $admin): ?>
                                <tr>
                                    <td class="p-3"><?= htmlspecialchars($admin['full_name']) ?><div class="text-xs text-gray-500"><?= htmlspecialchars($admin['email']) ?></div></td>
                                    <td class="p-3"><?= htmlspecialchars(str_replace('_', ' ', $admin['admin_role'])) ?></td>
                                    <td class="p-3"><?= $admin['is_active'] ? 'Hoạt động' : 'Đã khóa' ?></td>
                                    <td class="p-3">
                                        <?php if ((int)$admin['id'] !== (int)$_SESSION['admin_id']): ?>
                                            <form method="POST" class="flex gap-2">
                                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                                                <input type="hidden" name="action" value="set_admin_role">
                                                <input type="hidden" name="user_id" value="<?= (int)$admin['id'] ?>">
                                                <select name="admin_role" class="border rounded px-2 py-1">
                                                    <?php foreach (['super_admin', 'moderator', 'finance', 'support'] as $role): ?>
                                                        <option value="<?= $role ?>" <?= $role === $admin['admin_role'] ? 'selected' : '' ?>><?= htmlspecialchars(str_replace('_', ' ', $role)) ?></option>
                                                    <?php endforeach; ?>
                                                    <option value="remove">Thu hồi admin</option>
                                                </select>
                                                <button class="px-3 py-1 bg-blue-600 text-white rounded text-xs">Lưu</button>
                                            </form>
                                        <?php else: ?><span class="text-xs text-gray-500">Không thể tự đổi quyền</span><?php endif; ?>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php elseif ($tab === 'audit'): ?>
                    <div class="bg-white rounded-xl shadow-sm border overflow-x-auto">
                        <div class="p-5 border-b"><h2 class="font-bold text-lg">Nhật ký hoạt động quản trị</h2><p class="text-sm text-gray-500">100 thao tác gần nhất.</p></div>
                        <table class="w-full text-left min-w-[800px]">
                            <thead class="bg-gray-50 text-xs uppercase text-gray-500"><tr><th class="p-3">Thời gian</th><th class="p-3">Admin</th><th class="p-3">Thao tác</th><th class="p-3">Đối tượng</th><th class="p-3">Chi tiết</th></tr></thead>
                            <tbody class="divide-y">
                            <?php foreach ($auditRows as $entry): ?>
                                <tr>
                                    <td class="p-3 text-xs"><?= htmlspecialchars($entry['created_at']) ?></td>
                                    <td class="p-3"><?= htmlspecialchars($entry['admin_name'] ?? 'Removed admin') ?></td>
                                    <td class="p-3"><?= htmlspecialchars($entry['action']) ?></td>
                                    <td class="p-3"><?= htmlspecialchars($entry['entity_type'] . ' #' . ($entry['entity_id'] ?? '-')) ?></td>
                                    <td class="p-3 text-xs"><?= htmlspecialchars($entry['details_json'] ?? '') ?></td>
                                </tr>
                            <?php endforeach; ?>
                            <?php if (!$auditRows): ?><tr><td colspan="5" class="p-5 text-gray-500">Chưa có nhật ký.</td></tr><?php endif; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </main>
        </div>
    </div>

    <!-- ADD USER MODAL -->
    <div id="addUserModal" class="fixed inset-0 bg-black bg-opacity-50 hidden items-center justify-center z-50 px-4">
        <div class="bg-white rounded-xl shadow-2xl w-full max-w-md p-6">
            <div class="flex justify-between items-center mb-4 border-b pb-3">
                <h3 class="text-lg font-bold text-gray-800">Thêm Người Dùng Mới</h3>
                <button onclick="closeAddModal()" class="text-gray-400 hover:text-gray-600 text-xl font-bold">&times;</button>
            </div>
            <form method="POST" class="space-y-4">
                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                <input type="hidden" name="action" value="create_user">
                <div>
                    <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Họ Tên</label>
                    <input type="text" name="full_name" required class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Email</label>
                    <input type="email" name="email" required class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Mật khẩu</label>
                    <input type="password" name="password" required class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                </div>
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Vai Trò</label>
                        <select name="role" class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                            <option value="user">User</option>
                            <?php if (adminHasPermission($adminRole, 'admins')): ?><option value="admin">Admin (support role)</option><?php endif; ?>
                        </select>
                    </div>
                    <div>
                        <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Giới Tính</label>
                        <select name="gender" class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                            <option value="male">Male</option>
                            <option value="female">Female</option>
                            <option value="other">Other</option>
                        </select>
                    </div>
                </div>
                <div>
                    <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Số Xu Ban Đầu</label>
                    <input type="number" name="coins" value="10" class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                </div>
                <div class="flex justify-end gap-2 pt-3 border-t">
                    <button type="button" onclick="closeAddModal()" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg text-sm font-semibold hover:bg-gray-300">Hủy</button>
                    <button type="submit" class="px-4 py-2 bg-red-500 text-white rounded-lg text-sm font-semibold hover:bg-red-600">Thêm Mới</button>
                </div>
            </form>
        </div>
    </div>

    <!-- EDIT USER MODAL -->
    <div id="editUserModal" class="fixed inset-0 bg-black bg-opacity-50 hidden items-center justify-center z-50 px-4">
        <div class="bg-white rounded-xl shadow-2xl w-full max-w-md p-6">
            <div class="flex justify-between items-center mb-4 border-b pb-3">
                <h3 class="text-lg font-bold text-gray-800">Chỉnh Sửa Người Dùng</h3>
                <button onclick="closeEditModal()" class="text-gray-400 hover:text-gray-600 text-xl font-bold">&times;</button>
            </div>
            <form method="POST" class="space-y-4">
                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($csrfToken) ?>">
                <input type="hidden" name="action" value="edit_user">
                <input type="hidden" name="user_id" id="edit_user_id">
                <div>
                    <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Họ Tên</label>
                    <input type="text" name="full_name" id="edit_full_name" required class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Email</label>
                    <input type="email" name="email" id="edit_email" required class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                </div>
                <div>
                        <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Giới Tính</label>
                        <select name="gender" id="edit_gender" class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                            <option value="male">Male</option>
                            <option value="female">Female</option>
                            <option value="other">Other</option>
                        </select>
                </div>
                <div class="flex justify-end gap-2 pt-3 border-t">
                    <button type="button" onclick="closeEditModal()" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg text-sm font-semibold hover:bg-gray-300">Hủy thẻ chỉnh sửa</button>
                    <button type="submit" class="px-4 py-2 bg-yellow-500 text-white rounded-lg text-sm font-semibold hover:bg-yellow-600">Lưu Thay Đổi</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        function toggleSidebar() {
            const sidebar = document.getElementById('sidebar');
            const backdrop = document.getElementById('sidebarBackdrop');
            sidebar.classList.toggle('-translate-x-full');
            backdrop.classList.toggle('hidden');
        }
        function openAddModal() {
            const modal = document.getElementById('addUserModal');
            modal.classList.remove('hidden');
            modal.style.display = 'flex';
        }
        function closeAddModal() {
            const modal = document.getElementById('addUserModal');
            modal.style.display = 'none';
            modal.classList.add('hidden');
        }
        function openEditModal(user) {
            document.getElementById('edit_user_id').value = user.id;
            document.getElementById('edit_full_name').value = user.full_name || '';
            document.getElementById('edit_email').value = user.email || '';
            document.getElementById('edit_gender').value = user.gender || 'other';

            const modal = document.getElementById('editUserModal');
            modal.classList.remove('hidden');
            modal.style.display = 'flex';
        }
        function closeEditModal() {
            const modal = document.getElementById('editUserModal');
            modal.style.display = 'none';
            modal.classList.add('hidden');
        }
    </script>
<?php endif; ?>

</body>
</html>
