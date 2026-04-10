# Hexa-Cam Project Documentation

## Document Revision

- **Last updated:** 2026-04-09
- **Scope:** Flutter app architecture, features, platform behavior, testing, setup, and implementation notes.
- **Primary platforms:** Android, iOS, Web

### Changelog — Android & iOS (recent)

**Android**

- Startup permissions: `PermissionController` requests camera + mic; storage uses **`manageExternalStorage` on API 30+** and **`Permission.storage` only below API 30** (scoped storage aware).
- **Gallery export:** still images and videos saved with **`gal`** where possible (`FileService`).
- **Report download:** after app-folder save, copy to **public Downloads** (`Hexa Cam Reports`) when storage permission allows (`ReportController` + `FileService.saveToDownloads`).
- **Camera page** init requests storage/manage + optional photos/videos on Android only (not on iOS branch).
- **Debug APK:** build with `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk` (not committed; `/build/` is gitignored).

**iOS**

- **Info.plist:** `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`.
- **Podfile:** `permission_handler_apple` preprocessor flags enable **CAMERA, MICROPHONE, PHOTOS, PHOTOS_ADD_ONLY** so system dialogs actually appear.
- **Startup + camera open:** requests **photos + photosAddOnly** alongside camera/mic so saves match Android parity.
- **`isStorageGranted`:** set when photo library access is granted/limited/provisional (aligned with “ready to save” semantics).
- **Photos first:** `FileService.saveToDevice` / `saveVideoToDevice` try **`Gal`** (album `Hexa Cam`) then **share sheet** fallback.
- **Report download:** writes copy under app **Documents/Downloads/Hexa Cam Reports** (Files app), then opens **share** for AirDrop/Files.
- **Toasts:** `HexaToast` uses **root overlay** + **top** alignment so sheets/modals don’t pin messages to the bottom.

**Shared**

- Capture **Download/Save** awaits `_persistMedia` where applicable; folder save happens **before** device export so a gallery failure still leaves media in the app.
- **PDF reports:** **Noto Sans** TTFs embedded for correct **µm / nm** in text; `assets/fonts/` required in `pubspec.yaml`.

## Executive Summary

Hexa-Cam is a Flutter microscopy imaging app for:
- capturing images/videos,
- adding drawings and measurement annotations,
- organizing media in folders,
- generating PDF reports,
- exporting/sharing outputs with platform-safe fallbacks.

---

## Architecture

## Technology Stack

- **Framework:** Flutter
- **State + DI:** GetX
- **Persistence:** SharedPreferences + sqflite
- **Media:** camera, ffmpeg_kit_flutter_new_full, video_player, image
- **Export/Sharing:** gal, share_plus, path_provider
- **Reporting:** pdf

## Module Layout

- `lib/features/camera/` - capture flow and camera UX
- `lib/ui/viewer/` and `lib/ui/image_viewer/` - annotate/view/edit
- `lib/ui/report/` + `lib/controllers/report_controller.dart` - report composition and export
- `lib/controllers/permission_controller.dart` - permission orchestration
- `lib/data/services/` - file/database/media operations
- `lib/state/app_registry.dart` - dependency registration and app-wide controllers

---

## Key Runtime Behavior

## 1) Camera Initialization (`CameraControllerX`)

- Attempts multiple resolution presets safely.
- Uses fallback ordering and guarded init attempts.
- If all inits fail:
  - error state is set,
  - aspect ratio falls back to `16:9`,
  - snackbar is shown when app context is available,
  - exception is rethrown only in debug mode.

This keeps production stable while preserving debug visibility.

## 2) Permissions (`PermissionController`)

### Android
- Requests camera + microphone.
- Uses `manageExternalStorage` for Android 11+ (API 30+).
- Uses `Permission.storage` only on API <30.
- Permission dialog is debounced to avoid duplicate popup stacking.
- Retry count/backoff persisted in SharedPreferences.

### iOS
- Requests camera + microphone + photos + photosAddOnly.
- Photos access is treated as storage-ready state for save flows.
- Permanent denial path uses settings redirect.

### Reset
- `clearPermissionState()` clears startup flags and retry counters.
- Settings page exposes reset actions for support/debug workflows.

## 3) Export / Save / Download

### Images/Videos
- **Android:** direct gallery save via `gal`.
- **iOS:** tries direct Photos save via `gal`; if unavailable, opens share sheet fallback.
- **Web:** browser download path.

### Reports (PDF)
- Always saved to app folder first.
- Android additionally writes user-visible Downloads path when possible.
- iOS uses Files-sandbox download path and still offers share fallback.
- Web uses direct download.

## 4) Toast System (`HexaToast`)

- Root overlay based (prevents local sheet overlay placement issues).
- Top aligned and safe-area aware.
- Cancels/replaces previous toast entry to avoid stacking stale overlays.

## 5) PDF Rendering

- Includes metadata, metrics, marked image, and marking details.
- Noto Sans font assets are embedded for reliable `µm`/`nm` text.
- If font loading fails, fallback path still keeps report generation functional.

## 6) Annotation History

- `DrawHistory` now caps undo stack at **50** actions for memory stability.
- Oldest history entries are dropped once cap is exceeded.
- Undo/redo remains intact after cap.

---

## Data & Storage

## SharedPreferences

- Folder metadata, settings, startup flags, and UX toggles.
- Save-dialog persistence (`Don't ask again`) is included.

## SQLite (`MediaDatabase`)

- DB: `hexacam-media.db`
- Table: `media_assets`
- Stores binary blobs (`Uint8List`) for media/report assets.
- Explicit schema version + upgrade hook present for forward migration safety.

## File System

- App docs folders for captures/reports.
- Platform-specific export paths with fallback strategy.

---

## Testing & QA

## Automated Test Coverage (current)

- Camera init failure resilience and 16:9 fallback assertions.
- Permission reset state validation.
- SaveDialog `dontAskAgain` persistence behavior.
- Calibration conversion edge cases (`µm/nm`, positive/negative/zero).
- DrawHistory cap and undo/redo behavior.
- Report action async-button disable behavior.
- Auth/folder/model/state core tests.

## Standard Commands

```bash
flutter pub get
dart analyze --fatal-infos
flutter test
```

---

## Platform Notes

## Android

- Scoped-storage-aware permission handling.
- Download visibility depends on storage permission and OS behavior.

## iOS

- `Info.plist` contains camera/microphone/photos usage descriptions.
- Direct Photos write preferred where possible.
- Files/Share fallback path remains enabled for reliability.

## Web

- Camera/download handled via browser capabilities.
- Native plugin-only code paths are guarded behind platform checks.

---

## Setup

## Prerequisites

- Flutter SDK (stable channel recommended)
- Android Studio / Android SDK for Android builds
- Xcode + CocoaPods for iOS builds

## Bootstrap

```bash
flutter pub get
flutter run -d chrome
flutter run -d android
flutter run -d ios
```

### Android debug APK (local artifact)

```bash
flutter build apk --debug
```

Output (typical): `build/app/outputs/flutter-apk/app-debug.apk` — install with `adb install -r` or share the file. **Do not commit** `build/`; it stays ignored by git.

### Android release — APK (install / sideload)

```bash
flutter build apk --release
```

- Output: `build/app/outputs/flutter-apk/app-release.apk`
- Smaller per-CPU builds (optional):

```bash
    flutter build apk --release --split-per-abi
```

- Outputs under `build/app/outputs/flutter-apk/` as `app-*-release.apk` (armeabi-v7a, arm64-v8a, x86_64).

**Signing:** Play Store and serious sideload need a **release keystore**. Configure in `android/app/build.gradle.kts` (or `.gradle`) via `key.properties` pointing to your keystore — see [Flutter Android deployment](https://docs.flutter.dev/deployment/android).

### Android release — App Bundle (Google Play)

```bash
flutter build appbundle --release
```

- Output: `build/app/outputs/bundle/release/app-release.aab`
- Upload **`.aab`** in Play Console (not the raw APK for default Play distribution).

### iOS release — IPA (TestFlight / App Store)

Prerequisites: **Apple Developer** account, **signing certificates**, **provisioning profiles**, Xcode installed.

```bash
cd ios && pod install && cd ..
flutter build ipa
```

- Flutter drives **Xcode archive** flow; output is typically under `build/ios/ipa/`.
- Alternative: open **`ios/Runner.xcworkspace`** in Xcode → **Product → Archive** → Distribute App.

**Versioning:** bump `version:` in `pubspec.yaml` (`major.minor.patch+buildNumber` maps to iOS `CFBundleShortVersionString` / `CFBundleVersion`).

### Pre-release checks (all platforms)

```bash
flutter pub get
dart analyze --fatal-infos
flutter test
```

## Important Config Files

- `pubspec.yaml`
- `analysis_options.yaml`
- `ios/Runner/Info.plist`
- `ios/Podfile`
- `android/app/src/main/AndroidManifest.xml`

---

## Known Constraints

- FFmpeg plugin work runs via platform channels; Dart isolate migration is non-trivial.
- Very large media processing is still device/hardware bounded.
- Some export behavior is intentionally fallback-first for reliability.

---

## Prioritized Backlog

### High
- Add integration tests for permission dialog debounce and deny->settings loops.
- Complete structured logging pass for remaining catch blocks.
- Add explicit sqflite migration tests for future schema changes.

### Medium
- Add HTTP retry/backoff + optional offline caching policy.
- Add cancellation support for long-running user actions.
- Expand tablet accessibility + responsive QA matrix.

### Low
- Broader performance telemetry for heavy render/export flows.
- Additional resilience fallback paths for secure storage edge cases.

---

## Contribution Rules

- Reuse `AppTheme` tokens and shared UI helpers.
- Keep GetX DI/state patterns consistent with `app_registry.dart`.
- Guard platform-specific code paths and provide fallbacks.
- Add tests when changing behavior in camera/permission/export/report flows.

---

## Release Verification Checklist

- [ ] `flutter test` passes
- [ ] `dart analyze --fatal-infos` passes
- [ ] Android capture -> annotate -> export/report works
- [ ] iOS capture -> annotate -> Photos/save-share fallback works
- [ ] Report PDF displays `µm`/`nm` correctly
- [ ] Settings reset actions behave correctly
