# Async Actions

`AsyncActionController` provides simple, named async locks for UI actions.

## Use

- `isRunning(key)` tells you whether an action is active.
- `run(key, action)` blocks re-entry until the action finishes.

## Widgets

- `ResponsiveActionButton`
- `ResponsiveIconButton`
- `ResponsiveTap`

These widgets:

- disable immediately on tap
- show a spinner while busy
- re-enable after completion
- work well with GetX and `Obx`

## Example

```dart
final asyncActions = Get.put(AsyncActionController(), permanent: true);

ResponsiveActionButton(
  actionKey: 'download',
  asyncController: asyncActions,
  onPressed: () async => reportController.downloadReport(...),
  child: const Text('Download'),
)
```
