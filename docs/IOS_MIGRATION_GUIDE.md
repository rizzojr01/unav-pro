# iOS App Migration Guide: Personal → TaggedWeb Inc. (Org)

## Overview

This guide covers migrating a Flutter iOS app from a personal Apple Developer account to the **TaggedWeb Inc.** organization account (`3AKM83DNCV`). It includes all steps, files to change, and common issues encountered during the migration.

**Team ID:** `3AKM83DNCV`
**Org Name:** TaggedWeb Inc.

---

## Prerequisites

Before starting, have these ready:

1. Access to the TaggedWeb Inc. Apple Developer account
2. Access to the app's source code repository
3. Mac with Xcode installed
4. Flutter SDK installed (with FVM if applicable)

---

## Step-by-Step Migration

### 1. Register Devices for Automatic Signing (Local Dev)

**Where:** [developer.apple.com/account/resources/devices](https://developer.apple.com/account/resources/devices)

**Why:** Xcode automatic signing needs at least one registered device to generate provisioning profiles. Without this, automatic signing fails with "Your team has no devices from which to generate a provisioning profile."

**Note:** This is only needed for local development (running on physical devices). For TestFlight/App Store, you use manual signing which doesn't require registered devices.

**Register your Mac:**
```bash
# Get Mac UDID
system_profiler SPHardwareDataType | grep "Hardware UUID"
```

**Register test iPhones/iPads:**
- Connect via USB → open Finder → click on device → click serial number until UDID appears
- Or: Xcode → Window → Devices and Simulators → select device → copy Identifier

**Acceptance Criteria:**
- [ ] At least one device registered under TaggedWeb Inc.
- [ ] Xcode → Runner target → Signing & Capabilities → Debug tab shows TaggedWeb Inc. with automatic signing

---

### 2. Create Distribution Certificate

**Where:** [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)

**Why:** App Store/TestFlight requires an Apple Distribution certificate signed by Apple. Development certificates won't work for archives.

**Steps:**
1. Go to Certificates → click **+**
2. Select **Apple Distribution** (scroll down to "Distribution" section, not "Software")
3. Create a CSR (Certificate Signing Request):
   ```bash
   openssl req -new -newkey rsa:2048 -nodes -keyout distribution.key -out distribution.csr -subj "/CN=YourAppName Distribution/O=TaggedWeb Inc./C=US"
   ```
4. Upload the `.csr` file to Apple's portal
5. Download the `.cer` file
6. Install the certificate:
   ```bash
   # Convert DER to PEM
   openssl x509 -in ios_distribution.cer -inform DER -outform PEM -out cert.pem

   # Create .p12 with cert + key
   openssl pkcs12 -export -legacy -in cert.pem -inkey distribution.key -out distribution.p12

   # Import to Keychain (enter a password when prompted)
   security import distribution.p12 -k ~/Library/Keychains/login.keychain-db -P YOUR_PASSWORD -T /usr/bin/codesign -T /usr/bin/security
   ```
7. **Fix trust settings** (important!):
   - Open **Keychain Access**
   - Find the distribution certificate
   - Double-click → expand **Trust**
   - Set "When using this certificate" to **"Use System Defaults"** (NOT "Always Trust")
   - Close → enter Mac password

**Acceptance Criteria:**
- [ ] Certificate created under TaggedWeb Inc. (team `3AKM83DNCV`)
- [ ] Certificate installed in Keychain with private key
- [ ] Trust settings = "Use System Defaults"
- [ ] `security find-identity -v -p codesigning` shows the distribution identity

---

### 3. Create App Store Provisioning Profile

**Where:** [developer.apple.com/account/resources/profiles](https://developer.apple.com/account/resources/profiles)

**Why:** The archive/export process needs a provisioning profile to sign the app for distribution.

**Steps:**
1. Go to Profiles → click **+**
2. Select **App Store Connect** (under Distribution section)
3. Select your app (`com.yourapp.bundleid`)
4. Select the distribution certificate from Step 2
5. Make sure **Push Notifications** capability is enabled (if your app uses push)
6. Name the profile something memorable (e.g., `your-app-store`)
7. Download the `.mobileprovision` file
8. Install:
   ```bash
   # Copy to provisioning profiles directory
   cp yourprofile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

   # Get UUID
   security cms -D -i yourprofile.mobileprovision | plutil -extract UUID raw -

   # Rename to UUID (required by Xcode)
   mv ~/Library/MobileDevice/Provisioning\ Profiles/yourprofile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/UUID.mobileprovision
   ```

**Acceptance Criteria:**
- [ ] Profile type: **App Store Connect** (not Ad Hoc or Development)
- [ ] App ID matches your bundle ID
- [ ] Certificate matches the one from Step 2
- [ ] Capabilities include Push Notifications (if needed)
- [ ] Profile installed in `~/Library/MobileDevice/Provisioning Profiles/`

---

### 4. Update Xcode Project Settings

**File:** `ios/Runner.xcodeproj/project.pbxproj`

**Changes needed:**

**Bundle Identifier (all configs):**
```
PRODUCT_BUNDLE_IDENTIFIER = com.your.newbundleid;
```

**Team ID (all configs):**
```
DEVELOPMENT_TEAM = 3AKM83DNCV;
```

**Release and Profile configs - add these:**
```
CODE_SIGN_IDENTITY = "Apple Distribution";
CODE_SIGN_STYLE = Manual;
PROVISIONING_PROFILE_SPECIFIER = "your-profile-name";
```

**Keep Debug config as-is (for local dev):**
```
CODE_SIGN_IDENTITY = "Apple Development";
CODE_SIGN_STYLE = Automatic;
```

**Update project-level signing identity:**
```
"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";
```

**Quick way to update (sed commands):**
```bash
# Update team ID
sed -i '' "s/DEVELOPMENT_TEAM = YOUR_OLD_TEAM;/DEVELOPMENT_TEAM = 3AKM83DNCV;/g" ios/Runner.xcodeproj/project.pbxproj

# Update bundle ID
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com.old.bundleid;/PRODUCT_BUNDLE_IDENTIFIER = com.new.bundleid;/g" ios/Runner.xcodeproj/project.pbxproj
```

**Acceptance Criteria:**
- [ ] All `DEVELOPMENT_TEAM` = `3AKM83DNCV`
- [ ] All `PRODUCT_BUNDLE_IDENTIFIER` = new bundle ID
- [ ] Release/Profile have `CODE_SIGN_STYLE = Manual`
- [ ] Release/Profile have `PROVISIONING_PROFILE_SPECIFIER` set

---

### 5. Update Entitlements

**File:** `ios/Runner/Runner.entitlements`

Change `aps-environment` from `development` to `production`:
```xml
<key>aps-environment</key>
<string>production</string>
```

**File:** `ios/Runner/RunnerDebug.entitlements`

Keep as-is (or empty) for local development.

---

### 6. Update GitHub Secrets (For CI/CD)

**Where:** GitHub repo → Settings → Secrets and variables → Actions

**Secrets to update:**
- `APP_STORE_CONNECT_API_KEY_KEY_ID` — generate new API key in App Store Connect → Users and Access → Integrations → Keys
- `APP_STORE_CONNECT_API_KEY_ISSUER_ID` — shown in same location
- `APP_STORE_CONNECT_API_KEY_KEY` — download the `.p8` key file
- `MATCH_SSH_PRIVATE_KEY` — SSH key for accessing the match certificates repo
- `MATCH_PASSWORD` — password for fastlane match
- `APPLE_ID` — org's Apple ID email

**Update Fastlane configs:**

**`.github/app_config.json`:**
```json
{
  "team_id": "3AKM83DNCV",
  "app_store_connect_team_id": "3AKM83DNCV",
  "itc_team_id": "3AKM83DNCV",
  "bundle_id": "com.your.newbundleid"
}
```

**`ios/fastlane/Appfile`:**
```ruby
app_identifier("com.your.newbundleid")
apple_id("org-email@example.com")
team_id("3AKM83DNCV")
itc_team_id("3AKM83DNCV")
```

---

## Build & Upload to TestFlight

### Manual Build (First Time)

1. Open Xcode → Product → Archive
2. In Organizer: Distribute App → App Store Connect → Export
3. Open Transporter → drag `.ipa` → Deliver

### Command Line Build

```bash
# Build unsigned
fvm flutter build ios --release --no-codesign

# Archive with xcodebuild
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
  -archivePath build/Runner.xcarchive \
  -destination "generic/platform=iOS" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="iPhone Distribution: TaggedWeb Inc. (3AKM83DNCV)" \
  DEVELOPMENT_TEAM=3AKM83DNCV

# Create ExportOptions.plist
cat > ios/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>3AKM83DNCV</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.your.newbundleid</key>
        <string>your-profile-name</string>
    </dict>
</dict>
</plist>
EOF

# Export IPA
xcodebuild -exportArchive \
  -archivePath ~/Library/Developer/Xcode/Archives/Runner.xcarchive \
  -exportPath ~/Desktop/ipa-output \
  -exportOptionsPlist ios/ExportOptions.plist
```

---

## Common Issues & Fixes

### "Your team has no devices from which to generate a provisioning profile"
**Cause:** No devices registered for automatic signing.
**Fix:** Register at least one device UDID (Step 1).

### "Invalid trust settings. Restore system default trust settings for certificate"
**Cause:** Certificate trust set to "Always Trust" instead of "Use System Defaults".
**Fix:** Keychain Access → double-click certificate → Trust → set to "Use System Defaults".

### "No signing certificate 'iOS Distribution' found"
**Cause:** Distribution certificate not installed or not paired with private key.
**Fix:** Re-import the `.p12` file (Step 2).

### "No profiles matching 'bundleid' were found"
**Cause:** Provisioning profile not installed.
**Fix:** Double-click `.mobileprovision` file to install (Step 3).

### "Communication with Apple failed"
**Cause:** Xcode trying automatic signing for archive (needs device).
**Fix:** Use manual signing for Release/Profile configs (Step 4).

### "FirebaseCrashlytics does not support provisioning profiles"
**Cause:** Passing `-global` build settings to xcodebuild leaks to Pod targets.
**Fix:** Set `PROVISIONING_PROFILE_SPECIFIER` only in project.pbxproj, not as xcargs.

### Certificate not showing in keychain identities
**Cause:** Private key not paired with certificate.
**Fix:** Create `.p12` with both cert and key, then import.

### Flutter forces automatic signing
**Cause:** Flutter overrides project signing settings during build.
**Fix:** Use `flutter build ios --release --no-codesign` then archive with `xcodebuild` directly.

---

## Files Changed Summary

| File | What to Change |
|------|---------------|
| `ios/Runner.xcodeproj/project.pbxproj` | Team ID, Bundle ID, signing settings |
| `ios/Runner/Runner.entitlements` | `aps-environment` → `production` |
| `.github/app_config.json` | Team IDs, bundle ID (if using CI) |
| `ios/fastlane/Appfile` | Team ID, bundle ID, Apple ID |
| `ios/ExportOptions.plist` | Team ID, profile name, method |

---

## Checklist for New App Migration

- [ ] Get new bundle ID from Apple Developer portal (App IDs)
- [ ] Register devices under TaggedWeb Inc.
- [ ] Create distribution certificate under TaggedWeb Inc.
- [ ] Create App Store provisioning profile for new bundle ID
- [ ] Download and install certificate + profile
- [ ] Fix certificate trust settings (Use System Defaults)
- [ ] Update `project.pbxproj` with new team ID, bundle ID, signing settings
- [ ] Update `Runner.entitlements` (aps-environment → production)
- [ ] Update `.github/app_config.json` (if using CI)
- [ ] Update `ios/ExportOptions.plist` (if using CI)
- [ ] Build unsigned: `flutter build ios --release --no-codesign`
- [ ] Archive with xcodebuild
- [ ] Export IPA
- [ ] Upload via Transporter
- [ ] Verify in App Store Connect → TestFlight
