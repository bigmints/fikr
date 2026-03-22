---
description: Build, sign, and notarize the macOS app for direct distribution (outside App Store)
---

# macOS Build, Sign & Notarize Workflow

// turbo-all

This workflow produces a notarized DMG that can be distributed to any Mac without
"unidentified developer" warnings.

## Prerequisites

- **Apple Developer Program** membership (Team ID: `FBG8NKYPUJ`)
- **Developer ID Application** certificate installed in Keychain
  - Identity: `Developer ID Application: Pretheesh Thomas (FBG8NKYPUJ)`
  - SHA: `6C1A3F8220D266BD1EE7F74CA9DDE320610F911D`
- **Developer ID provisioning profile** at `fikr.provisionprofile` (project root)
  - Contains `keychain-access-groups` entitlement for flutter_secure_storage
- **Notarytool credentials** stored in Keychain profile `notarytool-profile`
  - Apple ID: `me@bigmints.com`
  - Team ID: `FBG8NKYPUJ`

If credentials are not stored, run:

```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "me@bigmints.com" \
  --password "APP_SPECIFIC_PASSWORD" \
  --team-id "FBG8NKYPUJ"
```

## Steps

### 1. Build the release macOS app

```bash
cd /Users/pretheesh/Projects/fikr && flutter build macos --release
```

### 2. Embed the provisioning profile

The provisioning profile is required for the `keychain-access-groups` entitlement
(used by flutter_secure_storage). It must be embedded BEFORE re-signing.

```bash
cp /Users/pretheesh/Projects/fikr/fikr.provisionprofile /Users/pretheesh/Projects/fikr/build/macos/Build/Products/Release/Fikr.app/Contents/embedded.provisionprofile
```

### 3. Re-sign with Developer ID Application (with hardened runtime)

Uses `DeveloperID.entitlements` which has resolved (non-variable) keychain-access-groups
value `FBG8NKYPUJ.com.bigmints.fikr` instead of Xcode variables.

```bash
cd /Users/pretheesh/Projects/fikr && codesign --deep --force --options runtime \
  --sign "Developer ID Application: Pretheesh Thomas (FBG8NKYPUJ)" \
  --entitlements macos/Runner/DeveloperID.entitlements \
  build/macos/Build/Products/Release/Fikr.app
```

### 4. Verify the signature

```bash
codesign -dv --verbose=2 /Users/pretheesh/Projects/fikr/build/macos/Build/Products/Release/Fikr.app 2>&1 | grep -E "Authority|flags"
```

Expected output should show:

- `Authority=Developer ID Application: Pretheesh Thomas (FBG8NKYPUJ)`
- `flags=0x10000(runtime)` (hardened runtime)

### 5. Create DMG for distribution (with Applications shortcut)

```bash
cd /Users/pretheesh/Projects/fikr && \
  mkdir -p /tmp/fikr-dmg-staging && \
  cp -R build/macos/Build/Products/Release/Fikr.app /tmp/fikr-dmg-staging/ && \
  ln -sf /Applications /tmp/fikr-dmg-staging/Applications && \
  hdiutil create -volname "Fikr" \
    -srcfolder /tmp/fikr-dmg-staging \
    -ov -format UDZO build/Fikr-macos.dmg && \
  rm -rf /tmp/fikr-dmg-staging
```

### 6. Notarize the DMG with Apple

```bash
xcrun notarytool submit /Users/pretheesh/Projects/fikr/build/Fikr-macos.dmg \
  --keychain-profile "notarytool-profile" --wait
```

Wait for `status: Accepted`. This typically takes 2-10 minutes.

### 7. Staple the notarization ticket to the DMG

```bash
xcrun stapler staple /Users/pretheesh/Projects/fikr/build/Fikr-macos.dmg
```

### 8. Verify Gatekeeper acceptance

```bash
spctl -a -vv /Users/pretheesh/Projects/fikr/build/macos/Build/Products/Release/Fikr.app 2>&1
```

Expected output: `source=Notarized Developer ID`

## Output

The distributable DMG is at:

```
/Users/pretheesh/Projects/fikr/build/Fikr-macos.dmg
```

## Key Files

| File                                     | Purpose                                                       |
| ---------------------------------------- | ------------------------------------------------------------- |
| `macos/Runner/Release.entitlements`      | Entitlements for App Store (uses Xcode variables)             |
| `macos/Runner/DeveloperID.entitlements`  | Entitlements for Developer ID (resolved values)               |
| `macos/Runner/DebugProfile.entitlements` | Entitlements for debug/profile builds                         |
| `fikr.provisionprofile`                  | Developer ID provisioning profile with keychain-access-groups |

## Troubleshooting

### "The application can't be opened"

- Usually means `keychain-access-groups` entitlement is missing or invalid
- Check `embedded.provisionprofile` is present: `ls Fikr.app/Contents/embedded.provisionprofile`
- Verify entitlements: `codesign -d --entitlements - Fikr.app`
- Check system log: `/usr/bin/log show --predicate 'eventMessage CONTAINS "Fikr"' --last 5m --style compact`

### Notarization rejected

Check the detailed log:

```bash
xcrun notarytool log <SUBMISSION_ID> --keychain-profile "notarytool-profile"
```

### Certificate not found

List available signing identities:

```bash
security find-identity -v -p codesigning
```

### CSR generation fails in Keychain Access

Use the command line instead:

```bash
openssl req -new -newkey rsa:2048 -nodes \
  -keyout /tmp/devid_private.key \
  -out /tmp/CertificateSigningRequest.certSigningRequest \
  -subj "/emailAddress=me@bigmints.com/CN=Pretheesh Thomas/C=AE"
```

Then upload the CSR at https://developer.apple.com/account/resources/certificates/add
and choose "Developer ID Application".

### App-specific password

Generate at: https://appleid.apple.com → Sign-in and Security → App-Specific Passwords
