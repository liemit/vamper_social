# Walkthrough - Avatar & Frame Store Screen UI

Implemented the Flutter **Item Store Screen** (`StoreScreen`) allowing users to browse, purchase, and equip Avatars, Profile Frames, and Party Room Frames using VPC Coins.

## Changes

### Frontend App
#### [store_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/wallet/store_screen.dart) [NEW]
- Interactive Item Store with:
  - VPC Coins Balance Banner & Top Up button.
  - Category TabBar (`Frames 🖼️`, `Party 👑`, `Avatars 👤`).
  - Item cards displaying item details, VPC coins price, owned/equipped badges, and Buy/Equip actions.
  - Automatic balance deduction and item ownership state updates.
#### [coin_shop_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/wallet/coin_shop_screen.dart)
- Added **"Open Avatar & Frame Store 🛍️"** button below the balance card.
#### [home_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/home/home_screen.dart)
- Added **"Item Store 🛍️"** menu item in `ProfileTab`.

## Verification Results

### Automated Tests
- Project builds and compiles successfully.
