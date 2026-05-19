---
description: Build, sign, notarize, and distribute the Fikr Flutter macOS app
---

# Fikr — macOS Build, Sign & Notarize

Produces a notarized DMG for direct distribution (outside App Store), without "unidentified developer" warnings.

## Prerequisites

- **Apple Developer Program** (Team ID: `FBG8NKYPUJ`)
- **Developer ID Application** cert in Keychain
  - Identity: `Developer ID Application: Pretheesh Thomas (FBG8NKYPUJ)`
- **Notarytool credentials** in Keychain profile `notarytool-profile`
  - Apple ID: `me@bigmints.com` · Team ID: `FBG8NKYPUJ`
- **Developer ID provisioning profile** at `fikr.provisionprofile` (project root)
  - Contains `keychain-access-groups` entitlement for `flutter_secure_storage`

If credentials are not stored:
```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "me@bigmints.com" \
  --password "APP_SPECIFIC_PASSWORD" \
  --team-id "FBG8NKYPUJ"
```

### One-time headless codesign setup

```bash
security set-key-partition-list \
  -S "apple-tool:,apple:,codesign:" \
  -s -k "YOUR_LOGIN_PASSWORD" \
  -D "Developer ID Application: Pretheesh Thomas (FBG8NKYPUJ)" \
  -t private \
  ~/Library/Keychains/login.keychain-db
```

---

> **Before building:** bump `version` in `pubspec.yaml` (e.g. `1.0.4+5` → `1.0.5+6`).

## 1. Build the release macOS app

```bash
flutter build macos --release
```

## 2. Embed the provisioning profile

Required for `keychain-access-groups` (used by `flutter_secure_storage`). Must be embedded **before** re-signing.

```bash
cp fikr.provisionprofile \
  build/macos/Build/Products/Release/Fikr.app/Contents/embedded.provisionprofile
```

## 3. Re-sign with Developer ID (hardened runtime)

Uses `DeveloperID.entitlements` which has resolved keychain-access-groups value `FBG8NKYPUJ.com.bigmints.fikr`.

```bash
codesign --deep --force --options runtime \
  --sign "Developer ID Application: Pretheesh Thomas (FBG8NKYPUJ)" \
  --entitlements macos/Runner/DeveloperID.entitlements \
  build/macos/Build/Products/Release/Fikr.app
```

## 4. Verify the signature

```bash
codesign -dv --verbose=2 build/macos/Build/Products/Release/Fikr.app 2>&1 | grep -E "Authority|flags"
```

Expected: `Authority=Developer ID Application: Pretheesh Thomas (FBG8NKYPUJ)` · `flags=0x10000(runtime)`

## 5. Create DMG with Applications shortcut

```bash
mkdir -p /tmp/fikr-dmg-staging && \
  cp -R build/macos/Build/Products/Release/Fikr.app /tmp/fikr-dmg-staging/ && \
  ln -sf /Applications /tmp/fikr-dmg-staging/Applications && \
  hdiutil create -volname "Fikr" \
    -srcfolder /tmp/fikr-dmg-staging \
    -ov -format UDZO build/Fikr-macos.dmg && \
  rm -rf /tmp/fikr-dmg-staging
```

## 6. Notarize the DMG

```bash
xcrun notarytool submit build/Fikr-macos.dmg \
  --keychain-profile "notarytool-profile" --wait
```

Wait for `status: Accepted` (typically 2–10 minutes).

## 7. Staple the ticket

```bash
xcrun stapler staple build/Fikr-macos.dmg
```

## 8. Verify Gatekeeper

```bash
spctl -a -vv build/macos/Build/Products/Release/Fikr.app 2>&1
```

Expected: `source=Notarized Developer ID`

## Output

```
build/Fikr-macos.dmg
```

## Key Files

| File | Purpose |
|---|---|
| `macos/Runner/Release.entitlements` | App Store entitlements (Xcode variables) |
| `macos/Runner/DeveloperID.entitlements` | Developer ID entitlements (resolved values) |
| `macos/Runner/DebugProfile.entitlements` | Debug/profile entitlements |
| `fikr.provisionprofile` | Developer ID profile with keychain-access-groups |

## Troubleshooting

### "The application can't be opened"
- Missing `keychain-access-groups` entitlement
- Check: `ls Fikr.app/Contents/embedded.provisionprofile`
- Verify: `codesign -d --entitlements - Fikr.app`
- Log: `/usr/bin/log show --predicate 'eventMessage CONTAINS "Fikr"' --last 5m --style compact`

### Notarization rejected
```bash
xcrun notarytool log <SUBMISSION_ID> --keychain-profile "notarytool-profile"
```

### Certificate not found
```bash
security find-identity -v -p codesigning
```
