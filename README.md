# demo_app

Hexa-Cam Flutter app for Android, iOS, web, and desktop.

## Latest Update (2026-04-08)

- Annotation placement pipeline hardened so capture/view/export/report coordinates stay aligned.
- Report preview/PDF now reuses deterministic marked-media flow to avoid missing overlays.
- Viewer clear-markings flow fixed (live canvas + persisted state now clear together).
- Toast/message system refreshed with progress support and clearer save/download destinations.
- Splash/login UI animations improved; splash remains cold-start only (no splash on resume).
- Android release startup stability preserved with shrinkers disabled in `android/app/build.gradle.kts`.
- iOS parity note: orientation and media permission declarations are aligned in `ios/Runner/Info.plist`; shared Flutter logic changes apply to both Android and iOS.

## Build-Time API URL

The API base URL is configured at build time so it is not hardcoded in the app service layer.

### Flutter builds

Pass the API URL with `--dart-define`:

```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example.com/api
flutter build ios --release --dart-define=API_BASE_URL=https://your-api.example.com/api
```

### Android local override

You can also set the value in `android/local.properties` for Android builds:

```properties
API_BASE_URL=https://your-api.example.com/api
```

The app falls back to `https://api.quasmoindianmicroscope.com/api` if no override is provided.

For a template, copy [`android/local.properties.example`](d:\Hexa-cam\demo_app\android\local.properties.example) to `android/local.properties` and fill in your local values.

## Launch Notes

- Android debug: `flutter run`
- Android release APK: `flutter build apk --release`
- Android release bundle: `flutter build appbundle --release`
- iOS: run from Xcode on macOS after `flutter pub get` and `pod install`
- iOS IPA (macOS only): `flutter build ipa` (or archive from Xcode Organizer)
