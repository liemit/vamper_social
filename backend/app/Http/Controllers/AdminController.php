<?php
require_once __DIR__ . '/../../config/database.php';

class AdminController {
    private function getDb() {
        $database = new Database();
        return $database->getConnection();
    }

    public function showLoginForm($error = '') {
        $errorHtml = $error ? "<p style='color: red; text-align: center;'>$error</p>" : "";
        echo '
        <!DOCTYPE html>
        <html>
        <head>
            <title>Vamper Admin Login</title>
            <style>
                body { font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background: #f4f4f4; margin: 0; }
                .login-box { background: white; padding: 2.5rem; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); width: 350px; }
                h2 { text-align: center; color: #333; margin-bottom: 1.5rem; }
                input { width: 100%; padding: 12px; margin: 10px 0; border: 1px solid #ddd; border-radius: 8px; box-sizing: border-box; font-size: 14px; }
                button { width: 100%; padding: 12px; background: #ff4b4b; color: white; border: none; border-radius: 8px; cursor: pointer; font-size: 16px; font-weight: bold; margin-top: 10px; }
                button:hover { background: #e03e3e; }
            </style>
        </head>
        <body>
            <div class="login-box">
                <h2>❤️ Vamper Admin</h2>
                ' . $errorHtml . '
                <form method="POST" action="login">
                    <input type="email" name="email" placeholder="Admin Email" required>
                    <input type="password" name="password" placeholder="Password" required>
                    <button type="submit">Login</button>
                </form>
            </div>
        </body>
        </html>';
    }

    public function login($data) {
        session_start();
        $email = $data['email'] ?? '';
        $password = $data['password'] ?? '';

        if (empty($email) || empty($password)) {
            $this->showLoginForm("Please fill in all fields.");
            return;
        }

        try {
            $db = $this->getDb();
            $stmt = $db->prepare("SELECT id, full_name, email, password, role, is_active FROM users WHERE email = :email LIMIT 1");
            $stmt->bindParam(":email", $email);
            $stmt->execute();

            if ($stmt->rowCount() > 0) {
                $user = $stmt->fetch(PDO::FETCH_ASSOC);

                // Check if user is admin and password matches
                if ($user['role'] === 'admin' && password_verify($password, $user['password'])) {
                    if ($user['is_active'] == 0) {
                        $this->showLoginForm("This admin account has been deactivated.");
                        return;
                    }

                    $_SESSION['admin_logged_in'] = true;
                    $_SESSION['admin_id'] = $user['id'];
                    $_SESSION['admin_name'] = $user['full_name'];

                    header('Location: dashboard');
                    exit;
                } else {
                    $this->showLoginForm("Invalid credentials or insufficient permissions.");
                }
            } else {
                $this->showLoginForm("Admin account not found.");
            }
        } catch (PDOException $e) {
            $this->showLoginForm("Database error: " . $e->getMessage());
        }
    }

    public function logout() {
        session_start();
        session_destroy();
        header('Location: login');
        exit;
    }

    private function checkAuth() {
        session_start();
        if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
            header('Location: login');
            exit;
        }
    }

    public function dashboard() {
        $this->checkAuth();

        $db = $this->getDb();

        // Handle actions (Toggle status or update coins)
        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            $action = $_POST['action'] ?? '';
            $userId = $_POST['user_id'] ?? null;

            if ($action === 'toggle_status' && $userId) {
                $stmt = $db->prepare("UPDATE users SET is_active = IF(is_active = 1, 0, 1) WHERE id = :id");
                $stmt->bindParam(':id', $userId);
                $stmt->execute();
            } elseif ($action === 'update_coins' && $userId) {
                $coins = intval($_POST['coins'] ?? 0);
                $stmt = $db->prepare("UPDATE users SET coins = :coins WHERE id = :id");
                $stmt->bindParam(':coins', $coins);
                $stmt->bindParam(':id', $userId);
                $stmt->execute();
            }
            header('Location: dashboard');
            exit;
        }

        // Fetch statistics
        $statsStmt = $db->prepare("SELECT
            (SELECT COUNT(*) FROM users) as total_users,
            (SELECT COUNT(*) FROM posts) as total_posts,
            (SELECT COUNT(*) FROM users WHERE is_active = 0) as banned_users,
            (SELECT COUNT(*) FROM users WHERE role = 'admin') as total_admins");
        $statsStmt->execute();
        $stats = $statsStmt->fetch(PDO::FETCH_ASSOC);

        // Fetch users list
        $usersStmt = $db->prepare("SELECT id, full_name, email, role, gender, coins, is_active, created_at FROM users ORDER BY created_at DESC");
        $usersStmt->execute();
        $users = $usersStmt->fetchAll(PDO::FETCH_ASSOC);

        $adminName = $_SESSION['admin_name'] ?? 'Admin';

        echo '
        <!DOCTYPE html>
        <html>
        <head>
            <title>Vamper Admin Dashboard</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 0; display: flex; background: #f8f9fa; }
                .sidebar { width: 240px; background: #212529; color: white; height: 100vh; padding: 1.5rem 1rem; position: fixed; }
                .sidebar h2 { color: #ff4b4b; font-size: 20px; margin-bottom: 2rem; text-align: center; }
                .sidebar a { display: block; color: #adb5bd; text-decoration: none; padding: 10px 15px; border-radius: 6px; margin-bottom: 5px; transition: 0.2s; }
                .sidebar a:hover, .sidebar a.active { background: #343a40; color: white; }
                .sidebar a.logout { color: #ff6b6b; margin-top: 2rem; }
                .content { margin-left: 260px; flex: 1; padding: 2rem; }
                .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem; }
                .stats-container { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
                .stat-card { background: white; padding: 1.5rem; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); border-left: 4px solid #ff4b4b; }
                .stat-card h3 { margin: 0 0 10px 0; color: #6c757d; font-size: 14px; }
                .stat-card p { margin: 0; font-size: 24px; font-weight: bold; color: #212529; }
                .table-container { background: white; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); overflow: hidden; }
                table { width: 100%; border-collapse: collapse; text-align: left; }
                th, td { padding: 12px 16px; border-bottom: 1px solid #dee2e6; font-size: 14px; }
                th { background: #f1f3f5; color: #495057; font-weight: bold; }
                .badge { padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
                .badge.active { background: #d4edda; color: #155724; }
                .badge.banned { background: #f8d7da; color: #721c24; }
                .badge.admin { background: #cce5ff; color: #004085; }
                .btn { padding: 6px 12px; border: none; border-radius: 4px; cursor: pointer; font-size: 12px; font-weight: bold; }
                .btn-danger { background: #dc3545; color: white; }
                .btn-success { background: #28a745; color: white; }
                .btn-primary { background: #007bff; color: white; }
                form.inline { display: inline; }
                input[type="number"] { width: 60px; padding: 4px; }
            </style>
        </head>
        <body>
            <div class="sidebar">
                <h2>❤️ Vamper Admin</h2>
                <a href="dashboard" class="active">📊 Dashboard</a>
                <a href="logout" class="logout">🚪 Logout</a>
            </div>
            <div class="content">
                <div class="header">
                    <h1>Welcome, ' . htmlspecialchars($adminName) . '</h1>
                    <span>' . date('d/m/Y H:i') . '</span>
                </div>

                <div class="stats-container">
                    <div class="stat-card">
                        <h3>Total Users</h3>
                        <p>' . $stats['total_users'] . '</p>
                    </div>
                    <div class="stat-card">
                        <h3>Total Posts</h3>
                        <p>' . $stats['total_posts'] . '</p>
                    </div>
                    <div class="stat-card">
                        <h3>Banned Users</h3>
                        <p>' . $stats['banned_users'] . '</p>
                    </div>
                    <div class="stat-card">
                        <h3>Admins</h3>
                        <p>' . $stats['total_admins'] . '</p>
                    </div>
                </div>

                <div class="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Name</th>
                                <th>Email</th>
                                <th>Role</th>
                                <th>Gender</th>
                                <th>Coins</th>
                                <th>Status</th>
                                <th>Joined</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>';

        foreach ($users as $u) {
            $statusBadge = $u['is_active'] == 1
                ? '<span class="badge active">Active</span>'
                : '<span class="badge banned">Banned</span>';
            $roleBadge = $u['role'] === 'admin'
                ? '<span class="badge admin">Admin</span>'
                : 'User';
            $toggleBtnText = $u['is_active'] == 1 ? 'Ban' : 'Unban';
            $toggleBtnClass = $u['is_active'] == 1 ? 'btn-danger' : 'btn-success';

            echo '<tr>
                <td>#' . $u['id'] . '</td>
                <td><strong>' . htmlspecialchars($u['full_name'] ?? '') . '</strong></td>
                <td>' . htmlspecialchars($u['email']) . '</td>
                <td>' . $roleBadge . '</td>
                <td>' . htmlspecialchars($u['gender'] ?? '-') . '</td>
                <td>
                    <form method="POST" class="inline">
                        <input type="hidden" name="action" value="update_coins">
                        <input type="hidden" name="user_id" value="' . $u['id'] . '">
                        <input type="number" name="coins" value="' . intval($u['coins']) . '">
                        <button type="submit" class="btn btn-primary">Save</button>
                    </form>
                </td>
                <td>' . $statusBadge . '</td>
                <td>' . substr($u['created_at'], 0, 10) . '</td>
                <td>
                    <form method="POST" class="inline" onsubmit="return confirm(\'Are you sure?\');">
                        <input type="hidden" name="action" value="toggle_status">
                        <input type="hidden" name="user_id" value="' . $u['id'] . '">
                        <button type="submit" class="btn ' . $toggleBtnClass . '">' . $toggleBtnText . '</button>
                    </form>
                </td>
            </tr>';
        }

        echo '          </tbody>
                    </table>
                </div>
            </div>
        </body>
        </html>';
    }
}
?>
