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
