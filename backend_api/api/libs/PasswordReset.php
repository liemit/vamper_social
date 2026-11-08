<?php

function ensurePasswordResetCodesTable(PDO $db): void
{
    $db->exec("CREATE TABLE IF NOT EXISTS password_reset_codes (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        email VARCHAR(255) NOT NULL,
        code_hash VARCHAR(255) NOT NULL,
        attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
        expires_at DATETIME NOT NULL,
        used_at DATETIME NULL,
        created_at DATETIME NOT NULL,
        KEY idx_password_reset_email_created (email, created_at),
        KEY idx_password_reset_user_created (user_id, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}
