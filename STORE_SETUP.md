# Store + IAP setup (Android & iOS)

App IDs used in this project:

| Platform | ID |
|---|---|
| Android `applicationId` | `com.omrscanner.raj` |
| iOS Bundle ID | `com.omrscanner.raj` |
| IAP product (non-consumable) | `premium_unlock` |
| Display name | OMR Scanner |

Change free limits anytime in `lib/services/premium_config.dart`.

## Current free vs Premium

**Free**
- 1 exam (`freeExamLimit = 1`)
- 20 scans per calendar month (`freeScansPerMonth = 20`)
- CSV export
- Answer key, scan, review, history, Test Detection

**Premium (one-time unlock)**
- Unlimited exams & scans
- Exam grading settings
- Excel + PDF export

To change limits, edit:

```dart
static const int freeExamLimit = 1;
static const int freeScansPerMonth = 20;
```

Then rebuild. Already-saved local premium status is unchanged.

---

## 1. Google Play — one-time IAP

1. Create app in [Play Console](https://play.google.com/console) with package `com.omrscanner.raj`.
2. Complete **Store listing**, **App content** (privacy policy URL, Data safety), **Content rating**.
3. **Monetize with Play → Products → In-app products → Create product**
   - Product ID: `premium_unlock` (must match code exactly)
   - Type: **One-time / Non-consumable**
   - Name: `Premium Unlock`
   - Description: Unlimited exams, scans, grading settings, Excel & PDF export
   - Price: e.g. `$3.99` (set regional prices as needed)
   - Activate the product
4. **License testing**: Settings → License testing → add Gmail accounts that will test purchases without being charged.
5. Upload an **AAB** to Internal testing / Closed testing (not debug-signed — see signing below).
6. Install from the testing track on a license-tester device and buy Premium.

### Android release signing

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties` (gitignored):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

A local `android/upload-keystore.jks` + `android/key.properties` may already exist for release builds.
**Change the default passwords before publishing**, back up the `.jks`, and never commit them.

Then:

```bash
flutter build appbundle --release
flutter build apk --release
```

- AAB path: `build/app/outputs/bundle/release/app-release.aab` → upload to Play
- APK path: `build/app/outputs/flutter-apk/app-release.apk` → sideload / direct share

**Back up the `.jks` and passwords.** Losing them means you cannot update the same Play listing.

---

## 2. Apple App Store — one-time IAP

1. Enroll in [Apple Developer Program](https://developer.apple.com/programs/) ($99/year).
2. [App Store Connect](https://appstoreconnect.apple.com) → My Apps → New App
   - Bundle ID: `com.omrscanner.raj` (register in Certificates, Identifiers & Profiles first)
3. Xcode → open `ios/Runner.xcworkspace`
   - Signing & Capabilities → Team
   - Add capability: **In-App Purchase**
4. App Store Connect → your app → **Monetization → In-App Purchases → Create**
   - Type: **Non-Consumable**
   - Product ID: `premium_unlock`
   - Reference name: Premium Unlock
   - Price: e.g. Tier matching ~$3.99
   - Localization: display name + description
   - Submit with the app version (or for review with first binary)
5. Agreements: **Paid Applications Agreement**, banking, tax — required before IAP works.
6. Sandbox: Users and Access → Sandbox → Testers → create a Sandbox Apple ID. Sign out of real Apple ID on device, run TestFlight/dev build, purchase with Sandbox ID.
7. App must include **Restore purchases** (already in App settings + Paywall).

### iOS privacy strings (already in Info.plist)

- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`

---

## 3. Privacy policy (required by both stores)

Host a short page that says:

- App scans OMR sheets using camera / gallery photos
- Processing is on-device
- Results stored locally on the phone
- Purchases handled by Google Play / Apple
- No account required (unless you add one later)
- Contact email

Put the URL in Play Data safety + App Store Privacy Policy field.

---

## 4. Listing copy (short)

**Title:** OMR Scanner  

**Subtitle:** Offline answer-sheet grading  

**Description (draft):**  
Scan OMR answer sheets with your phone. Auto-aligns to printed timing marks, reads bubbles, grades against your answer key, and exports results. Works offline.

Free: 1 exam, 20 scans/month, CSV export.  
Premium (one-time): unlimited exams & scans, grading rules, Excel & PDF export.

---

## 5. Test checklist before submit

- [ ] Free: cannot create 2nd exam → paywall
- [ ] Free: 21st scan in a month → paywall
- [ ] Free: Excel/PDF → paywall; CSV works
- [ ] Free: Exam settings → paywall
- [ ] Buy Premium (test track / Sandbox) → all unlock
- [ ] Restore purchases on second device / reinstall
- [ ] Debug builds: `[Debug] Unlock Premium` only in debug (not in release)

---

## 6. Useful commands

```bash
# Release Android
flutter build appbundle --release
flutter build apk --release

# iOS (on macOS with Xcode)
flutter build ipa --release
```

Product ID constant: `PremiumConfig.premiumProductId` in `lib/services/premium_config.dart`.
