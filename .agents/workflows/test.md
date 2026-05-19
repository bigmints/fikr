# Test & Validate

```bash
flutter pub get
flutter analyze              # 0 issues required
flutter test                 # all tests must pass
flutter test test/tools/     # tool engine tests specifically
```

**Task gate:** a task is not done until both `flutter analyze` and `flutter test` pass.
