# APK Size Guidance

Use this project command for smaller Android release outputs without removing app features:

- `flutter build apk --release --split-per-abi`
- `flutter build appbundle --release`

The biggest size driver in this app is `ffmpeg_kit_flutter_new_full`.
If you keep that package, a very large APK is expected.
