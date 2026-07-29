# OMR Scanner (Flutter)

Offline exam/OMR management app: create exams, set a multi-answer-capable
answer key, calibrate the bubble grid once per sheet layout, then scan
sheets with a **live camera guide + auto-capture** and get instant scoring
stored per roll number.

## 1. Setup

This zip contains only the `lib/` source + `pubspec.yaml` (no `android/`,
`ios/` folders — generate those with your local Flutter SDK).

```bash
flutter create --org com.yourcompany omr_scanner
# replace the generated lib/ and pubspec.yaml with the ones from this zip
cd omr_scanner
flutter pub get
```

**Android** — `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```
Also set `minSdkVersion` to at least 21 in `android/app/build.gradle` (the
`camera` plugin requires it).

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan OMR answer sheets</string>
```

Run: `flutter run`

## 2. No calibration — the app aligns itself

You were right that calibration shouldn't exist. Your sheet format is fixed,
so the layout is now **measured once and baked into the app**
(`lib/services/sheet_template.dart`), and each photo is aligned to it
automatically.

### How the alignment works
Your sheet already carries registration marks: the **rows of solid black
rectangles** printed above and below the answer block. They exist precisely
so a machine can find the grid. The app:

1. Isolates black ink using the **red channel** (your form is printed in red,
   so red printing goes near-white there and vanishes; only black ink
   survives — the timing marks and the students' pen marks).
2. Runs connected-component analysis and keeps blobs matching the timing
   marks' shape signature (solid, taller than wide, size relative to the
   frame). The reference sheet has 45 top and 44 bottom.
3. Splits them into the top and bottom bands at the largest vertical gap,
   and takes the outermost mark of each band as the four anchor points.
4. Builds a **projective transform (homography)** from the unit square onto
   those four anchors, and projects every template coordinate through it.

Because it's a full homography and not a rectangle, it corrects rotation,
tilt and perspective automatically. Shoot the sheet handheld at an angle and
it still lands on the bubbles.

### Why not OCR
OCR recognises **text characters**. A filled bubble is not a character, and
neither is a timing mark — ML Kit and Tesseract return nothing useful for
either. No commercial OMR system uses OCR for this; they all use registration
marks plus fill measurement, which is what's implemented here. Using the
sheet's own printed marks is both faster and far more reliable than trying to
OCR anything on the page.

### The template
Measured directly off the reference sheet you supplied:
- 3 answer columns (Q1-17, Q18-34, Q35-50), 4 options each (ক/খ/গ/ঘ)
- 17 row positions, normalised against the timing-mark anchors
- 6-digit roll-number grid, 10 rows of digit bubbles

Verified end-to-end against your sample: it correctly read Q1-30 as marked,
Q31-50 as blank, and flagged Q15, Q16 and Q23 as multi-marked — which matches
the sheet.

If you ever change the printed layout, only `sheet_template.dart` needs new
numbers; nothing else changes.

## 3. Roll numbers are read automatically

Your sheet bubbles the roll number, so the app reads it — no typing. Each of
the 6 digit columns is scanned for its filled bubble. If a column is blank or
has two marks, the field is left for you to fill in, flagged in orange. The
value is always shown editable in the review screen before saving.

## 4. Getting exact results

No automatic OMR is 100% on every sheet — smudges, half-erased marks and
double-marks are real. The way to guarantee the stored data is exact is
**auto-detect + confirm**, which is what happens:

- Every scan opens a **Review screen** before anything is saved.
- The **annotated photo** (pinch-zoomable) shows blue boxes on the timing
  marks it locked onto, and a circle at every sampled bubble: **green** =
  read filled, **red** = empty, **yellow** = borderline.
- It **auto-flags** what's worth checking — borderline reads, blanks, and
  multi-marks where the key expects one answer — and opens filtered to only
  those.
- Every option is one tap to toggle; long-press shows the measured fill
  percentage.
- Confirm saves and drops you straight back into the live camera for the next
  sheet.

## 5. If something reads wrong

Exam → **Test Detection**, shoot a sheet, zoom in:

- **No blue boxes / "could not find registration marks"** → the black mark
  strips above and below the answer block weren't both fully in frame, or the
  shot is too dark. Fit the whole sheet in the guide; use the torch toggle.
- **Blue boxes correct but circles off the bubbles** → the sheet layout
  differs from the baked-in template; `sheet_template.dart` needs remeasuring.
- **Circles on the bubbles but wrong fill reads** → a non-black pen was used,
  or the lighting is washing the marks out.

## 6. Detection pipeline summary

| Stage | Method |
|---|---|
| Isolate marks | Red-channel split (red print drops out, black ink stays) |
| Find anchors | Connected components + shape filter on timing marks |
| Align | 4-point homography, unit square → anchor quad |
| Locate bubbles | Baked template coordinates projected through the homography |
| Measure fill | Ink fraction inside 0.68× the bubble radius |
| Decide | Otsu threshold over fill ratios, per sheet |
| Confirm | Review screen with annotated overlay + tap-to-correct |

All pixel work runs in a background isolate via `compute()`, so the live
camera preview stays smooth.

## 7. Remaining limitations

- **Sheet must be upright.** A 180°-rotated sheet will register upside down;
  there's no orientation check yet. Adding one is straightforward (the roll
  block is above the top band, so a sanity check on its content would do it).
- **Auto-capture triggers on stillness**, not on true document detection — it
  waits until the frame stops moving. Works well with the guide frame, but a
  real paper-edge detector would be a further improvement.
- **Both timing-mark strips must be visible.** If the sheet is cropped, the
  scan fails cleanly with a message rather than producing wrong numbers.
- **No cloud sync** — local SQLite only.

## 8. File map

```
lib/
  models/exam.dart              Exam + AnswerKey
  services/sheet_template.dart  Baked-in sheet layout (the thing that replaced calibration)
  models/student_result.dart    Per-scan result record
  db/db_helper.dart             SQLite (exams, results) incl. v1->v2 migration
  services/omr_processor.dart   Anchor detection + homography + fill measurement + grading
  screens/exam_list_screen.dart      Home: list + add exam
  screens/add_exam_screen.dart       New exam form
  screens/exam_detail_screen.dart    Hub: answer key / calibrate / scan / history
  screens/answer_key_screen.dart     Checkbox answer key entry
  screens/live_scan_screen.dart      Live camera, guide overlay, auto-capture
  screens/review_screen.dart         Confirm/correct detected marks before saving
  screens/detection_test_screen.dart Diagnostic: see anchors + sampled bubbles
  screens/history_screen.dart        All results for an exam
  screens/student_detail_screen.dart Per-question right/wrong breakdown
```
