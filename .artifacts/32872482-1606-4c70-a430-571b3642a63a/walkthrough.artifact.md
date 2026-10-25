# Walkthrough - Hard User Block Feature

Implemented permanent **Hard User Block** across database, backend APIs, profile views, party rooms, and settings.

## Changes

### Database & SQL Export
#### [vamper_social.sql](file:///C:/Users/liemb/Downloads/vamper/vamper/vamper_social.sql)
- Added `blocked_users` table structure DDL for direct import in phpMyAdmin/MySQL.

### Backend API
#### [block-user.php](file:///C:/Users/liemb/Downloads/vamper/vamper/backend_api/api/block-user.php) [NEW]
- Endpoint to block/unblock users and list blocked users for settings.
#### [get-profile.php](file:///C:/Users/liemb/Downloads/vamper/vamper/backend_api/api/get-profile.php) & [join-party.php](file:///C:/Users/liemb/Downloads/vamper/vamper/backend_api/api/join-party.php)
- Enforced hard blocking logic: Profile views and party room entry are rejected when blocked.

### Frontend App
#### [profile_preview_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/profile/profile_preview_screen.dart)
- Added "Block User 🚫" button in AppBar actions and blocked placeholder layout.
#### [party_room_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/matches/party_room_screen.dart)
- Added "Block User 🚫" option to participant seat bottom sheet.
#### [blocked_users_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/settings/blocked_users_screen.dart)
- Created full Blocked Users management screen allowing users to view and unblock users.

## Verification Results

### Automated Tests
- Project builds and compiles successfully.
