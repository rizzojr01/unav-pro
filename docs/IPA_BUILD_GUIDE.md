# IPA Build & TestFlight Deployment Guide

This documents the full process used to merge branches, resolve conflicts, and build the IPA for TestFlight submission.

---

## 1. Branch Setup

```bash
# Current branch: migrate_to_new_org (org migration changes)
# Target to merge: main (has newer commits)
```

The `migrate_to_new_org` branch contained org migration changes. The `main` branch had additional features:
- Snap-to-route toggle for direction tracking
- Cache clearing for destinations and floor plans
- Improved error handling with user-friendly messages
- Cocoapods upgrade to 1.17.0

---

## 2. Fetch Latest & Merge

```bash
# Fetch all remote changes
git fetch origin

# Merge main into current branch
git merge origin/main --no-edit
```

### Conflict Resolution

One conflict in `lib/main.dart`:

```
<<<<<<< HEAD
=======
import 'package:smart_sense/core/network/api_client.dart';
>>>>>>> origin/main
```

**Resolution:** Keep the import — `ApiClient` is used at line 63 for the fire-and-forget API warm-up call. Without this import the build would fail.

```bash
# After resolving, stage and complete the merge
git add lib/main.dart
git commit --no-edit
```

---

## 3. Dependencies

```bash
flutter pub get
```

Resolved 100+ packages. No breaking dependency conflicts.

---

## 4. Certificate & Signing Check

### Available Certificates

```bash
security find-identity -v -p codesigning
```

Results:
| # | Identity | Type |
|---|----------|------|
| 1 | Apple Development: surendharkps@gmail.com | Development |
| 2 | Apple Distribution: Surendhar Palanisamy | Distribution |
| 3 | Apple Development: Surendhar Palanisamy | Development |
| 4 | Apple Development: Surendhar Palanisamy | Development |
| 5 | Apple Development: surendhar2k18@gmail.com | Development |
| 6 | iPhone Distribution: TaggedWeb Inc. (3AKM83DNCV) | Distribution |

### Project Signing Configuration

- **Bundle Identifier:** `com.pathlogic.pro`
- **Team ID:** `3AKM83DNCV` (TaggedWeb Inc.)
- **Export Method:** `app-store`
- **Signing Style:** `Automatic` (was `Manual` with missing profile "FOR PL PRO")

### Export Options (`ios/ExportOptions.plist`)

```xml
<key>method</key>
<string>app-store</string>
<key>provisioningProfiles</key>
<dict>
    <key>com.pathlogic.pro</key>
    <string>FOR PL PRO</string>
</dict>
<key>signingStyle</key>
<string>manual</string>
<key>teamID</key>
<string>3AKM83DNCV</string>
```

> The provisioning profile "FOR PL PRO" was not found on disk. Xcode's automatic signing handled this during archive.

---

## 5. MinimumOSVersion Fix

The first build succeeded but was **rejected by App Store Connect** with error `90068`:

> MinimumOSVersion too low. This app has a MinimumOSVersion of 13.0. Starting in Spring 2027, all iOS apps must have a MinimumOSVersion of 15.0 or later in order to be uploaded to App Store Connect or submitted for distribution.

### Fix

Two files were updated to change the deployment target from `13.0` to `15.0`:

**1. `ios/Runner.xcodeproj/project.pbxproj`** — all 3 occurrences:

```bash
# Before
IPHONEOS_DEPLOYMENT_TARGET = 13.0;

# After
IPHONEOS_DEPLOYMENT_TARGET = 15.0;
```

**2. `ios/Podfile`** — platform line:

```ruby
# Before
platform :ios, '13.0'

# After
platform :ios, '15.0'
```

---

## 6. Build the IPA

```bash
flutter build ipa --release --no-tree-shake-icons
```

### Build Output

```
Archiving com.pathlogic.pro...
Running Xcode build...
Xcode archive done.    90.6s

App Settings Validation:
  - Version Number: 1.0.9
  - Build Number: 28
  - Display Name: PathLogicPro
  - Deployment Target: 15.0
  - Bundle Identifier: com.pathlogic.pro

Building App Store IPA...    30.5s
Built IPA to build/ios/ipa (217.0MB)
```

### Output File

```
build/ios/ipa/PathLogicPro.ipa   (209 MB)
```

---

## 7. Upload to TestFlight

### Option A: Transporter (recommended)

1. Open **Transporter** on macOS ([App Store link](https://apps.apple.com/us/app/transporter/id1450874788))
2. Sign in with your Apple Developer account
3. Drag `build/ios/ipa/PathLogicPro.ipa` into Transporter
4. Click **Deliver**
5. Wait for processing (~10-30 min) on [App Store Connect](https://appstoreconnect.apple.com)
6. The build will appear under the app's TestFlight tab

### Option B: altool (CLI)

```bash
xcrun altool --upload-app \
  --type ios \
  -f build/ios/ipa/PathLogicPro.ipa \
  --apiKey YOUR_API_KEY \
  --apiIssuer YOUR_ISSUER_ID
```

Generate the API key at [App Store Connect > Users and Access > Keys](https://appstoreconnect.apple.com/access/integrations/api).

---

## 8. Post-Build Notes

- **Launch Image:** The build warns about using the default placeholder launch image. Replace it in `ios/Runner/Assets.xcassets/LaunchImage.imageset/` before App Store submission.
- **UIScene Migration:** A deprecation warning about UIScene lifecycle support — migration guide at https://flutter.dev/to/uiscene-migration. Not blocking, but should be addressed soon.
- **Pods:** Cocoapods 1.17.0 is being used (upgraded in main).
