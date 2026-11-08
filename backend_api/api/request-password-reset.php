<?php
require_once '../config/cors.php';
require_once '../config/database.php';
require_once '../libs/EmailSender.php';
require_once __DIR__ . '/libs/PasswordReset.php';

$genericResponse = [
    'success' => true,
    'message' => 'If an active account uses that email, a password reset code will be sent shortly.',
];

$database = new Database();
$db = $database->getConnection();
$data = json_decode(file_get_contents('php://input'));
$email = is_object($data) ? strtolower(trim((string)($data->email ?? ''))) : '';

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Enter a valid email address.']);
    exit();
}

try {
    ensurePasswordResetCodesTable($db);
    $accountQuery = $db->prepare('SELECT id, email FROM users WHERE email = :email AND is_active = 1 LIMIT 1');
    $accountQuery->execute([':email' => $email]);
    $account = $accountQuery->fetch(PDO::FETCH_ASSOC);

    if ($account) {
        $rateQuery = $db->prepare(
            'SELECT COUNT(*) FROM password_reset_codes
             WHERE user_id = :user_id AND created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 15 MINUTE)'
        );
        $rateQuery->execute([':user_id' => (int)$account['id']]);
        $recentRequests = (int)$rateQuery->fetchColumn();

        $cooldownQuery = $db->prepare(
            'SELECT 1 FROM password_reset_codes
             WHERE user_id = :user_id AND created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 60 SECOND)
             LIMIT 1'
        );
        $cooldownQuery->execute([':user_id' => (int)$account['id']]);
        $cooldownActive = (bool)$cooldownQuery->fetchColumn();

        if ($recentRequests < 3 && !$cooldownActive) {
            $code = sprintf('%06d', random_int(0, 999999));
            $db->beginTransaction();
            $db->prepare(
                'UPDATE password_reset_codes SET used_at = UTC_TIMESTAMP()
                 WHERE user_id = :user_id AND used_at IS NULL'
            )->execute([':user_id' => (int)$account['id']]);
            $insert = $db->prepare(
                'INSERT INTO password_reset_codes (user_id, email, code_hash, expires_at, created_at)
                 VALUES (:user_id, :email, :code_hash, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 MINUTE), UTC_TIMESTAMP())'
            );
            $insert->execute([
                ':user_id' => (int)$account['id'],
                ':email' => $account['email'],
                ':code_hash' => password_hash($code, PASSWORD_DEFAULT),
            ]);
            $resetId = (int)$db->lastInsertId();
            $db->commit();

            $emailSender = new EmailSender();
            $html = $emailSender->wrapOtpEmailHtml(
                $code,
                'Reset your password',
                'Enter this one-time code in the Vamper app to choose a new password:'
            );
            $emailResult = $emailSender->send(
                $account['email'],
                'Vamper password reset code',
                $html,
                "Your Vamper password reset code is $code. It expires in 10 minutes."
            );

            if (empty($emailResult['success'])) {
                $db->prepare('UPDATE password_reset_codes SET used_at = UTC_TIMESTAMP() WHERE id = :id')
                    ->execute([':id' => $resetId]);
                error_log('Password reset email delivery failed for a registered account.');
            }
        }
    }

    http_response_code(200);
    echo json_encode($genericResponse);
} catch (Throwable $error) {
    error_log('Password reset request failed: ' . $error->getMessage());
    http_response_code(200);
    echo json_encode($genericResponse);
}
?>
