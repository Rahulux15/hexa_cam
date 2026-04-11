#!/usr/bin/env bash
# Newer Xcode / iOS SDKs may not expose AVCaptureSession.wasInterruptedNotification
# and runtimeErrorNotification to Swift (see flutter/flutter#183380). Pub versions
# including camera_avfoundation 0.10.1 still reference the old symbols — replace
# with NSNotification.Name("...") so iOS release builds succeed.
set -euo pipefail

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
PUB_HOSTED="$PUB_CACHE/hosted/pub.dev"
if [[ ! -d "$PUB_HOSTED" ]]; then
  echo "patch_camera_avfoundation_xcode: no pub cache at $PUB_HOSTED (skip)"
  exit 0
fi

patched=0
while IFS= read -r -d '' f; do
  [[ -f "$f" ]] || continue
  if ! grep -q 'AVCaptureSession\.wasInterruptedNotification' "$f" 2>/dev/null; then
    continue
  fi
  echo "patch_camera_avfoundation_xcode: patching $f"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' 's/AVCaptureSession\.wasInterruptedNotification/NSNotification.Name("AVCaptureSessionWasInterruptedNotification")/g' "$f"
    sed -i '' 's/AVCaptureSession\.runtimeErrorNotification/NSNotification.Name("AVCaptureSessionRuntimeErrorNotification")/g' "$f"
  else
    sed -i 's/AVCaptureSession\.wasInterruptedNotification/NSNotification.Name("AVCaptureSessionWasInterruptedNotification")/g' "$f"
    sed -i 's/AVCaptureSession\.runtimeErrorNotification/NSNotification.Name("AVCaptureSessionRuntimeErrorNotification")/g' "$f"
  fi
  patched=$((patched + 1))
done < <(find "$PUB_HOSTED" -path '*/camera_avfoundation-*/ios/camera_avfoundation/Sources/camera_avfoundation/DefaultCamera.swift' -print0 2>/dev/null || true)

if [[ "$patched" -eq 0 ]]; then
  echo "patch_camera_avfoundation_xcode: no DefaultCamera.swift needed patching (already patched or no camera_avfoundation)"
fi
