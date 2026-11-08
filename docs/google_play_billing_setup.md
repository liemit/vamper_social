# Google Play Billing Setup

## Android application ID

The current Android Gradle configuration uses `com.example.vamper` as `applicationId`. The package name configured in Play Console and `GOOGLE_PLAY_PACKAGE_NAME` must match the published app exactly. If this is only a placeholder and the app has not been published, choose the final unique package name before creating the Play Console app; do not change it after publishing.

## Product IDs

Create these as one-time in-app products in Play Console. Keep the IDs exactly in sync with `CoinShopScreen` and `verify-google-play-purchase.php`:

| Product ID | VPC credited |
| --- | ---: |
| `vamper_coins_100` | 100 |
| `vamper_coins_500` | 500 |
| `vamper_coins_1200` | 1,200 |
| `vamper_coins_3000` | 3,000 |

Set product availability and localized prices in Play Console. The Android app reads the localized price from Google Play; the server decides the VPC amount from the product ID.

## Server credentials

1. Enable the Google Play Android Developer API in the Google Cloud project linked to the Play Console.
2. Create a service account and grant it access to this app in Play Console with the permissions needed to view purchases and manage orders.
3. Store the service-account JSON securely on the PHP host, outside the public web root, and configure:
   - `GOOGLE_PLAY_PACKAGE_NAME`: the Android `applicationId` published to Play.
   - `GOOGLE_PLAY_SERVICE_ACCOUNT_FILE`: absolute path to the service-account JSON file.
4. Never commit the service-account JSON or its private key to GitHub or bundle it in the app.
5. Ensure PHP OpenSSL and cURL extensions are enabled.

The PHP endpoint creates `google_play_purchases` on first verified purchase and writes coin credits to `vpc_ledger` transactionally. A purchase token hash is unique, so replaying the same purchase cannot credit VPC twice.

## Test rollout

1. Upload a signed build to an Internal testing track and configure the products as active.
2. Add tester accounts in Play Console and install the app from the testing link.
3. Test successful purchase, cancellation, insufficient network/server availability, retry after verification failure, and duplicate purchase notifications.
4. Confirm the user's VPC balance, `google_play_purchases`, and `vpc_ledger` before enabling a production rollout.

PayPal Sandbox remains available on Web only. Live PayPal is not enabled by this change. iOS purchases are not configured; they need a separate App Store in-app purchase integration.
