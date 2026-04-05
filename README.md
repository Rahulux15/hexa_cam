# demo_app

Hexa-Cam Flutter app for Android, iOS, web, and desktop.

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
