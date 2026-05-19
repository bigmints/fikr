# Build

```bash
flutter pub get
flutter build macos --release      # macOS
flutter build appbundle            # Android AAB
flutter build ipa                  # iOS
```

**Validation before any build:**
```bash
flutter analyze    # must report 0 issues
flutter test       # must pass
```

→ For signing + notarizing the macOS DMG: `workflows/release.md`
→ For App Store / Play Store submission: `workflows/deploy.md`
