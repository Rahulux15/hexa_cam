# Async Action Migration

Use `AsyncActionController` when a control triggers async work and should ignore rapid re-taps.

## Recommended pattern

```dart
final asyncActions = Get.put(AsyncActionController(), permanent: true);

ResponsiveActionButton(
  actionKey: 'save_report',
  asyncController: asyncActions,
  onPressed: () async {
    await reportController.saveReport(...);
  },
  child: const Text('Save'),
)
```

## Incremental migration

- Start with the most error-prone buttons: save, download, capture, upload.
- Keep the existing business logic inside the callback.
- Use distinct `actionKey` values for independent actions.
- Leave non-async controls unchanged.

## Notes

- The wrapper blocks immediate re-entry.
- Each action key is tracked independently.
- For long tasks, pair this with a top-level overlay if needed.
