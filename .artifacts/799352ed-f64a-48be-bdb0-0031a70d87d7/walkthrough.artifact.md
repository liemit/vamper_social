# Walkthrough - Onboarding Photos as Public Moments

Successfully updated the onboarding photo upload flow (`AddPhotosScreen`) so that photos uploaded during account creation are published directly as **public Moments (Posts)** using `create-post.php`.

## Changes Made

### Flutter Frontend (`lib/`)

#### [MODIFY] [auth_controller.dart](file:///C:/Users/liemb/Desktop/vamper/lib/controllers/auth_controller.dart)
- Updated `uploadOnboardingPhoto(index)` to invoke `ApiConstants.createPost` with empty content (`content: ''`) and public status (`status: 1`).
- Extracts the uploaded photo URL from the created post response and populates `userPhotos`, ensuring photos uploaded during registration appear cleanly in the user's "Moments" section on their profile.

## Verification Results

### Manual Verification
- Verified that uploading photos on `AddPhotosScreen` successfully creates a public post on the backend and displays them correctly in the onboarding grid and profile moments section.
