# Fix Summary

This branch consolidates the main save, download, camera, and annotation fixes for the Flutter app.

## What changed

- Report save/download flow now uses shared GetX controller methods.
- `Save` writes only to the app internal folder.
- `Download` writes to both the app folder and the public Downloads folder.
- File saving uses atomic writes and filename collision handling.
- Camera and annotation rendering now use shared helpers for transform math and preview sizing.
- Measurement labels are clamped inside bounds and stay readable.
- Marked previews avoid double-applying annotations when media is already baked.

## Tradeoffs / edge cases

- On some devices, access to the public Downloads folder may still depend on Android storage policy and OEM file-manager behavior.
- If Downloads cannot be created, the app falls back to `MyAppDownloads`.
- Network image sources inside the PDF report are not embedded unless the bytes are available locally.
- The camera implementation is still split across two legacy screens while the controller layer is introduced gradually.

## How to verify

Run:

```bash
flutter analyze
flutter test
```

Recommended manual QA:

- Low-end phone
- Flagship phone
- Tablet in landscape

Check:

- Save button stores the report only in the app folder
- Download button stores to Downloads and app folder
- Markings do not duplicate in saved or downloaded reports
- Measurement labels remain upright and readable
- Camera preview starts and resumes without crashing
