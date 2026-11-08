<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/../libs/AdminTools.php';
require_once __DIR__ . '/libs/ApiAuth.php';

$database = new Database();
$db = $database->getConnection();
$hostId = authenticateApiUser($db);
$data = json_decode(file_get_contents("php://input"));
$title = trim((string)($data->title ?? ''));
$theme = trim((string)($data->theme ?? 'General'));
$isPrivate = !empty($data->is_private);
$password = trim((string)($data->password ?? ''));

if ($title === '' || mb_strlen($title) > 255) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "A party title of at most 255 characters is required."]);
    exit();
}

if ($isPrivate && ($password === '' || strlen($password) > 72)) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Private room passwords must contain 1 to 72 bytes."]);
    exit();
}

try {
    ensureVpcLedgerTable($db);

    foreach ([
        'is_private' => "TINYINT(1) DEFAULT 0",
        'password' => "VARCHAR(255) NULL",
    ] as $column => $definition) {
        $check = $db->query("SHOW COLUMNS FROM parties LIKE " . $db->quote($column));
        if ($check->rowCount() === 0) {
            $db->exec("ALTER TABLE parties ADD COLUMN `$column` $definition");
        }
    }
    $passwordColumn = $db->query("SHOW COLUMNS FROM parties LIKE 'password'")->fetch(PDO::FETCH_ASSOC);
    if ($passwordColumn && preg_match('/^varchar\\((\\d+)\\)$/i', $passwordColumn['Type'], $matches) && (int)$matches[1] < 255) {
        $db->exec('ALTER TABLE parties MODIFY COLUMN password VARCHAR(255) NULL');
    }

    $db->exec("CREATE TABLE IF NOT EXISTS party_creation_stats (
        user_id INT NOT NULL PRIMARY KEY,
        created_count INT UNSIGNED NOT NULL DEFAULT 0,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    $db->exec('INSERT IGNORE INTO party_creation_stats (user_id, created_count)
        SELECT host_id, COUNT(*) FROM parties GROUP BY host_id');

    $db->beginTransaction();
    $balanceQuery = $db->prepare('SELECT coins FROM users WHERE id = :user_id FOR UPDATE');
    $balanceQuery->execute([':user_id' => $hostId]);
    $balanceBefore = $balanceQuery->fetchColumn();
    if ($balanceBefore === false) {
        throw new RuntimeException('User account was not found.');
    }

    $createStats = $db->prepare('INSERT IGNORE INTO party_creation_stats (user_id, created_count) VALUES (:user_id, 0)');
    $createStats->execute([':user_id' => $hostId]);
    $countQuery = $db->prepare('SELECT created_count FROM party_creation_stats WHERE user_id = :user_id FOR UPDATE');
    $countQuery->execute([':user_id' => $hostId]);
    $createdCount = (int)$countQuery->fetchColumn();
    $creationFee = $createdCount >= 3 ? 200 : 0;
    $balanceBefore = (int)$balanceBefore;

    if ($creationFee > 0 && $balanceBefore < $creationFee) {
        $db->rollBack();
        http_response_code(402);
        echo json_encode([
            'success' => false,
            'message' => 'You need 200 VPC to create a party after your 3 free rooms.',
            'required_coins' => 200,
            'balance' => $balanceBefore,
            'free_rooms_used' => 3,
        ]);
        exit();
    }

    if ($creationFee > 0) {
        $deduct = $db->prepare('UPDATE users SET coins = coins - :fee WHERE id = :user_id AND coins >= :minimum');
        $deduct->execute([
            ':fee' => $creationFee,
            ':user_id' => $hostId,
            ':minimum' => $creationFee,
        ]);
        if ($deduct->rowCount() !== 1) {
            throw new RuntimeException('Unable to charge the party creation fee.');
        }
    }

    $stmt = $db->prepare(
        "INSERT INTO parties (host_id, title, theme, is_private, password, participants_count, is_live, created_at)
         VALUES (:host_id, :title, :theme, :is_private, :password, 1, 1, NOW())"
    );
    $stmt->execute([
        ':host_id' => $hostId,
        ':title' => $title,
        ':theme' => $theme,
        ':is_private' => $isPrivate ? 1 : 0,
        ':password' => $isPrivate ? password_hash($password, PASSWORD_DEFAULT) : null,
    ]);
    $partyId = (int)$db->lastInsertId();

    $incrementStats = $db->prepare('UPDATE party_creation_stats SET created_count = created_count + 1 WHERE user_id = :user_id');
    $incrementStats->execute([':user_id' => $hostId]);

    $balanceAfter = $balanceBefore - $creationFee;
    if ($creationFee > 0) {
        recordVpcLedger(
            $db,
            $hostId,
            -$creationFee,
            $balanceBefore,
            $balanceAfter,
            'party_creation',
            'Party room creation after three free rooms',
            (string)$partyId,
            $hostId
        );
    }

    $db->commit();

    http_response_code(200);
    echo json_encode([
        "success" => true,
        "message" => "Party room created successfully!",
        "data" => [
            "party_id" => $partyId,
            "created_count" => $createdCount + 1,
            "creation_fee" => $creationFee,
            "coins" => $balanceAfter,
        ],
    ]);
} catch (Throwable $error) {
    if ($db->inTransaction()) {
        $db->rollBack();
    }
    error_log('Unable to create party: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Unable to create the party room."]);
}
?>
