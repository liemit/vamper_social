# Party room media configuration

Party voice and screen sharing use LiveKit. Configure these variables in the
PHP-FPM/Apache environment on the API server; do not put the API secret in
Flutter, the SQL dump, or a public `.env` file:

```text
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=your-livekit-api-key
LIVEKIT_API_SECRET=your-livekit-api-secret
```

Pass the variables through the PHP-FPM pool if its environment is cleared, then
restart PHP-FPM or Apache. If the server does not provide all three values,
chat, seats, reactions, and presence still work, but
the app will report that voice and screen sharing are unavailable. The backend
issues short-lived room tokens. Microphone publishing is limited to speaker
seats; screen sharing is limited to the host or a seated participant explicitly
approved by the host. A host or co-host can lock a participant's microphone.

## Admin portal

The PHP admin portal and API use the `VAMPER_DB_HOST`, `VAMPER_DB_NAME`,
`VAMPER_DB_USER`, and `VAMPER_DB_PASSWORD` environment variables when present.
The existing local defaults remain `localhost` / `vamper_social` / `root` /
empty password. Set production credentials in the PHP-FPM/Apache environment,
not in source control.

On the first admin login, additive migrations create `admin_accounts`,
`admin_audit_log`, and `vpc_ledger`, add report-review metadata and the
`shop_items.is_active` flag, and preserve existing accounts and purchases. The
PayPal checkout endpoints create their own order and idempotency tables on
first use.
Existing `users.role = 'admin'` accounts are initialized as `super_admin` so
they retain access. The database account needs `CREATE` and `ALTER` privileges
for this one-time initialization. No database reset or full SQL import is
required. Existing sessions are invalidated by the admin-only session cookie.

Admin sessions use password hashes only, CSRF tokens, role permissions, and
audited write actions. User and post moderation is reversible; user deletion
has been removed. VPC adjustments, shop purchases, gifts, and sandbox top-ups
are recorded in the additive VPC ledger. Older coin activity is intentionally
not backfilled because trustworthy before/after balances are unavailable.

PayPal checkout uses server-created Orders v2 and server-side capture
verification. The package price, coin count, currency, and merchant are checked
on the server before coins are credited; processing is idempotent. Sandbox
payments are recorded as `sandbox_mock` and excluded from revenue totals. Live
payments are recorded as `completed`.

Configure these values in the PHP-FPM/Apache environment on the API server.
Never put PayPal client secrets in Flutter, SQL, or source control:

```text
PAYPAL_SANDBOX_CLIENT_ID=your-sandbox-client-id
PAYPAL_SANDBOX_CLIENT_SECRET=your-sandbox-client-secret
PAYPAL_LIVE_CLIENT_ID=your-live-client-id
PAYPAL_LIVE_CLIENT_SECRET=your-live-client-secret
PAYPAL_RETURN_URL=https://api.example.com/api/paypal-return.php
```

Enable the PHP cURL extension and allow outbound HTTPS to PayPal. Set the
environment variables in the PHP-FPM pool if it clears inherited variables,
then restart PHP-FPM or Apache. In the Admin wallet settings, set the merchant
email to the email address of the matching PayPal account and choose Sandbox or
Live. Checkout is disabled unless that mode's API credentials and a valid
merchant email are configured. Sandbox uses PayPal Sandbox buyer and merchant
accounts; Live charges real money. The authenticated
`get-payment-settings.php` endpoint supplies the mode to all app builds.

The app opens the PayPal approval page, then the user returns to the app and
selects “Verify payment”. The server captures or verifies the PayPal order and
credits coins only after checking the completed capture. Deploy the backend
before updating the app. Test the complete flow with Sandbox accounts before
enabling Live. Check Google Play and Apple App Store payment policies for
digital goods before distributing the app through those stores.

Party music playback is not implemented yet. The shop exposes profile frames
and avatars only; legacy Party-frame records are hidden and cannot be purchased
or equipped.

## Profile cosmetics shop

Opening the shop through `get-shop-items.php` installs any missing profile
frames and avatars in `shop_items`, including on an existing database. This
catalog update is additive and does not replace existing shop rows or
`user_items` ownership; no database reset or full SQL import is needed. Avatar
artwork is currently served by DiceBear, so those images require internet
access to that service.

Run the Party table additions in `../vamper_social.sql` when applying the schema;
the Party APIs also create the new tables for existing installations. Party
passwords are hashed on creation, and the password is never returned by the
party-list endpoint.

Android screen sharing requests the system capture permission and runs the
required foreground service. On iOS, LiveKit can capture the app itself; sharing
other apps requires configuring a ReplayKit Broadcast Upload Extension and a
shared App Group in the Xcode project.

## Virtual gifts

The authenticated `get-gifts.php` and `send-gift.php` endpoints initialize
the gift catalog, immutable transaction history, and notification storage for
existing installations. The catalog is seeded with starter emoji gifts and
prices in VPC coins. `send-gift.php` handles direct chat gifts; Party gifts use
the `send_gift` action in `party-room.php`. The server validates recipients,
loads prices from the catalog, locks the sender's balance, and records the
coin debit and delivery atomically. Request IDs prevent a retried request from
charging twice. Gift value is not credited to the recipient in this initial
version.

The authenticated `get-my-gifts.php` endpoint builds the recipient's collection
and recent-gift history directly from `gift_transactions`, the authoritative
gift ledger. No additional inventory table or SQL migration is required;
existing gift transactions are included automatically. Received gifts are
collectibles and cannot be redeemed or transferred for VPC coins.

In chat, the sender sees a gift celebration immediately after the gift API
confirms delivery. The recipient sees the matching celebration when message
polling detects the new gift; visual tiers scale with catalog coin value.

## Chat delivery and presence

The authenticated `chat-presence.php` endpoint records app heartbeats and
explicit offline transitions in the additive `user_presence` table, created on
first use. Flutter sends heartbeats while the app is foregrounded and marks the
user offline when it is backgrounded. A user is considered online only if the
last heartbeat is under 45 seconds old and their `settings_show_online_status`
setting is enabled; stale sessions therefore expire without a database reset.

Opening a conversation marks its incoming messages as read before returning
them. The sender's chat polling then receives the updated `is_read` state, which
drives the sent/seen check mark shown on outgoing messages.

## Voice Match calls

Voice Match matchmaking uses the authenticated `voice-match-session.php`
endpoint. It pairs two active queue members with mutually compatible gender
preferences and issues room-scoped LiveKit tokens that can publish microphone
audio only. The Flutter call screen connects to the returned room, requests
microphone access, and uses authenticated heartbeats to detect the other
participant leaving. Voice Match queue/session tables are initialized on first
use; both participants need the LiveKit URL, API key, and API secret configured
for calls to connect.

## One-to-one chat calls

The authenticated `chat-call.php` endpoint supports audio and video calls
between users who have both sent a message in the same conversation. It handles
ringing, accept/decline, heartbeats, and ending calls; LiveKit tokens are issued
only after acceptance. Audio calls can publish microphone audio only, while
video calls can publish microphone audio and camera video. Android and iOS need
microphone and camera permissions enabled for the respective call features.
Incoming calls are currently checked while the recipient has the matching chat
open in the foreground; background notifications and calls from other screens
are not implemented yet.
