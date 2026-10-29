<?php

function ensureApiTokensTable(PDO $db): void
{
    $db->exec("CREATE TABLE IF NOT EXISTS api_tokens (
        token_hash CHAR(64) NOT NULL PRIMARY KEY,
        user_id INT NOT NULL,
        expires_at DATETIME NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_api_tokens_user_id (user_id),
        INDEX idx_api_tokens_expires_at (expires_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}

function issueApiToken(PDO $db, int $userId): string
{
    ensureApiTokensTable($db);

    $token = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $token);

    $stmt = $db->prepare(
        "INSERT INTO api_tokens (token_hash, user_id, expires_at)
         VALUES (:token_hash, :user_id, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 DAY))"
    );
    $stmt->execute([
        ':token_hash' => $tokenHash,
        ':user_id' => $userId,
    ]);

    return $token;
}

function authenticateApiUser(PDO $db): int
{
    try {
        ensureApiTokensTable($db);
    } catch (PDOException $error) {
        error_log('Unable to initialize API token storage: ' . $error->getMessage());
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Authentication service is unavailable.',
        ]);
        exit();
    }

    $token = readBearerToken();
    if ($token === null) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Authentication required. Please sign in again.',
        ]);
        exit();
    }

    try {
        $stmt = $db->prepare(
            "SELECT t.user_id
             FROM api_tokens t
             INNER JOIN users u ON u.id = t.user_id
             WHERE t.token_hash = :token_hash
               AND t.expires_at > UTC_TIMESTAMP()
               AND u.is_active = 1
             LIMIT 1"
        );
        $stmt->execute([':token_hash' => hash('sha256', $token)]);
        $userId = $stmt->fetchColumn();
    } catch (PDOException $error) {
        error_log('Unable to validate API token: ' . $error->getMessage());
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Authentication service is unavailable.',
        ]);
        exit();
    }

    if ($userId === false) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Session expired or invalid. Please sign in again.',
        ]);
        exit();
    }

    return (int)$userId;
}

function revokeApiToken(PDO $db): void
{
    authenticateApiUser($db);
    $token = readBearerToken();
    if ($token === null) {
        return;
    }

    $stmt = $db->prepare('DELETE FROM api_tokens WHERE token_hash = :token_hash');
    $stmt->execute([':token_hash' => hash('sha256', $token)]);
}

function readBearerToken(): ?string
{
    $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($authorization === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $name => $value) {
            if (strcasecmp($name, 'Authorization') === 0) {
                $authorization = $value;
                break;
            }
        }
    }

    return preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($authorization), $matches)
        ? $matches[1]
        : null;
}
