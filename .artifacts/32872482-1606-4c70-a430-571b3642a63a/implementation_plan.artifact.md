# Implementation Plan - Avatar & Frame Store Screen UI

Build the Flutter **Store Screen** (`StoreScreen`) where users can browse, purchase (using VPC Coins), and equip Avatars, Profile Frames, and Party Room Frames, and link it from the Profile Tab and Coin Store.

## User Review Required

> [!IMPORTANT]
> This plan implements:
> 1. **Store Screen (`StoreScreen`)**:
     - Tabs: `Avatars`, `Profile Frames`, `Party Frames`.
     - Displays item details, price in VPC Coins, owned status, and Equip/Buy actions.
> 2. **Entry Points**:
     - Add an entry button in `ProfileTab` (`home_screen.dart`) and `CoinShopScreen` (`coin_shop_screen.dart`) titled **"Avatar & Frame Store"** or **"Item Shop"**.

## Open Questions

- None. The backend APIs (`get-shop-items.php`, `purchase-item.php`, `equip-item.php`) are already fully built.

## Proposed Changes

### Frontend Flutter App (`lib/`)

#### [NEW] [store_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/wallet/store_screen.dart)
- Store screen with TabBar (`Avatars`, `Profile Frames`, `Party Frames`), item grid, coin balance card, purchase confirmation dialog, and equip action.

#### [MODIFY] [coin_shop_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/wallet/coin_shop_screen.dart)
- Add a button to open the Item Store.

#### [MODIFY] [home_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/home/home_screen.dart)
- Add an entry button in `ProfileTab` to open the Item Store.

## Verification Plan

### Automated Tests
- Build and run Flutter app.

### Manual Verification
- Go to Profile or Coin Store, click "Avatar & Frame Store".
- Browse items across tabs, purchase an item with VPC Coins, and equip it.
