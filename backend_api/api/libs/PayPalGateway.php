<?php

final class PayPalGateway
{
    private string $baseUrl;
    private string $clientId;
    private string $clientSecret;

    public function __construct(string $mode)
    {
        if (!in_array($mode, ['sandbox', 'live'], true)) {
            throw new InvalidArgumentException('Unsupported PayPal environment.');
        }
        if (!function_exists('curl_init')) {
            throw new RuntimeException('The PHP cURL extension is required for PayPal checkout.');
        }

        $prefix = $mode === 'live' ? 'PAYPAL_LIVE' : 'PAYPAL_SANDBOX';
        $this->clientId = trim((string)getenv($prefix . '_CLIENT_ID'));
        $this->clientSecret = trim((string)getenv($prefix . '_CLIENT_SECRET'));
        if ($this->clientId === '' || $this->clientSecret === '') {
            throw new RuntimeException('PayPal API credentials are not configured for the selected mode.');
        }

        $this->baseUrl = $mode === 'live'
            ? 'https://api-m.paypal.com'
            : 'https://api-m.sandbox.paypal.com';
    }

    public static function isConfigured(string $mode): bool
    {
        if (!function_exists('curl_init') || !in_array($mode, ['sandbox', 'live'], true)) {
            return false;
        }

        $prefix = $mode === 'live' ? 'PAYPAL_LIVE' : 'PAYPAL_SANDBOX';
        $returnUrl = trim((string)getenv('PAYPAL_RETURN_URL'));
        return trim((string)getenv($prefix . '_CLIENT_ID')) !== ''
            && trim((string)getenv($prefix . '_CLIENT_SECRET')) !== ''
            && filter_var($returnUrl, FILTER_VALIDATE_URL) !== false
            && strtolower((string)parse_url($returnUrl, PHP_URL_SCHEME)) === 'https';
    }

    public function createOrder(
        string $checkoutId,
        int $userId,
        int $coins,
        string $amount,
        string $merchantEmail,
        string $requestId
    ): array {
        $returnUrl = trim((string)getenv('PAYPAL_RETURN_URL'));
        $separator = str_contains($returnUrl, '?') ? '&' : '?';
        $returnUrl .= $separator . 'checkout=' . rawurlencode($checkoutId);
        $cancelUrl = $returnUrl . '&cancel=1';

        return $this->request(
            'POST',
            '/v2/checkout/orders',
            [
                'intent' => 'CAPTURE',
                'purchase_units' => [[
                    'reference_id' => $checkoutId,
                    'custom_id' => (string)$userId,
                    'invoice_id' => $checkoutId,
                    'description' => $coins . ' Vamper Coins',
                    'payee' => ['email_address' => $merchantEmail],
                    'amount' => ['currency_code' => 'USD', 'value' => $amount],
                ]],
                'application_context' => [
                    'brand_name' => 'Vamper',
                    'user_action' => 'PAY_NOW',
                    'return_url' => $returnUrl,
                    'cancel_url' => $cancelUrl,
                ],
            ],
            $requestId
        );
    }

    public function getOrder(string $paypalOrderId): array
    {
        return $this->request('GET', '/v2/checkout/orders/' . rawurlencode($paypalOrderId));
    }

    public function captureOrder(string $paypalOrderId, string $requestId): array
    {
        return $this->request(
            'POST',
            '/v2/checkout/orders/' . rawurlencode($paypalOrderId) . '/capture',
            null,
            $requestId
        );
    }

    private function accessToken(): string
    {
        $curl = curl_init($this->baseUrl . '/v1/oauth2/token');
        curl_setopt_array($curl, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => 'grant_type=client_credentials',
            CURLOPT_HTTPHEADER => [
                'Accept: application/json',
                'Accept-Language: en_US',
                'Content-Type: application/x-www-form-urlencoded',
            ],
            CURLOPT_USERPWD => $this->clientId . ':' . $this->clientSecret,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ]);
        $response = curl_exec($curl);
        $status = (int)curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        $curlError = curl_error($curl);
        curl_close($curl);

        if ($response === false || $status < 200 || $status >= 300) {
            error_log('PayPal OAuth request failed with HTTP ' . $status . ($curlError !== '' ? ': ' . $curlError : ''));
            throw new RuntimeException('Unable to connect to PayPal. Please try again later.');
        }

        $decoded = json_decode($response, true);
        $token = is_array($decoded) ? ($decoded['access_token'] ?? null) : null;
        if (!is_string($token) || $token === '') {
            throw new RuntimeException('PayPal did not provide an API access token.');
        }
        return $token;
    }

    private function request(
        string $method,
        string $path,
        ?array $payload = null,
        ?string $requestId = null
    ): array {
        $headers = [
            'Accept: application/json',
            'Content-Type: application/json',
            'Authorization: Bearer ' . $this->accessToken(),
        ];
        if ($requestId !== null) {
            $headers[] = 'PayPal-Request-Id: ' . $requestId;
        }

        $curl = curl_init($this->baseUrl . $path);
        curl_setopt_array($curl, [
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 45,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ]);
        if ($payload !== null) {
            curl_setopt(
                $curl,
                CURLOPT_POSTFIELDS,
                json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES)
            );
        }

        $response = curl_exec($curl);
        $status = (int)curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        $curlError = curl_error($curl);
        curl_close($curl);

        if ($response === false) {
            error_log('PayPal API request failed: ' . $curlError);
            throw new RuntimeException('Unable to connect to PayPal. Please try again.');
        }
        $decoded = json_decode($response, true);
        if ($status < 200 || $status >= 300 || !is_array($decoded)) {
            $debugId = is_array($decoded) ? ($decoded['debug_id'] ?? 'unavailable') : 'unavailable';
            error_log('PayPal API returned HTTP ' . $status . ', debug id: ' . $debugId);
            if ($status === 422) {
                throw new DomainException('PayPal has not approved this payment yet, or it was already processed.');
            }
            throw new RuntimeException('PayPal could not complete the request. Please try again.');
        }
        return $decoded;
    }
}
