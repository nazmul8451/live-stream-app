# AREIS / CultureCards Shorebird Code Push Guide

This document explains how **Shorebird Code Push (Over-the-Air Updates)** is configured and how to push updates to **Android** and **iOS** instantly without going through Google Play Store or Apple App Store review.

---

## 1. How Shorebird Works

Shorebird integrates a specialized Flutter engine that supports dynamic patch execution.
- **Base Release**: The binary installed from Google Play or Apple App Store must be compiled using `shorebird release` (so it contains Shorebird's updater engine).
- **Patch (OTA)**: Any Dart code change can be deployed using `shorebird patch`. Within 1-2 minutes, all user devices download the patch automatically in the background and run the new version on next launch.

### What CAN be updated via Shorebird Patch (No App Store / Play Store build needed):
- Any Dart code (`.dart` files)
- UI design, screens, colors, typography, themes
- State management & business logic (GetX controllers, services, repositories)
- Bug fixes, validation logic, API error handling
- API endpoint modifications & logic updates

### What CANNOT be updated via Shorebird Patch (Requires a store release):
- Native Android code (`android/` Kotlin/Java) or iOS code (`ios/` Swift/Obj-C)
- Adding new plugins with native platform dependencies (e.g. adding a new native library to Podfile/build.gradle)
- Permissions or config changes in `AndroidManifest.xml` or `Info.plist`
- Bundled offline assets (e.g. local asset image replacements or modifying the packaged `.env` file)

---

## 2. In-App Architecture & Features

The app includes:
1. **`shorebird.yaml`**:
   - `app_id: c1a409df-a90e-44eb-a146-6662820a25fd`
   - `auto_update: true` (Downloads patches silently on launch)
2. **`ShorebirdService`** (`lib/data/services/shorebird_service.dart`):
   - Initializes safely on app startup in [lib/main.dart](file:///c:/Users/rimon/StudioProjects/live-stream-app/lib/main.dart).
   - Runs a non-blocking background check 4 seconds after app launch.
   - Automatically downloads available patches without disturbing the user.
   - Shows a subtle banner when an update is ready for restart.
   - Provides on-demand update checks in **Account Settings**.
3. **Account Settings Screen**:
   - Displays current build and patch status (`v1.0.3+12 • Patch #1` or `Base release`).
   - Includes a **Check for Updates** button for instant manual checking and downloading.

---

## 3. Creating the Baseline Release (One-time or for Native/Major Changes)

> **Important**: A patch can ONLY be applied to an app that was originally built with `shorebird release`.

### Android:
```sh
shorebird release android
```
- This generates the release bundle (`build/app/outputs/bundle/release/app-release.aab`).
- Upload this `.aab` to Google Play Console (Production / Internal Testing).

### iOS (Build on macOS or Codemagic CI):
```sh
shorebird release ios --flutter-version=3.44.9 --export-method=app-store
```
- Upload the generated `.ipa` to App Store Connect / TestFlight.

---

## 4. Deploying Updates Over-The-Air (No Store Review / No New Build)

Whenever you fix a bug, change UI, or update logic, follow these commands:

### Android Patch:
```sh
shorebird patch android
```
*(Optional: specify release version if not on the latest: `shorebird patch android --release-version 1.0.3+12`)*

### iOS Patch (Run on macOS or CI):
```sh
shorebird patch ios
```
*(Optional: specify release version: `shorebird patch ios --release-version 1.0.3+12`)*

---

## 5. Staging & Testing Before Full Rollout (Recommended)

You can push patches to a staging track to test on your own device before releasing to all users:

```sh
# 1. Patch to staging track
shorebird patch android --track staging

# 2. Preview on your device
shorebird preview --platforms=android

# 3. When tested and verified, promote to stable (all users):
shorebird patches promote --platform=android --patch-number=PATCH_NUMBER
```

---

## 6. Useful Verification Commands

```sh
# Verify Shorebird configuration and environment
shorebird doctor

# Check authenticated Shorebird account
shorebird account whoami

# List existing releases for the app
shorebird releases list

# List patches published for a release
shorebird patches list --release-version 1.0.3+12
```
