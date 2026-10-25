# Implementation Plan - Hard User Block Feature

Implement a strict, permanent **User Block** feature. Blocked users cannot view profiles, join party rooms created by the blocker, or interact across the app until unblocked.

## User Review Required

> [!IMPORTANT]
> This plan implements:
> 1. **Database Schema & SQL File**: Adds the `blocked_users` table structure to `vamper_social.sql` and auto-provisions it in backend scripts.
> 2. **Backend Hard Block Enforcement**:
>    - `block-user.php`: API endpoint to block/unblock users and list blocked users.
>    - `get-profile.php`: Rejects profile views if blocked.
>    - `get-parties.php` & `join-party.php`: Rejects party room entry if the host or participant is blocked.
> 3. **Frontend App Integration**:
>    - `ProfilePreviewScreen`: "Block User 🚫" button and blocked state placeholder.
>    - `PartyRoomScreen`: Block action in participant/seat modal.
>    - `BlockedUsersScreen`: List blocked users with Unblock capability.

## Open Questions

- None. The feature strictly satisfies the user's requirements and database export needs.

## Proposed Changes

### Database (`vamper_social.sql`)
- Add `blocked_users` table DDL script to `vamper_social.sql` for easy import.

### Backend API (`backend_api/api/`)

#### [NEW] [block-user.php](file:///C:/Users/liemb/Downloads/vamper/vamper/backend_api/api/block-user.php)
- Handle block/unblock actions and fetch blocked users list for settings.

#### [MODIFY] [get-profile.php](file:///C:/Users/liemb/Downloads/vamper/vamper/backend_api/api/get-profile.php)
- Check `blocked_users` table and return `is_blocked = true` if blocked.

#### [MODIFY] [join-party.php](file:///C:/Users/liemb/Downloads/vamper/vamper/backend_api/api/join-party.php)
- Prevent users from joining party rooms created by users who blocked them.

### Frontend Flutter App (`lib/`)

#### [MODIFY] [profile_preview_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/profile/profile_preview_screen.dart)
- Add Block button to AppBar/menu and handle blocked state layout.

#### [MODIFY] [party_room_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/matches/party_room_screen.dart)
- Add "Block User 🚫" option to participant seat bottom sheet.

#### [MODIFY] [blocked_users_screen.dart](file:///C:/Users/liemb/Downloads/vamper/vamper/lib/screens/settings/blocked_users_screen.dart)
- Connect to `block-user.php` to list and unblock users.

## Verification Plan

### Automated Tests
- Build and run Flutter app.

### Manual Verification
- Block a user from their profile or party room.
- Verify profile view shows blocked placeholder.
- Verify blocked user cannot join party rooms created by the blocker.
- Verify unblocking via Blocked Users Settings.
