<?php

function adminTableExists(PDO $db, string $table): bool
{
    $stmt = $db->prepare(
        'SELECT 1 FROM information_schema.tables
         WHERE table_schema = DATABASE() AND table_name = :table_name LIMIT 1'
    );
    $stmt->execute([':table_name' => $table]);
    return (bool)$stmt->fetchColumn();
}

function adminColumnExists(PDO $db, string $table, string $column): bool
{
    $stmt = $db->prepare(
        'SELECT 1 FROM information_schema.columns
         WHERE table_schema = DATABASE() AND table_name = :table_name
           AND column_name = :column_name LIMIT 1'
    );
    $stmt->execute([':table_name' => $table, ':column_name' => $column]);
    return (bool)$stmt->fetchColumn();
}

function ensureAdminToolsSchema(PDO $db): void
{
    if (!adminTableExists($db, 'reports')) {
        $db->exec("CREATE TABLE IF NOT EXISTS reports (
        id INT AUTO_INCREMENT PRIMARY KEY,
        reporter_id INT NOT NULL,
        target_type VARCHAR(50) DEFAULT 'post',
        target_id INT NOT NULL,
        reason VARCHAR(255) NOT NULL,
        description TEXT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    }
    if (!adminTableExists($db, 'shop_items')) {
        $db->exec("CREATE TABLE IF NOT EXISTS shop_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        type ENUM('avatar','profile_frame','party_frame') NOT NULL,
        image_url VARCHAR(255) NOT NULL,
        price_coins INT NOT NULL DEFAULT 100,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    }
    ensureAdminAuthorizationSchema($db);
    ensureAdminAuditTable($db);
    ensureVpcLedgerTable($db);

    ensureShopActiveColumn($db);

    foreach ([
        'reviewed_by' => 'INT NULL',
        'reviewed_at' => 'TIMESTAMP NULL',
        'review_note' => 'VARCHAR(500) NULL',
    ] as $name => $definition) {
        if (!adminColumnExists($db, 'reports', $name)) {
            $db->exec("ALTER TABLE reports ADD COLUMN `$name` $definition");
        }
    }
}

function ensureAdminAuthorizationSchema(PDO $db): void
{
    if (!adminTableExists($db, 'admin_accounts')) {
        $db->exec("CREATE TABLE IF NOT EXISTS admin_accounts (
        user_id INT NOT NULL PRIMARY KEY,
        admin_role ENUM('super_admin','moderator','finance','support') NOT NULL DEFAULT 'support',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    }
    $accountCount = (int)$db->query('SELECT COUNT(*) FROM admin_accounts')->fetchColumn();
    if ($accountCount === 0) {
        $db->exec("INSERT IGNORE INTO admin_accounts (user_id, admin_role)
            SELECT id, 'super_admin' FROM users WHERE role = 'admin'");
    }
}

function ensureAdminAuditTable(PDO $db): void
{
    if (adminTableExists($db, 'admin_audit_log')) {
        return;
    }
    $db->exec("CREATE TABLE IF NOT EXISTS admin_audit_log (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        actor_id INT NULL,
        action VARCHAR(80) NOT NULL,
        entity_type VARCHAR(40) NOT NULL,
        entity_id VARCHAR(80) NULL,
        details_json JSON NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        KEY idx_admin_audit_created (created_at),
        KEY idx_admin_audit_actor (actor_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function ensureShopActiveColumn(PDO $db): void
{
    if (!adminColumnExists($db, 'shop_items', 'is_active')) {
        $db->exec("ALTER TABLE shop_items ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1");
    }
}

function ensureVpcLedgerTable(PDO $db): void
{
    if (adminTableExists($db, 'vpc_ledger')) {
        return;
    }
    $db->exec("CREATE TABLE IF NOT EXISTS vpc_ledger (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        amount_delta BIGINT NOT NULL,
        balance_before BIGINT NOT NULL,
        balance_after BIGINT NOT NULL,
        source_type VARCHAR(40) NOT NULL,
        source_id VARCHAR(100) NULL,
        reason VARCHAR(500) NOT NULL,
        actor_id INT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        KEY idx_vpc_ledger_user (user_id, created_at),
        KEY idx_vpc_ledger_source (source_type, source_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function recordVpcLedger(
    PDO $db,
    int $userId,
    int $delta,
    int $before,
    int $after,
    string $source,
    string $reason,
    ?string $sourceId = null,
    ?int $actorId = null
): void {
    $stmt = $db->prepare(
        'INSERT INTO vpc_ledger
            (user_id, amount_delta, balance_before, balance_after, source_type, source_id, reason, actor_id)
         VALUES (:uid, :delta, :before, :after, :source, :source_id, :reason, :actor)'
    );
    $stmt->execute([
        ':uid' => $userId,
        ':delta' => $delta,
        ':before' => $before,
        ':after' => $after,
        ':source' => $source,
        ':source_id' => $sourceId,
        ':reason' => $reason,
        ':actor' => $actorId,
    ]);
}

function adminRolePermissions(string $role): array
{
    return match ($role) {
        'super_admin' => ['dashboard', 'users', 'reports', 'finance', 'shop', 'admins', 'audit'],
        'moderator' => ['dashboard', 'users', 'reports'],
        'finance' => ['dashboard', 'finance'],
        'support' => ['dashboard', 'users'],
        default => [],
    };
}

function adminHasPermission(string $role, string $permission): bool
{
    return in_array($permission, adminRolePermissions($role), true);
}

function assertAdminApiPermission(PDO $db, int $userId, string $permission): void
{
    $activeAdmin = $db->prepare("SELECT 1 FROM users WHERE id = :id AND role = 'admin' AND is_active = 1");
    $activeAdmin->execute([':id' => $userId]);
    if (!$activeAdmin->fetchColumn()) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Administrator permission required.']);
        exit;
    }
    ensureAdminAuthorizationSchema($db);
    ensureAdminAuditTable($db);
    $stmt = $db->prepare(
        "SELECT a.admin_role FROM users u
         INNER JOIN admin_accounts a ON a.user_id = u.id
         WHERE u.id = :id AND u.role = 'admin' AND u.is_active = 1"
    );
    $stmt->execute([':id' => $userId]);
    $role = $stmt->fetchColumn();
    if ($role === false || !adminHasPermission((string)$role, $permission)) {
        http_response_code(403);
        echo json_encode(['success' => false, 'message' => 'Administrator permission required.']);
        exit;
    }
}

function writeAdminAudit(
    PDO $db,
    ?int $actorId,
    string $action,
    string $entityType,
    string|int|null $entityId,
    array $details = []
): void {
    $stmt = $db->prepare(
        'INSERT INTO admin_audit_log (actor_id, action, entity_type, entity_id, details_json)
         VALUES (:actor, :action, :entity, :entity_id, :details)'
    );
    $stmt->execute([
        ':actor' => $actorId,
        ':action' => $action,
        ':entity' => $entityType,
        ':entity_id' => $entityId === null ? null : (string)$entityId,
        ':details' => json_encode($details, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
    ]);
}
