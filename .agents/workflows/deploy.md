---
description: Package and release the Fikr Flutter app (iOS + Android + macOS)
---

# Fikr — Deploy Workflow

Packages the mobile and desktop Flutter apps for production release.

> **Before releasing:** bump `version` in `pubspec.yaml` (e.g. `1.0.4+5` → `1.0.5+6`). Test thoroughly via `flutter run` first.

---

## 1. Android — Build App Bundle

```bash
flutter build appbundle
```

**Next step:** Upload `build/app/outputs/bundle/release/app-release.aab` to the Google Play Console manually.

---

## 2. iOS — Build IPA

```bash
flutter build ipa
```

**Next step:** Open Xcode Organizer or the `Transporter` app to upload `build/ios/archive/Runner.xcarchive` to App Store Connect / TestFlight.

---

## 3. macOS — Build, Sign & Notarize DMG

For macOS direct distribution (outside App Store), follow the full signing workflow:

→ `.agents/workflows/build-macos.md`

---

## 4. Firestore / Storage Rules

```bash
firebase deploy --only firestore:rules,storage
```

---

## See Also

- macOS signing detail: `.agents/workflows/build-macos.md`
- AI model config: `.agents/workflows/manage-ai-config.md`
- Backend deploy: see `fikr.one/.agents/workflows/deploy.md`
