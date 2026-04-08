# Hexa-Cam E2E QA Checklist (Pass/Fail)

Use this checklist on each target:
- Android phone
- Android tablet
- iPhone
- iPad
- Web (Chrome)

For every test item, mark:
- `[PASS]`
- `[FAIL]`
- Notes (screenshot + short log)

---

## 0) Test Matrix

Record before starting:
- Device model:
- OS version:
- Build type: Debug / Release / Web
- App version shown on login footer:
- Camera permission state: Fresh install / Already granted

---

## 1) App Startup + Login

### 1.1 Launch Stability
- Open app from cold start.
- Expected:
  - Splash loads.
  - No black screen.
  - Auto route works (login/folders based on session).

### 1.2 Login Screen UX
- Verify terms checkbox default checked.
- Uncheck terms.
- Expected:
  - Sign In button disabled + disabled color visible.
- Re-check terms.
- Expected:
  - Sign In button active color returns.
- Verify footer text + app version shown.

### 1.3 Login Behavior
- Empty email -> tap sign in.
- Expected:
  - validation message appears.
- Valid email+password.
- Expected:
  - login success, route to folders.

---

## 2) Folder + Navigation

### 2.1 Folder Open + Back
- Open a folder.
- Tap back.
- Expected:
  - returns correctly every time.
  - no dead back button.

### 2.2 Media Grid/List
- Check image cards render preview.
- Check video cards render thumbnail + play icon.
- Expected:
  - no blank placeholders for newly captured media.

---

## 3) Camera Layout + Controls (All Orientations)

Run in both portrait and landscape.

### 3.1 Rail Alignment
- Portrait: top and bottom rails.
- Landscape: left and right rails.
- Expected:
  - rails are centered and not clipped.
  - no overlap with capture/record buttons.
  - no overlap with safe area/nav bar.

### 3.2 Back Button Reliability
- Tap camera back from portrait and landscape.
- Expected:
  - always navigates back to previous page (or folders fallback).

### 3.3 Tool Buttons
- Check each:
  - zoom in/out
  - settings/tune
  - capture
  - video start/stop
  - draw/tools panel
  - lock
  - hold/pause
  - move
  - aspect ratio toggle 4:3 / 16:9
- Expected:
  - no dead buttons.
  - visible state changes.

---

## 4) Annotation Behavior (Critical)

### 4.1 Live Annotation Draw
- Draw line/arrow/circle/text.
- Expected:
  - smooth stroke (no heavy lag).
  - stroke thickness readable.
  - measurement label visible.

### 4.2 Move/Lock/Hold
- Draw mark.
- Enable move and drag mark.
- Expected:
  - mark moves correctly.
- Enable lock and try edit.
- Expected:
  - editing blocked.
- Enable hold/pause and try edit/capture.
- Expected:
  - behavior follows app rule without freezing.

### 4.3 Position Integrity
- Draw mark in live camera.
- Capture.
- Save.
- Download.
- Generate report.
- Expected:
  - mark coordinates remain consistent in all outputs.

---

## 5) Image Capture Flow

### 5.1 Capture Review Sheet
- Capture image.
- Expected:
  - review preview visible.
  - Download/Save/Create report actions visible and aligned.

### 5.2 Save (App Folder)
- Tap Save.
- Expected:
  - media saved in app folder.
  - success toast mentions app folder.

### 5.3 Download (Gallery/Device)
- Tap Download.
- Expected:
  - image in device gallery/download area.
  - success toast "Downloaded to Gallery" (or configured message).

---

## 6) Video Flow (Most Critical)

### 6.1 Record + Stop
- Start recording for 5-10 seconds.
- Stop recording.
- Expected:
  - review sheet opens.
  - no stuck spinner.

### 6.2 Video Preview in Review Sheet
- Expected:
  - thumbnail/frame visible (not blank icon-only unless web limitation).

### 6.3 Save Video (App Folder)
- Save video.
- Go to folder.
- Expected:
  - video card shows thumbnail.
  - opens in viewer.
  - playback works.

### 6.4 Download Video (Device)
- Download video from review/viewer.
- Expected:
  - file exists in device gallery/download.
  - overlays/markings are burned when expected.

### 6.5 Video Marking Visibility
- Add annotations before save/download.
- Expected:
  - downloaded video contains markings (if export path requires burn-in).
  - preview thumbnail is not empty.

---

## 7) Image/Video Viewer Page

### 7.1 Open Image Viewer
- Expected:
  - media renders.
  - edit tools open/close.
  - undo works.

### 7.2 Open Video Viewer
- Expected:
  - video initializes quickly.
  - play/pause works.
  - no black placeholder forever.

### 7.3 Viewer Download Sheet
- Save to gallery.
- Generate report.
- Expected:
  - actions complete with correct toasts.

---

## 8) Report Generation

### 8.1 Create Report from Image
- Generate report from marked image.
- Expected:
  - report preview shows image.
  - markings visible in preview card.

### 8.2 Create Report from Video
- Generate report from marked video.
- Expected:
  - still preview/thumbnail appears (not "No image available").
  - no crash.

### 8.3 Save vs Download Report
- Save report.
- Download report.
- Expected:
  - save writes app folder copy.
  - download writes device file.
  - success toasts are correct.

### 8.4 PDF Content Verification
- Open generated PDF.
- Expected:
  - Marked image visible.
  - Marking details populated.
  - measurement units show proper `μm` or `nm` based on calibration.

---

## 9) Calibration + Measurement

### 9.1 Calibration Setup
- Set calibration for a lens.
- Draw measured line.
- Expected:
  - unit/scale persists.
  - stamp label updates.

### 9.2 Unit Correctness
- Verify measurements in UI and report for:
  - `μm`
  - `nm`
- Expected:
  - no malformed unit text.

---

## 10) Lifecycle + Reliability

### 10.1 Background/Foreground
- Open camera, send app background, bring to foreground.
- Expected:
  - camera resumes.
  - no "camera stopped/retry" loop.

### 10.2 Rotation Stress
- Rotate portrait -> landscape -> portrait (3 cycles).
- Expected:
  - no overflow.
  - controls still tappable.
  - preview scales correctly.

### 10.3 Long Session
- 10+ captures + 3 videos + 2 reports in one session.
- Expected:
  - no significant lag spikes.
  - no crashes.

---

## 11) Release Build Verification

### 11.1 Install Release APK/IPA
- Clean install.
- Expected:
  - app starts normally.
  - no startup black screen.

### 11.2 Core Sanity
- Login.
- open folder.
- capture image.
- record video.
- generate/download report.
- Expected:
  - all complete successfully.

---

## 12) Failure Log Template

When a test fails, capture this:

- Checklist item ID: (example `6.3`)
- Device + OS:
- Build type:
- What happened:
- Expected:
- Screenshot/video:
- Console log snippet:
- Is it reproducible (Y/N):

---

## Recommended Execution Order

1. Android phone (release)  
2. Android tablet (release)  
3. iPhone (release)  
4. iPad (release)  
5. Web Chrome (latest build)

This order catches the highest-risk camera/video/storage issues first.
