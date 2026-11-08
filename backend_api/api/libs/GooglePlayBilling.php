<?php

function googlePlayBillingSettings(): array
{
    $packageName = trim((string)getenv('GOOGLE_PLAY_PACKAGE_NAME'));
    if ($packageName === '') {
        throw new RuntimeException('Google Play package name is not configured.');
    }

    $serviceAccountJson = trim((string)getenv('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
    if ($serviceAccountJson === '') {
        $serviceAccountFile = trim((string)getenv('GOOGLE_PLAY_SERVICE_ACCOUNT_FILE'));
        if ($serviceAccountFile !== '' && is_file($serviceAccountFile) && is_readable($serviceAccountFile)) {
            $serviceAccountJson = (string)file_get_contents($serviceAccountFile);
        }
    }

    $serviceAccount = json_decode($serviceAccountJson, true);
    if (!is_array($serviceAccount)
        || empty($serviceAccount['client_email'])
        || empty($serviceAccount['private_key'])
        || empty($serviceAccount['token_uri'])) {
        throw new RuntimeException('Google Play service account credentials are not configured.');
    }

    if (!str_starts_with((string)$serviceAccount['token_uri'], 'https://')) {
        throw new RuntimeException('Google OAuth token URI must use HTTPS.');
    }

    return [
        'package_name' => $packageName,
        'client_email' => (string)$serviceAccount['client_email'],
        'private_key' => (string)$serviceAccount['private_key'],
        'token_uri' => (string)$serviceAccount['token_uri'],
    ];
}

function googlePlayBase64UrlEncode(string $value): string
{
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function googlePlayAccessToken(array $settings): string
{
    $now = time();
    $header = ['alg' => 'RS256', 'typ' => 'JWT'];
    $claims = [
        'iss' => $settings['client_email'],
        'scope' => 'https://www.googleapis.com/auth/androidpublisher',
        'aud' => $settings['token_uri'],
        'iat' => $now,
        'exp' => $now + 3600,
    ];

    $unsignedToken = googlePlayBase64UrlEncode(json_encode($header, JSON_THROW_ON_ERROR)) . '.'
        . googlePlayBase64UrlEncode(json_encode($claims, JSON_THROW_ON_ERROR));
    $privateKey = openssl_pkey_get_private($settings['private_key']);
    if ($privateKey === false || !openssl_sign($unsignedToken, $signature, $privateKey, OPENSSL_ALGO_SHA256)) {
        throw new RuntimeException('Unable to sign Google Play authorization request.');
    }

    $assertion = $unsignedToken . '.' . googlePlayBase64UrlEncode($signature);
    $response = googlePlayCurlRequest(
        $settings['token_uri'],
        'POST',
        ['Content-Type: application/x-www-form-urlencoded'],
        http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $assertion,
        ])
    );
    $data = json_decode($response['body'], true);
    if ($response['status'] < 200 || $response['status'] >= 300 || !is_array($data) || empty($data['access_token'])) {
        throw new RuntimeException('Google Play authorization failed.');
    }

    return (string)$data['access_token'];
}

function googlePlayApiRequest(array $settings, string $method, string $path, ?array $payload = null): array
{
    $accessToken = googlePlayAccessToken($settings);
    $headers = [
        'Authorization: Bearer ' . $accessToken,
        'Accept: application/json',
    ];
    $body = null;
    if ($payload !== null) {
        $headers[] = 'Content-Type: application/json';
        $body = json_encode($payload, JSON_THROW_ON_ERROR);
    }

    $response = googlePlayCurlRequest(
        'https://androidpublisher.googleapis.com' . $path,
        $method,
        $headers,
        $body
    );
    $data = $response['body'] === '' ? [] : json_decode($response['body'], true);
    if ($response['status'] < 200 || $response['status'] >= 300) {
        error_log('Google Play Developer API request failed with HTTP ' . $response['status'] . '.');
        throw new RuntimeException('Google Play could not verify this purchase right now.');
    }

    return is_array($data) ? $data : [];
}

function googlePlayCurlRequest(string $url, string $method, array $headers, ?string $body): array
{
    if (!function_exists('curl_init')) {
        throw new RuntimeException('PHP cURL is required for Google Play Billing verification.');
    }

    $curl = curl_init($url);
    $options = [
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 20,
    ];
    if ($body !== null) {
        $options[CURLOPT_POSTFIELDS] = $body;
    }
    curl_setopt_array($curl, $options);
    $responseBody = curl_exec($curl);
    $status = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
    $error = curl_error($curl);
    curl_close($curl);

    if ($responseBody === false) {
        error_log('Google Play HTTP request failed: ' . $error);
        throw new RuntimeException('Unable to connect to Google Play for purchase verification.');
    }

    return ['status' => $status, 'body' => (string)$responseBody];
}
