# Regression Checklist

## Devices

- Low-end Android phone
- Flagship Android phone
- Tablet in landscape

## Report flow

- Save button is enabled and responsive.
- Download button is enabled and responsive.
- Save writes only to the app folder.
- Download writes to Downloads and app folder.
- Snackbar text is shown after each action.
- A second tap while saving is blocked.

## Media flow

- Captured image/video opens without duplicated markings.
- Saved media keeps markings in the correct orientation after rotate/flip/mirror.
- Measurement text remains upright.
- Calibration stamp does not overlap the annotation path.

## Camera flow

- Camera initializes on each device profile.
- Preview does not crash on rotation/resume.
- Preview remains responsive in portrait and landscape.
- No freeze when switching lenses or toggling transforms.

## File flow

- Download path resolves to public Downloads when available.
- Fallback path resolves to `MyAppDownloads` when needed.
- Saved file exists on disk and contains expected bytes.
