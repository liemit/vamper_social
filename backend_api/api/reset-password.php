<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once __DIR__ . '/libs/PasswordReset.php';

$database = new Database();
$db = $database->getConnection();
$data = json_decode(file_get_contents('php://input'));
$email = is_object($data) ? strtolower(trim((string)($data->email ?? ''))) : '';
$code = is_object($data) ? trim((string)($data->code ?? '')) : '';
$newPassword = is_object($data) ? (string)($data->new_password ?? '') : '';

if (!filter_var($email, FILTER_VALIDATE_EMAIL)
    || !preg_match('/^\d{6}$/', $code)
    || strlen($newPassword) < 6
    || strlen($newPassword) > 200) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Enter a valid email, 6-digit code, and password of at least 6 characters.']);
    exit();
}

try {
    ensurePasswordResetCodesTable($db);
    $db->beginTransaction();
    $resetQuery = $db->prepare(
        'SELECT id, user_id, code_hash, attempts FROM password_reset_codes
         WHERE email = :email AND used_at IS NULL AND expires_at > UTC_TIMESTAMP()
         ORDER BY id DESC LIMIT 1 FOR UPDATE'
    );
    $resetQuery->execute([':email' => $email]);
    $reset = $resetQuery->fetch(PDO::FETCH_ASSOC);

    if (!$reset || (int)$reset['attempts'] >= 5) {
        if ($reset) {
            $db->prepare('UPDATE password_reset_codes SET used_at = UTC_TIMESTAMP() WHERE id = :id')
                ->execute([':id' => (int)$reset['id']]);
            $db->commit();
        } else {
            $db->rollBack();
        }
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'The code is invalid or expired. Request a new code and try again.']);
        exit();
    }

    if (!password_verify($code, $reset['code_hash'])) {
        $attempts = (int)$reset['attempts'] + 1;
        $db->prepare(
            'UPDATE password_reset_codes SET attempts = :attempts,
             used_at = IF(:attempts_used >= 5, UTC_TIMESTAMP(), used_at) WHERE id = :id'
        )->execute([
            ':attempts' => $attempts,
            ':attempts_used' => $attempts,
            ':id' => (int)$reset['id'],
        ]);
        $db->commit();
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'The code is invalid or expired. Request a new code and try again.']);
        exit();
    }

    $userId = (int)$reset['user_id'];
    $passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);
    $updateUser = $db->prepare('UPDATE users SET password = :password, updated_at = UTC_TIMESTAMP() WHERE id = :id AND email = :email AND is_active = 1');
    $updateUser->execute([
        ':password' => $passwordHash,
        ':id' => $userId,
        ':email' => $email,
    ]);
    if ($updateUser->rowCount() !== 1) {
        throw new DomainException('The account could not be updated.');
    }

    $db->prepare('UPDATE password_reset_codes SET used_at = UTC_TIMESTAMP() WHERE user_id = :id AND used_at IS NULL')
        ->execute([':id' => $userId]);
    $apiTokensTable = $db->query("SHOW TABLES LIKE 'api_tokens'")->fetchColumn();
    if ($apiTokensTable !== false) {
        $db->prepare('DELETE FROM api_tokens WHERE user_id = :id')->execute([':id' => $userId]);
    }

    $db->commit();
    echo json_encode([
        'success' => true,
        'message' => 'Password changed. Sign in again with your new password.',
    ]);
} catch (DomainException $error) {
    if ($db->inTransaction()) $db->rollBack();
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => $error->getMessage()]);
} catch (Throwable $error) {
    if ($db->inTransaction()) $db->rollBack();
    error_log('Password reset failed: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Unable to reset password right now. Please try again.']);
}
?>
