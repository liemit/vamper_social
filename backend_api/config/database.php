<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

class Database {
    private $host = "localhost";
    private $db_name = "vamper_social";
    private $username = "root";
    private $password = "";
    public $conn;

    public function getConnection() {
        $this->conn = null;
        $host = getenv("VAMPER_DB_HOST") ?: $this->host;
        $dbName = getenv("VAMPER_DB_NAME") ?: $this->db_name;
        $username = getenv("VAMPER_DB_USER") ?: $this->username;
        $password = getenv("VAMPER_DB_PASSWORD") ?: $this->password;

        try {
            $this->conn = new PDO(
                "mysql:host=" . $host . ";dbname=" . $dbName . ";charset=utf8mb4",
                $username,
                $password,
                [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
            );
            $this->conn->exec("set names utf8mb4");
            $this->conn->exec("SET time_zone = '+07:00'"); // ⚠️ Bắt buộc: Múi giờ Việt Nam - đồng bộ PHP / MySQL 100%
        } catch(PDOException $exception) {
            error_log("Database connection error: " . $exception->getMessage());
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Database service is unavailable."
            ]);
            exit();
        }

        return $this->conn;
    }
}
?>
