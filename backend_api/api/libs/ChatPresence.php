<?php

function ensureChatPresenceTable(PDO $db): void
{
    $db->exec("CREATE TABLE IF NOT EXISTS user_presence (
        user_id INT NOT NULL PRIMARY KEY,
        last_seen DATETIME NOT NULL,
        is_active TINYINT(1) NOT NULL DEFAULT 0,
        INDEX idx_user_presence_online (is_active, last_seen)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}
