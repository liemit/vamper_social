<?php
session_start();

// Database configuration
$host = "localhost";
$db_name = "vamper_social";
$username = "root";
$password = "";

try {
    $db = new PDO("mysql:host=$host;dbname=$db_name;charset=utf8mb4", $username, $password);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Database Connection Error: " . $e->getMessage());
}

$tab = $_GET['tab'] ?? 'users';
$search = trim($_GET['search'] ?? '');
$page = max(1, intval($_GET['page'] ?? 1));
$limit = 10;
$offset = ($page - 1) * $limit;

// Posts pagination
$postPage = max(1, intval($_GET['post_page'] ?? 1));
$postLimit = 10;
$postOffset = ($postPage - 1) * $postLimit;

// Transactions pagination
$txPage = max(1, intval($_GET['tx_page'] ?? 1));
$txLimit = 10;
$txOffset = ($txPage - 1) * $txLimit;

$error = '';
$success = '';

// Handle Login POST
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['login'])) {
    $email = trim($_POST['email'] ?? '');
    $pass = $_POST['password'] ?? '';

    if (empty($email) || empty($pass)) {
        $error = "Vui lòng nhập đầy đủ email và mật khẩu.";
    } else {
        $stmt = $db->prepare("SELECT id, full_name, email, password, role, is_active FROM users WHERE email = :email LIMIT 1");
        $stmt->bindParam(':email', $email);
        $stmt->execute();

        if ($stmt->rowCount() > 0) {
            $user = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($user['role'] === 'admin' && password_verify($pass, $user['password'])) {
                if ($user['is_active'] == 0) {
                    $error = "Tài khoản admin này đã bị khóa.";
                } else {
                    $_SESSION['admin_logged_in'] = true;
                    $_SESSION['admin_id'] = $user['id'];
                    $_SESSION['admin_name'] = $user['full_name'];
                    header('Location: admin.php');
                    exit;
                }
            } else {
                $error = "Sai thông tin đăng nhập hoặc không có quyền admin.";
            }
        } else {
            $error = "Không tìm thấy tài khoản admin.";
        }
    }
}

// Handle Logout
if (isset($_GET['action']) && $_GET['action'] === 'logout') {
    session_destroy();
    header('Location: admin.php');
    exit;
}

// Check Authentication
$isAdminLoggedIn = isset($_SESSION['admin_logged_in']) && $_SESSION['admin_logged_in'] === true;

// Handle CRUD & Dashboard Actions
if ($isAdminLoggedIn && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $postAction = $_POST['action'] ?? '';

    if ($postAction === 'toggle_status') {
        $userId = $_POST['user_id'] ?? null;
        if ($userId) {
            $stmt = $db->prepare("UPDATE users SET is_active = IF(is_active = 1, 0, 1) WHERE id = :id");
            $stmt->bindParam(':id', $userId);
            $stmt->execute();
            $success = "Đã cập nhật trạng thái tài khoản thành công!";
        }
    } elseif ($postAction === 'update_coins') {
        $userId = $_POST['user_id'] ?? null;
        $coins = intval($_POST['coins'] ?? 0);
        if ($userId) {
            $stmt = $db->prepare("UPDATE users SET coins = :coins WHERE id = :id");
            $stmt->bindParam(':coins', $coins);
            $stmt->bindParam(':id', $userId);
            $stmt->execute();
            $success = "Đã cập nhật số xu thành công!";
        }
    } elseif ($postAction === 'create_user') {
        $fullName = trim($_POST['full_name'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $pass = $_POST['password'] ?? '';
        $role = $_POST['role'] ?? 'user';
        $gender = $_POST['gender'] ?? 'other';
        $coins = intval($_POST['coins'] ?? 0);

        if (empty($fullName) || empty($email) || empty($pass)) {
            $error = "Vui lòng điền đầy đủ Họ tên, Email và Mật khẩu.";
        } else {
            $hashedPass = password_hash($pass, PASSWORD_DEFAULT);
            try {
                $stmt = $db->prepare("INSERT INTO users (full_name, email, password, role, gender, coins, is_active, created_at) VALUES (:name, :email, :pass, :role, :gender, :coins, 1, NOW())");
                $stmt->execute([
                    ':name' => $fullName,
                    ':email' => $email,
                    ':pass' => $hashedPass,
                    ':role' => $role,
                    ':gender' => $gender,
                    ':coins' => $coins
                ]);
                $success = "Đã thêm người dùng mới thành công!";
            } catch (PDOException $e) {
                $error = "Lỗi: Email này có thể đã tồn tại.";
            }
        }
    } elseif ($postAction === 'edit_user') {
        $userId = $_POST['user_id'] ?? null;
        $fullName = trim($_POST['full_name'] ?? '');
        $email = trim($_POST['email'] ?? '');
        $role = $_POST['role'] ?? 'user';
        $gender = $_POST['gender'] ?? 'other';

        if ($userId && !empty($fullName) && !empty($email)) {
            $stmt = $db->prepare("UPDATE users SET full_name = :name, email = :email, role = :role, gender = :gender WHERE id = :id");
            $stmt->execute([
                ':name' => $fullName,
                ':email' => $email,
                ':role' => $role,
                ':gender' => $gender,
                ':id' => $userId
            ]);
            $success = "Đã cập nhật thông tin người dùng thành công!";
        }
    } elseif ($postAction === 'delete_user') {
        $userId = $_POST['user_id'] ?? null;
        if ($userId) {
            $stmt = $db->prepare("DELETE FROM users WHERE id = :id");
            $stmt->bindParam(':id', $userId);
            $stmt->execute();
            $success = "Đã xóa người dùng thành công!";
        }
    } elseif ($postAction === 'delete_post') {
        $postId = $_POST['post_id'] ?? null;
        if ($postId) {
            $stmt = $db->prepare("DELETE FROM posts WHERE id = :id");
            $stmt->bindParam(':id', $postId);
            $stmt->execute();
            $success = "Đã xóa bài đăng thành công!";
        }
    } elseif ($postAction === 'delete_reported_post') {
        $postId = $_POST['post_id'] ?? null;
        $reportId = $_POST['report_id'] ?? null;
        if ($postId) {
            $stmt = $db->prepare("DELETE FROM posts WHERE id = :id");
            $stmt->bindParam(':id', $postId);
            $stmt->execute();
        }
        if ($reportId) {
            $stmt = $db->prepare("UPDATE reports SET status = 'resolved' WHERE id = :id");
            $stmt->bindParam(':id', $reportId);
            $stmt->execute();
        }
        $success = "Đã xóa bài đăng vi phạm và giải quyết tố cáo!";
    } elseif ($postAction === 'dismiss_report') {
        $reportId = $_POST['report_id'] ?? null;
        if ($reportId) {
            $stmt = $db->prepare("UPDATE reports SET status = 'dismissed' WHERE id = :id");
            $stmt->bindParam(':id', $reportId);
            $stmt->execute();
            $success = "Đã bỏ qua tố cáo này!";
        }
    } elseif ($postAction === 'save_settings') {
        $paypalEmail = trim($_POST['paypal_email'] ?? '');
        $paypalMode = $_POST['paypal_mode'] ?? 'sandbox';

        $upsert = $db->prepare("INSERT INTO settings (`key`, `value`) VALUES (:k, :v) ON DUPLICATE KEY UPDATE `value` = :v");
        $upsert->execute([':k' => 'paypal_email', ':v' => $paypalEmail]);
        $upsert->execute([':k' => 'paypal_mode', ':v' => $paypalMode]);

        $success = "Đã lưu cài đặt ví PayPal thành công!";
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
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-pink-500 to-red-600">
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
    // Ensure tables exist
    try {
        $db->exec("CREATE TABLE IF NOT EXISTS reports (
            id INT AUTO_INCREMENT PRIMARY KEY,
            reporter_id INT NOT NULL,
            target_type VARCHAR(50) DEFAULT 'post',
            target_id INT NOT NULL,
            reason VARCHAR(255) NOT NULL,
            description TEXT NULL,
            status VARCHAR(50) DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

        $db->exec("CREATE TABLE IF NOT EXISTS settings (
            `key` VARCHAR(255) PRIMARY KEY,
            `value` TEXT NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");

        $db->exec("CREATE TABLE IF NOT EXISTS transactions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            amount_usd DECIMAL(10,2) NOT NULL,
            coins INT NOT NULL,
            gateway VARCHAR(50) DEFAULT 'PayPal',
            status VARCHAR(50) DEFAULT 'completed',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");
    } catch (Exception $e) {}

    // Fetch stats
    $statsStmt = $db->query("SELECT
        (SELECT COUNT(*) FROM users) as total_users,
        (SELECT COUNT(*) FROM posts) as total_posts,
        (SELECT COUNT(*) FROM users WHERE is_active = 0) as banned_users,
        (SELECT COUNT(*) FROM users WHERE role = 'admin') as total_admins,
        (SELECT COUNT(*) FROM reports WHERE status = 'pending') as pending_reports,
        (SELECT COALESCE(SUM(amount_usd), 0) FROM transactions WHERE status = 'completed') as total_revenue,
        (SELECT COALESCE(SUM(coins), 0) FROM transactions WHERE status = 'completed') as total_coins_sold,
        (SELECT COUNT(*) FROM transactions WHERE status = 'completed') as total_transactions");
    $stats = $statsStmt->fetch(PDO::FETCH_ASSOC);

    // Fetch settings
    $settingsStmt = $db->query("SELECT * FROM settings");
    $settingsMap = [];
    while ($row = $settingsStmt->fetch(PDO::FETCH_ASSOC)) {
        $settingsMap[$row['key']] = $row['value'];
    }
    $paypalEmail = $settingsMap['paypal_email'] ?? 'admin@vamper.com';
    $paypalMode = $settingsMap['paypal_mode'] ?? 'sandbox';

    // Pagination & Users Query
    if ($search) {
        $countStmt = $db->prepare("SELECT COUNT(*) FROM users WHERE full_name LIKE :s OR email LIKE :s");
        $like = "%$search%";
        $countStmt->bindParam(':s', $like);
        $countStmt->execute();
        $totalUsers = $countStmt->fetchColumn();

        $stmtUsers = $db->prepare("SELECT id, full_name, email, role, gender, coins, is_active, created_at FROM users WHERE full_name LIKE :s OR email LIKE :s ORDER BY created_at DESC LIMIT :limit OFFSET :offset");
        $stmtUsers->bindValue(':s', $like, PDO::PARAM_STR);
        $stmtUsers->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmtUsers->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmtUsers->execute();
    } else {
        $totalUsers = $db->query("SELECT COUNT(*) FROM users")->fetchColumn();

        $stmtUsers = $db->prepare("SELECT id, full_name, email, role, gender, coins, is_active, created_at FROM users ORDER BY created_at DESC LIMIT :limit OFFSET :offset");
        $stmtUsers->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmtUsers->bindValue(':offset', $offset, PDO::PARAM_INT);
        $stmtUsers->execute();
    }
    $users = $stmtUsers->fetchAll(PDO::FETCH_ASSOC);
    $totalPages = max(1, ceil($totalUsers / $limit));

    // Fetch posts for moderation with pagination
    $totalPosts = $db->query("SELECT COUNT(*) FROM posts")->fetchColumn();
    $totalPostPages = max(1, ceil($totalPosts / $postLimit));

    $postsStmt = $db->prepare("SELECT p.id, p.content, p.image_url, p.created_at, u.full_name, u.email FROM posts p JOIN users u ON p.user_id = u.id ORDER BY p.created_at DESC LIMIT :limit OFFSET :offset");
    $postsStmt->bindValue(':limit', $postLimit, PDO::PARAM_INT);
    $postsStmt->bindValue(':offset', $postOffset, PDO::PARAM_INT);
    $postsStmt->execute();
    $posts = $postsStmt->fetchAll(PDO::FETCH_ASSOC);

    // Fetch reports
    $reportsStmt = $db->query("SELECT r.*, u.full_name as reporter_name, u.email as reporter_email, p.content as post_content, author.full_name as author_name
                               FROM reports r
                               JOIN users u ON r.reporter_id = u.id
                               LEFT JOIN posts p ON r.target_id = p.id AND r.target_type = 'post'
                               LEFT JOIN users author ON p.user_id = author.id
                               ORDER BY r.created_at DESC");
    $reports = $reportsStmt->fetchAll(PDO::FETCH_ASSOC);

    // Fetch transactions with pagination
    $totalTx = $db->query("SELECT COUNT(*) FROM transactions")->fetchColumn();
    $totalTxPages = max(1, ceil($totalTx / $txLimit));

    $txStmt = $db->prepare("SELECT t.*, u.full_name, u.email FROM transactions t JOIN users u ON t.user_id = u.id ORDER BY t.created_at DESC LIMIT :limit OFFSET :offset");
    $txStmt->bindValue(':limit', $txLimit, PDO::PARAM_INT);
    $txStmt->bindValue(':offset', $txOffset, PDO::PARAM_INT);
    $txStmt->execute();
    $transactions = $txStmt->fetchAll(PDO::FETCH_ASSOC);
?>
    <!-- DASHBOARD LAYOUT -->
    <div class="flex h-screen overflow-hidden">
        <!-- Sidebar -->
        <div class="w-64 bg-gray-900 text-white flex flex-col shadow-xl">
            <div class="p-5 text-center border-b border-gray-800">
                <h2 class="text-xl font-bold text-red-500 flex items-center justify-center gap-2">
                    <i class="fa-solid fa-fire"></i> Vamper Admin
                </h2>
                <span class="text-xs text-gray-400">Management Panel</span>
            </div>
            <nav class="flex-1 p-4 space-y-2">
                <a href="admin.php?tab=users" class="flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition <?= $tab === 'users' ? 'bg-red-500 text-white shadow-lg' : 'text-gray-400 hover:bg-gray-800 hover:text-white' ?>">
                    <i class="fa-solid fa-users w-5"></i> Quản Lý Người Dùng
                </a>
                <a href="admin.php?tab=posts" class="flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition <?= $tab === 'posts' ? 'bg-red-500 text-white shadow-lg' : 'text-gray-400 hover:bg-gray-800 hover:text-white' ?>">
                    <i class="fa-solid fa-newspaper w-5"></i> Kiểm Duyệt Bài Đăng
                </a>
                <a href="admin.php?tab=reports" class="flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition <?= $tab === 'reports' ? 'bg-red-500 text-white shadow-lg' : 'text-gray-400 hover:bg-gray-800 hover:text-white' ?>">
                    <i class="fa-solid fa-flag w-5"></i> Quản Lý Tố Cáo
                    <?php if (($stats['pending_reports'] ?? 0) > 0): ?>
                        <span class="ml-auto bg-red-600 text-white text-xs px-2 py-0.5 rounded-full"><?= $stats['pending_reports'] ?></span>
                    <?php endif; ?>
                </a>
                <a href="admin.php?tab=wallet" class="flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition <?= $tab === 'wallet' ? 'bg-red-500 text-white shadow-lg' : 'text-gray-400 hover:bg-gray-800 hover:text-white' ?>">
                    <i class="fa-solid fa-wallet w-5"></i> Ví & Giao Dịch
                </a>
            </nav>
            <div class="p-4 border-t border-gray-800">
                <a href="admin.php?action=logout" class="flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium text-red-400 hover:bg-red-500 hover:text-white transition">
                    <i class="fa-solid fa-right-from-bracket w-5"></i> Đăng Xuất
                </a>
            </div>
        </div>

        <!-- Main Content Area -->
        <div class="flex-1 flex flex-col overflow-y-auto">
            <!-- Top Header -->
            <header class="bg-white shadow-sm px-8 py-4 flex justify-between items-center sticky top-0 z-10">
                <div class="flex items-center gap-3">
                    <h1 class="text-xl font-bold text-gray-800">
                        <?= $tab === 'users' ? 'Quản Lý Người Dùng' : ($tab === 'posts' ? 'Kiểm Duyệt Bài Đăng' : ($tab === 'reports' ? 'Quản Lý Tố Cáo' : 'Ví & Giao Dịch Tài Chính')) ?>
                    </h1>
                </div>
                <div class="flex items-center gap-4">
                    <div class="text-right">
                        <p class="text-sm font-semibold text-gray-800"><?= htmlspecialchars($_SESSION['admin_name']) ?></p>
                        <p class="text-xs text-gray-500">Quản trị viên tối cao</p>
                    </div>
                    <div class="w-10 h-10 rounded-full bg-red-500 text-white flex items-center justify-center font-bold">
                        <?= strtoupper(substr($_SESSION['admin_name'], 0, 1)) ?>
                    </div>
                </div>
            </header>

            <!-- Content Body -->
            <main class="p-8">
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

                <?php if ($tab === 'users'): ?>
                    <!-- Stats Grid -->
                    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
                        <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                            <div>
                                <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tổng Người Dùng</p>
                                <h3 class="text-2xl font-bold text-gray-800 mt-1"><?= $stats['total_users'] ?></h3>
                            </div>
                            <div class="p-3 bg-blue-50 text-blue-500 rounded-xl text-xl"><i class="fa-solid fa-users"></i></div>
                        </div>
                        <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                            <div>
                                <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tổng Bài Đăng</p>
                                <h3 class="text-2xl font-bold text-gray-800 mt-1"><?= $stats['total_posts'] ?></h3>
                            </div>
                            <div class="p-3 bg-green-50 text-green-500 rounded-xl text-xl"><i class="fa-solid fa-newspaper"></i></div>
                        </div>
                        <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                            <div>
                                <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tố Cáo Chưa Xử Lý</p>
                                <h3 class="text-2xl font-bold text-red-600 mt-1"><?= $stats['pending_reports'] ?></h3>
                            </div>
                            <div class="p-3 bg-red-50 text-red-500 rounded-xl text-xl"><i class="fa-solid fa-flag"></i></div>
                        </div>
                        <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                            <div>
                                <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Quản Trị Viên</p>
                                <h3 class="text-2xl font-bold text-gray-800 mt-1"><?= $stats['total_admins'] ?></h3>
                            </div>
                            <div class="p-3 bg-purple-50 text-purple-500 rounded-xl text-xl"><i class="fa-solid fa-shield-halved"></i></div>
                        </div>
                    </div>

                    <!-- USERS TAB -->
                    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden mb-8">
                        <div class="p-6 border-b border-gray-100 flex flex-col md:flex-row justify-between items-center gap-4">
                            <div class="flex items-center gap-3 w-full md:w-auto">
                                <h3 class="text-lg font-bold text-gray-800">Danh Sách Người Dùng</h3>
                                <button onclick="openAddModal()" class="px-4 py-2 bg-red-500 text-white rounded-lg text-sm font-semibold hover:bg-red-600 transition flex items-center gap-2">
                                    <i class="fa-solid fa-user-plus"></i> Thêm Người Dùng
                                </button>
                            </div>
                            <form method="GET" class="flex gap-2 w-full md:w-auto">
                                <input type="hidden" name="tab" value="users">
                                <input type="text" name="search" value="<?= htmlspecialchars($search) ?>" placeholder="Tìm kiếm theo tên hoặc email..." class="px-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500 w-full md:w-80">
                                <button type="submit" class="px-4 py-2 bg-gray-800 text-white rounded-lg text-sm font-semibold hover:bg-gray-700 transition">Tìm</button>
                                <?php if ($search): ?>
                                    <a href="admin.php?tab=users" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg text-sm font-semibold hover:bg-gray-300 transition">Đặt lại</a>
                                <?php endif; ?>
                            </form>
                        </div>
                        <div class="overflow-x-auto">
                            <table class="w-full text-left border-collapse">
                                <thead>
                                    <tr class="bg-gray-50 text-gray-600 text-xs uppercase font-semibold tracking-wider">
                                        <th class="py-3 px-6">ID</th>
                                        <th class="py-3 px-6">Họ Tên</th>
                                        <th class="py-3 px-6">Email</th>
                                        <th class="py-3 px-6">Vai Trò</th>
                                        <th class="py-3 px-6">Giới Tính</th>
                                        <th class="py-3 px-6">Số Xu</th>
                                        <th class="py-3 px-6">Trạng Thái</th>
                                        <th class="py-3 px-6">Ngày Tạo</th>
                                        <th class="py-3 px-6 text-center">Thao Tác</th>
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
                                        <td class="py-4 px-6 text-gray-500">#<?= $u['id'] ?></td>
                                        <td class="py-4 px-6 font-semibold text-gray-800"><?= htmlspecialchars($u['full_name'] ?? '') ?></td>
                                        <td class="py-4 px-6 text-gray-600"><?= htmlspecialchars($u['email']) ?></td>
                                        <td class="py-4 px-6"><?= $roleBadge ?></td>
                                        <td class="py-4 px-6 text-gray-600"><?= htmlspecialchars($u['gender'] ?? '-') ?></td>
                                        <td class="py-4 px-6">
                                            <form method="POST" class="flex items-center gap-2">
                                                <input type="hidden" name="action" value="update_coins">
                                                <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                                                <input type="number" name="coins" value="<?= intval($u['coins']) ?>" class="w-20 px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:ring-1 focus:ring-red-500">
                                                <button type="submit" class="px-2.5 py-1 bg-blue-500 text-white rounded text-xs font-semibold hover:bg-blue-600 transition">Lưu</button>
                                            </form>
                                        </td>
                                        <td class="py-4 px-6"><?= $statusBadge ?></td>
                                        <td class="py-4 px-6 text-gray-500 text-xs"><?= substr($u['created_at'], 0, 10) ?></td>
                                        <td class="py-4 px-6 text-center space-x-1">
                                            <button onclick='openEditModal(<?= json_encode($u) ?>)' class="px-2.5 py-1.5 bg-yellow-500 text-white rounded text-xs font-semibold hover:bg-yellow-600 transition" title="Sửa">
                                                <i class="fa-solid fa-pen"></i>
                                            </button>
                                            <form method="POST" class="inline" onsubmit="return confirm('Bạn có chắc chắn muốn thay đổi trạng thái tài khoản này?');">
                                                <input type="hidden" name="action" value="toggle_status">
                                                <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                                                <button type="submit" class="px-2.5 py-1.5 text-white rounded text-xs font-semibold shadow-sm transition <?= $toggleClass ?>" title="<?= $toggleText ?>"><?= $toggleText ?></button>
                                            </form>
                                            <form method="POST" class="inline" onsubmit="return confirm('CẢNH BÁO: Bạn có chắc chắn muốn XÓA VĨNH VIỄN người dùng này?');">
                                                <input type="hidden" name="action" value="delete_user">
                                                <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                                                <button type="submit" class="px-2.5 py-1.5 bg-gray-700 text-white rounded text-xs font-semibold hover:bg-gray-800 transition" title="Xóa">
                                                    <i class="fa-solid fa-trash"></i>
                                                </button>
                                            </form>
                                        </td>
                                    </tr>
                                    <?php endforeach; endif; ?>
                                </tbody>
                            </table>
                        </div>

                        <!-- Pagination -->
                        <?php if ($totalPages > 1): ?>
                            <div class="p-6 border-t border-gray-100 flex justify-between items-center">
                                <span class="text-sm text-gray-500">Trang <?= $page ?> / <?= $totalPages ?> (Tổng <?= $totalUsers ?> người dùng)</span>
                                <div class="flex gap-1">
                                    <?php if ($page > 1): ?>
                                        <a href="admin.php?tab=users&page=<?= $page - 1 ?><?= $search ? '&search=' . urlencode($search) : '' ?>" class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300">Trước</a>
                                    <?php endif; ?>

                                    <?php for ($i = 1; $i <= $totalPages; $i++): ?>
                                        <a href="admin.php?tab=users&page=<?= $i ?><?= $search ? '&search=' . urlencode($search) : '' ?>" class="px-3 py-1.5 rounded text-sm font-semibold <?= $i === $page ? 'bg-red-500 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300' ?>"><?= $i ?></a>
                                    <?php endfor; ?>

                                    <?php if ($page < $totalPages): ?>
                                        <a href="admin.php?tab=users&page=<?= $page + 1 ?><?= $search ? '&search=' . urlencode($search) : '' ?>" class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300">Sau</a>
                                    <?php endif; ?>
                                </div>
                            </div>
                        <?php endif; ?>
                    </div>
                <?php elseif ($tab === 'posts'): ?>
                    <!-- POSTS MODERATION TAB -->
                    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                        <div class="p-6 border-b border-gray-100">
                            <h3 class="text-lg font-bold text-gray-800">Kiểm Duyệt Bài Đăng</h3>
                        </div>
                        <div class="overflow-x-auto">
                            <table class="w-full text-left border-collapse">
                                <thead>
                                    <tr class="bg-gray-50 text-gray-600 text-xs uppercase font-semibold tracking-wider">
                                        <th class="py-3 px-6">ID</th>
                                        <th class="py-3 px-6">Tác Giả</th>
                                        <th class="py-3 px-6">Nội Dung</th>
                                        <th class="py-3 px-6">Hình Ảnh</th>
                                        <th class="py-3 px-6">Ngày Đăng</th>
                                        <th class="py-3 px-6 text-center">Thao Tác</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-gray-200 text-sm">
                                    <?php if (empty($posts)): ?>
                                        <tr><td colspan="6" class="py-6 text-center text-gray-400">Không có bài đăng nào.</td></tr>
                                    <?php else: foreach ($posts as $p): ?>
                                    <tr class="hover:bg-gray-50 transition">
                                        <td class="py-4 px-6 text-gray-500">#<?= $p['id'] ?></td>
                                        <td class="py-4 px-6 font-semibold text-gray-800">
                                            <?= htmlspecialchars($p['full_name']) ?>
                                            <div class="text-xs text-gray-400 font-normal"><?= htmlspecialchars($p['email']) ?></div>
                                        </td>
                                        <td class="py-4 px-6 text-gray-700 max-w-xs truncate"><?= htmlspecialchars($p['content'] ?? '') ?></td>
                                        <td class="py-4 px-6">
                                            <?php if (!empty($p['image_url'])): ?>
                                                <a href="<?= htmlspecialchars($p['image_url']) ?>" target="_blank" class="text-blue-500 underline text-xs">Xem ảnh</a>
                                            <?php else: ?>
                                                <span class="text-gray-400 text-xs">Không có</span>
                                            <?php endif; ?>
                                        </td>
                                        <td class="py-4 px-6 text-gray-500 text-xs"><?= $p['created_at'] ?></td>
                                        <td class="py-4 px-6 text-center">
                                            <form method="POST" onsubmit="return confirm('Bạn có chắc chắn muốn xóa bài đăng này?');">
                                                <input type="hidden" name="action" value="delete_post">
                                                <input type="hidden" name="post_id" value="<?= $p['id'] ?>">
                                                <button type="submit" class="px-3 py-1.5 bg-red-500 text-white rounded text-xs font-semibold shadow-sm hover:bg-red-600 transition">Xóa Bài</button>
                                            </form>
                                        </td>
                                    </tr>
                                    <?php endforeach; endif; ?>
                                </tbody>
                            </table>
                        </div>

                        <!-- Posts Pagination -->
                        <?php if ($totalPostPages > 1): ?>
                            <div class="p-6 border-t border-gray-100 flex justify-between items-center">
                                <span class="text-sm text-gray-500">Trang <?= $postPage ?> / <?= $totalPostPages ?> (Tổng <?= $totalPosts ?> bài viết)</span>
                                <div class="flex gap-1">
                                    <?php if ($postPage > 1): ?>
                                        <a href="admin.php?tab=posts&post_page=<?= $postPage - 1 ?>" class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded text-sm hover:bg-gray-300">Trước</a>
                                    <?php endif; ?>

                                    <?php for ($i = 1; $i <= $totalPostPages; $i++): ?>
                                        <a href="admin.php?tab=posts&post_page=<?= $i ?>" class="px-3 py-1.5 rounded text-sm font-semibold <?= $i === $postPage ? 'bg-red-500 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300' ?>"><?= $i ?></a>
                                    <?php endfor; ?>

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
                        <div class="p-6 border-b border-gray-100">
                            <h3 class="text-lg font-bold text-gray-800">Quản Lý Tố Cáo (Reports)</h3>
                        </div>
                        <div class="overflow-x-auto">
                            <table class="w-full text-left border-collapse">
                                <thead>
                                    <tr class="bg-gray-50 text-gray-600 text-xs uppercase font-semibold tracking-wider">
                                        <th class="py-3 px-6">ID</th>
                                        <th class="py-3 px-6">Người Tố Cáo</th>
                                        <th class="py-3 px-6">Bài Viết Bị Tố Cáo</th>
                                        <th class="py-3 px-6">Lý Do</th>
                                        <th class="py-3 px-6">Mô Tả</th>
                                        <th class="py-3 px-6">Trạng Thái</th>
                                        <th class="py-3 px-6">Thời Gian</th>
                                        <th class="py-3 px-6 text-center">Thao Tác</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-gray-200 text-sm">
                                    <?php if (empty($reports)): ?>
                                        <tr><td colspan="8" class="py-6 text-center text-gray-400">Không có tố cáo nào.</td></tr>
                                    <?php else: foreach ($reports as $r):
                                        $statusBadge = $r['status'] === 'pending'
                                            ? '<span class="px-2.5 py-1 bg-yellow-100 text-yellow-800 rounded-full text-xs font-semibold">Pending</span>'
                                            : ($r['status'] === 'resolved' ? '<span class="px-2.5 py-1 bg-green-100 text-green-800 rounded-full text-xs font-semibold">Resolved</span>' : '<span class="px-2.5 py-1 bg-gray-100 text-gray-800 rounded-full text-xs font-semibold">Dismissed</span>');
                                    ?>
                                    <tr class="hover:bg-gray-50 transition">
                                        <td class="py-4 px-6 text-gray-500">#<?= $r['id'] ?></td>
                                        <td class="py-4 px-6 font-semibold text-gray-800">
                                            <?= htmlspecialchars($r['reporter_name']) ?>
                                            <div class="text-xs text-gray-400 font-normal"><?= htmlspecialchars($r['reporter_email']) ?></div>
                                        </td>
                                        <td class="py-4 px-6 text-gray-700 max-w-xs">
                                            <?php if ($r['post_content']): ?>
                                                <div class="font-semibold text-xs text-gray-500 mb-1">Tác giả: <?= htmlspecialchars($r['author_name'] ?? 'Unknown') ?></div>
                                                <div class="truncate"><?= htmlspecialchars($r['post_content']) ?></div>
                                            <?php else: ?>
                                                <span class="text-red-500 text-xs font-semibold">Bài viết đã bị xóa</span>
                                            <?php endif; ?>
                                        </td>
                                        <td class="py-4 px-6 font-semibold text-red-600"><?= htmlspecialchars($r['reason']) ?></td>
                                        <td class="py-4 px-6 text-gray-600 text-xs"><?= htmlspecialchars($r['description'] ?? '-') ?></td>
                                        <td class="py-4 px-6"><?= $statusBadge ?></td>
                                        <td class="py-4 px-6 text-gray-500 text-xs"><?= $r['created_at'] ?></td>
                                        <td class="py-4 px-6 text-center space-x-2">
                                            <?php if ($r['status'] === 'pending' && $r['post_content']): ?>
                                                <form method="POST" class="inline" onsubmit="return confirm('Xác nhận XÓA bài đăng vi phạm này?');">
                                                    <input type="hidden" name="action" value="delete_reported_post">
                                                    <input type="hidden" name="report_id" value="<?= $r['id'] ?>">
                                                    <input type="hidden" name="post_id" value="<?= $r['target_id'] ?>">
                                                    <button type="submit" class="px-3 py-1.5 bg-red-500 text-white rounded text-xs font-semibold hover:bg-red-600 transition">Xóa Bài Vi phạm</button>
                                                </form>
                                            <?php endif; ?>
                                            <?php if ($r['status'] === 'pending'): ?>
                                                <form method="POST" class="inline">
                                                    <input type="hidden" name="action" value="dismiss_report">
                                                    <input type="hidden" name="report_id" value="<?= $r['id'] ?>">
                                                    <button type="submit" class="px-3 py-1.5 bg-gray-500 text-white rounded text-xs font-semibold hover:bg-gray-600 transition">Bỏ Qua</button>
                                                </form>
                                            <?php endif; ?>
                                            <?php if ($r['status'] !== 'pending'): ?>
                                                <span class="text-xs text-gray-400 italic">Đã xử lý</span>
                                            <?php endif; ?>
                                        </td>
                                    </tr>
                                    <?php endforeach; endif; ?>
                                </tbody>
                            </table>
                        </div>
                    </div>
                <?php else: ?>
                    <!-- WALLET & TRANSACTIONS TAB -->
                    <div class="space-y-8">
                        <!-- Stats Grid -->
                        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                            <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                                <div>
                                    <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tổng Doanh Thu</p>
                                    <h3 class="text-2xl font-bold text-green-600 mt-1">$<?= number_format($stats['total_revenue'], 2) ?></h3>
                                </div>
                                <div class="p-3 bg-green-50 text-green-500 rounded-xl text-xl"><i class="fa-solid fa-dollar-sign"></i></div>
                            </div>
                            <div class="p-3 bg-amber-50 text-amber-500 rounded-xl text-xl"><i class="fa-solid fa-coins"></i></div>
                            <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                                <div>
                                    <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Tổng Số Xu Đã Bán</p>
                                    <h3 class="text-2xl font-bold text-amber-500 mt-1"><?= number_format($stats['total_coins_sold']) ?> Coins</h3>
                                </div>
                                <div class="p-3 bg-amber-50 text-amber-500 rounded-xl text-xl"><i class="fa-solid fa-coins"></i></div>
                            </div>
                            <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 flex items-center justify-between">
                                <div>
                                    <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">Giao Dịch Thành Công</p>
                                    <h3 class="text-2xl font-bold text-blue-600 mt-1"><?= number_format($stats['total_transactions']) ?></h3>
                                </div>
                                <div class="p-3 bg-blue-50 text-blue-500 rounded-xl text-xl"><i class="fa-solid fa-receipt"></i></div>
                            </div>
                        </div>

                        <!-- Admin Wallet Settings Form -->
                        <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                            <h3 class="text-lg font-bold text-gray-800 mb-4 flex items-center gap-2">
                                <i class="fa-solid fa-gear text-red-500"></i> Cài Đặt Ví Thanh Toán Admin (PayPal)
                            </h3>
                            <form method="POST" class="space-y-4 max-w-xl">
                                <input type="hidden" name="action" value="save_settings">
                                <div>
                                    <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Email Ví PayPal Business / Merchant</label>
                                    <input type="email" name="paypal_email" value="<?= htmlspecialchars($paypalEmail) ?>" required class="w-full px-4 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500">
                                </div>
                                <div>
                                    <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Môi Trường Thanh Toán</label>
                                    <select name="paypal_mode" class="w-full px-4 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500">
                                        <option value="sandbox" <?= $paypalMode === 'sandbox' ? 'selected' : '' ?>>Sandbox (Thử nghiệm)</option>
                                        <option value="live" <?= $paypalMode === 'live' ? 'selected' : '' ?>>Live (Thật - Quốc tế)</option>
                                    </select>
                                </div>
                                <button type="submit" class="px-6 py-2.5 bg-red-500 text-white rounded-lg text-sm font-semibold hover:bg-red-600 transition shadow-md">
                                    Lưu Cài Đặt Ví
                                </button>
                            </form>
                        </div>

                        <!-- Transaction Logs Table -->
                        <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                            <div class="p-6 border-b border-gray-100">
                                <h3 class="text-lg font-bold text-gray-800">Lịch Sử Giao Dịch Nạp Xu Của Người Chơi</h3>
                            </div>
                            <div class="overflow-x-auto">
                                <table class="w-full text-left border-collapse">
                                    <thead>
                                        <tr class="bg-gray-50 text-gray-600 text-xs uppercase font-semibold tracking-wider">
                                            <th class="py-3 px-6">ID Giao Dịch</th>
                                            <th class="py-3 px-6">Người Chơi</th>
                                            <th class="py-3 px-6">Số Tiền (USD)</th>
                                            <th class="py-3 px-6">Số Xu Nhận</th>
                                            <th class="py-3 px-6">Cổng Thanh Toán</th>
                                            <th class="py-3 px-6">Trạng Thái</th>
                                            <th class="py-3 px-6">Thời Gian</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-gray-200 text-sm">
                                        <?php if (empty($transactions)): ?>
                                            <tr><td colspan="7" class="py-6 text-center text-gray-400">Không có giao dịch nạp tiền nào.</td></tr>
                                        <?php else: foreach ($transactions as $tx): ?>
                                        <tr class="hover:bg-gray-50 transition">
                                            <td class="py-4 px-6 text-gray-500">#TX-<?= $tx['id'] ?></td>
                                            <td class="py-4 px-6 font-semibold text-gray-800">
                                                <?= htmlspecialchars($tx['full_name']) ?>
                                                <div class="text-xs text-gray-400 font-normal"><?= htmlspecialchars($tx['email']) ?></div>
                                            </td>
                                            <td class="py-4 px-6 font-bold text-green-600">$<?= number_format($tx['amount_usd'], 2) ?></td>
                                            <td class="py-4 px-6 font-bold text-amber-500">+<?= number_format($tx['coins']) ?> Coins</td>
                                            <td class="py-4 px-6 text-gray-700"><?= htmlspecialchars($tx['gateway']) ?></td>
                                            <td class="py-4 px-6"><span class="px-2.5 py-1 bg-green-100 text-green-800 rounded-full text-xs font-semibold"><?= htmlspecialchars($tx['status']) ?></span></td>
                                            <td class="py-4 px-6 text-gray-500 text-xs"><?= $tx['created_at'] ?></td>
                                        </tr>
                                        <?php endforeach; endif; ?>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                <?php endif; ?>
            </main>
        </div>
    </div>

    <!-- ADD USER MODAL -->
    <div id="addUserModal" class="fixed inset-0 bg-black bg-opacity-50 hidden items-center justify-center z-50">
        <div class="bg-white rounded-xl shadow-2xl w-full max-w-md p-6">
            <div class="flex justify-between items-center mb-4 border-b pb-3">
                <h3 class="text-lg font-bold text-gray-800">Thêm Người Dùng Mới</h3>
                <button onclick="closeAddModal()" class="text-gray-400 hover:text-gray-600 text-xl font-bold">&times;</button>
            </div>
            <form method="POST" class="space-y-4">
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
                            <option value="admin">Admin</option>
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
                    <input type="number" name="coins" value="100" class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                </div>
                <div class="flex justify-end gap-2 pt-3 border-t">
                    <button type="button" onclick="closeAddModal()" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg text-sm font-semibold hover:bg-gray-300">Hủy</button>
                    <button type="submit" class="px-4 py-2 bg-red-500 text-white rounded-lg text-sm font-semibold hover:bg-red-600">Thêm Mới</button>
                </div>
            </form>
        </div>
    </div>

    <!-- EDIT USER MODAL -->
    <div id="editUserModal" class="fixed inset-0 bg-black bg-opacity-50 hidden items-center justify-center z-50">
        <div class="bg-white rounded-xl shadow-2xl w-full max-w-md p-6">
            <div class="flex justify-between items-center mb-4 border-b pb-3">
                <h3 class="text-lg font-bold text-gray-800">Chỉnh Sửa Người Dùng</h3>
                <button onclick="closeEditModal()" class="text-gray-400 hover:text-gray-600 text-xl font-bold">&times;&#10005;</button>
            </div>
            <form method="POST" class="space-y-4">
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
                <div class="grid grid-cols-2 gap-4">
                    <div>
                        <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Vai Trò</label>
                        <select name="role" id="edit_role" class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                            <option value="user">User</option>
                            <option value="admin">Admin</option>
                        </select>
                    </div>
                    <div>
                        <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Giới Tính</label>
                        <select name="gender" id="edit_gender" class="w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:outline-none">
                            <option value="male">Male</option>
                            <option value="female">Female</option>
                            <option value="other">Other</option>
                        </select>
                    </div>
                </div>
                <div class="flex justify-end gap-2 pt-3 border-t">
                    <button type="button" onclick="closeEditModal()" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg text-sm font-semibold hover:bg-gray-300">Hủy</button>
                    <button type="submit" class="px-4 py-2 bg-yellow-500 text-white rounded-lg text-sm font-semibold hover:bg-yellow-600">Lưu Thay Đổi</button>
                </div>
            </form>
        </div>
    </div>

    <script>
        function openAddModal() {
            cout = 0; // cleanup
            document.getElementById('addUserModal').classList.remove('hidden');
            document.getElementById('addUserModel')?.classList.add('flex');
            document.getElementById('addUserModal').classList.add('flex');
        }
        function closeAddModal() {
            document.getElementById('addUserModal').classList.remove('flex');
            document.getElementById('addUserModal').classList.add('hidden');
        }
        function openEditModal(user) {
            document.getElementById('edit_user_id').value = user.id;
            document.getElementById('edit_full_name').value = user.full_name || '';
            document.getElementById('edit_email').value = user.email || '';
            document.getElementById('edit_role').value = user.role || 'user';
            document.getElementById('edit_gender').value = user.gender || 'other';

            document.getElementById('editUserModal').classList.remove('hidden');
            document.getElementById('editUserModal').classList.add('flex');
        }
        function closeEditModal() {
            document.getElementById('editUserModal').classList.remove('flex');
            document.getElementById('editUserModal').classList.add('hidden');
        }
    </script>
<?php endif; ?>

</body>
</html>
