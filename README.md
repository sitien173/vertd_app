# vertd iOS App Scaffold

This directory contains the SwiftUI source scaffold for tasks 7-13.

## Notes
- Source files live under `vertd/`.
- Unit tests live under `vertdTests/`.
- `vertd.xcodeproj` currently contains a placeholder `project.pbxproj` in this CLI environment.
  Open this folder on macOS/Xcode and create the app + test targets that include these files.

## GitHub Actions IPA Build

This repo includes a macOS CI workflow at `.github/workflows/build-ipa.yml` that archives and exports an `.ipa`.

### Required repository secrets

- `IOS_CERT_P12_BASE64`: Base64 of Apple signing `.p12` certificate.
- `IOS_CERT_PASSWORD`: Password for the `.p12`.
- `IOS_PROVISION_PROFILE_BASE64`: Base64 of `.mobileprovision` profile.
- `IOS_TEAM_ID`: Apple Developer Team ID.
- `IOS_BUNDLE_ID`: App bundle identifier used by the Xcode target.
- `IOS_SIGNING_CERT`: Certificate common name, for example `Apple Distribution`.

### Triggering builds

- Automatic on pushes to `master`.
- Manual from Actions tab with optional `export_method` (`ad-hoc` or `development`).

### Important

The workflow intentionally fails if `vertd.xcodeproj/project.pbxproj` is still the placeholder file.
Commit a real Xcode project file first, then CI can produce signed IPAs.

## Codemagic IPA Build

This repo also includes `codemagic.yaml` for Codemagic native iOS builds.

### Codemagic setup checklist

- Add this repository in Codemagic and select the `ios-native-workflow`.
- Upload signing assets in Codemagic (`Code signing identities` and `Provisioning profiles`) for the bundle ID.
- Ensure bundle identifier and signing settings match your real app target:
  - `BUNDLE_ID`
  - `environment.ios_signing.bundle_identifier`
- Keep `XCODE_PROJECT` and `XCODE_SCHEME` aligned with your real Xcode project.

### Important

As with GitHub Actions, Codemagic build will fail until `vertd.xcodeproj/project.pbxproj` is replaced with a real Xcode project file.
