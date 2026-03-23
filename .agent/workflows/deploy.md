---
description: How to release and deploy the Fikr applications
---

This workflow automates the end-to-end process of packaging the mobile apps for production and deploying the Next.js backend to Google Cloud Run. 

## 1. Prepare for Release
1. Check `pubspec.yaml` and manually bump the `version:` number (e.g. from `1.0.4+5` to `1.0.5+6`).
2. Ensure you have tested everything thoroughly via `npm run dev` and `flutter run`.

## 2. Package Flutter Apps
Run the following commands in the `fikr` mobile app directory (`/Users/pretheesh/Projects/fikr/`):

// turbo
```bash
flutter build appbundle
```
**Next Steps for Android:** Once finished, upload the newly built AAB (`build/app/outputs/bundle/release/app-release.aab`) to the Google Play Console manually.

// turbo
```bash
flutter build ipa
```
**Next Steps for iOS:** Once finished, open Xcode Organizer or the `Transporter` app to upload the generated archive (`build/ios/archive/Runner.xcarchive`) to App Store Connect / TestFlight.

## 3. Deploy Backend to Google Cloud Run
Run the following command in the `fikr.one` backend directory (`/Users/pretheesh/Projects/fikr.one/`):

// turbo
```bash
gcloud run deploy ssrfikrapps --source . --project fikr-apps --region us-central1 --quiet </dev/null
```
This will containerize the Next.js backend and automatically push it to Cloud Run.
