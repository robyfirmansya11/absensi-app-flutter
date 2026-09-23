# InSys Mobile

**Employee attendance, business requests, and approval workflows in one Android application.**

InSys Mobile is a Flutter application connected to the InSys Laravel / Filament backend. It enables employees to record attendance, submit internal requests, and track their status, while authorized managers can review and decide requests from their phones.

Android is the current development and testing focus. Other platform directories are included in the project, but their presence does not imply release readiness.

## Features

| Area | Modules |
| --- | --- |
| Attendance | Clock In, Clock Out, location and camera capture, attendance history, and monthly summaries |
| HRIS | Late Working Permits, Leave Requests, Overtime Requests, and Travel Reimbursements |
| Finance, Accounting & Tax | Loan Note, Payment Application Letter, and Expense Reimbursement Note |
| Legal & Litigation | Register Letter and Stamp Application Letter |
| Account | Authentication, employee profile, and session handling |

Supported request modules include approval interfaces for authorized reviewers. Available actions depend on the user's role, reporting relationships, request status, and the backend approval rules. Leave approvals have a dedicated screen; other supported approval modules provide a **Pending Approvals** view alongside **My Requests**.

The application also includes English interface labels, form validation, confirmation dialogs, rejection reasons, attachment uploads where supported, and connectivity feedback. An internet connection is required for server operations; connectivity feedback does not provide offline submission or synchronization.

## Technology

- **Flutter / Dart** for the application and interface.
- **Riverpod** for application state management.
- **Dio** for HTTP requests and API error handling.
- **Flutter Secure Storage** for authentication token storage.
- **Geolocator, Camera, and Image Picker** for attendance capture.
- **File Picker** for supported request attachments.
- **Laravel / Filament REST API** for persistence, authorization, and approval processing, maintained separately.

Dependency constraints are defined in [pubspec.yaml](pubspec.yaml), with resolved versions in [pubspec.lock](pubspec.lock).

## Prerequisites

- Flutter SDK with Dart **3.12.2 or a compatible 3.x version**, as required by `pubspec.yaml`.
- Android Studio and Android SDK Platform **36**.
- A JDK compatible with the project's Android build tooling; Android Studio's bundled JDK is recommended. Java and Kotlin compilation target Java 17.
- An Android emulator or a physical Android device with USB debugging enabled.
- Access to a compatible InSys backend and a valid user account.

The current release APK requires **Android 7.0 / API 24 or later**. The project delegates its minimum SDK setting to Flutter, so verify device requirements again after SDK upgrades.

## Getting Started

```sh
git clone https://github.com/robyfirmansya11/absensi-app-flutter.git
cd absensi-app-flutter
flutter doctor
flutter pub get
flutter devices
```

Start an Android emulator in Android Studio, then run:

```sh
flutter run -d <android-device-id>
```

Replace `<android-device-id>` with the identifier reported by `flutter devices`. The default environment is **development**.

## Environment Configuration

Environment selection is defined in [app_config.dart](lib/core/constants/app_config.dart) using the compile-time `APP_ENV` value.

| Setting | Development | Production |
| --- | --- | --- |
| `APP_ENV` | `development` (default) | `production` |
| API base URL | `http://10.0.2.2/api/v1` | `https://insys.bumimorowaliutama.com/api/v1` |
| Custom `Host` header | `internal-system.test` | None |
| Intended use | Local backend through the Android emulator | Deployed backend, including physical-device testing |

Only the exact value `production` selects production; omitted or other values select development. The configuration also adjusts legacy image URLs for the selected environment.

### Local development

Ensure the local backend is running and serves the `internal-system.test` virtual host on HTTP port 80. The Android emulator accesses the host computer through `10.0.2.2`.

```sh
flutter run -d <android-device-id> --dart-define=APP_ENV=development
```

`10.0.2.2` is an Android emulator address. It does not point to your development computer from a physical phone. Local testing on a phone requires a reachable backend address and corresponding configuration.

The current development routing relies on a custom `Host` header. A browser run is not equivalent to Android emulator testing and requires separate browser-compatible routing and CORS configuration.

### Production testing

```sh
flutter run -d <android-device-id> --dart-define=APP_ENV=production
```

Stop and relaunch the application when changing `--dart-define` values. Hot reload does not change the build's environment selection.

Production builds connect to the live backend. Requests and approval decisions use the account and data available on that server.

## Build an Android APK

Build a universal release APK using the production API:

```sh
flutter build apk --release --dart-define=APP_ENV=production
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

For separate APKs by processor architecture:

```sh
flutter build apk --release --split-per-abi --dart-define=APP_ENV=production
```

To install the universal APK on a connected device with Android Platform Tools available:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The current release build uses the **debug signing configuration** in [android/app/build.gradle.kts](android/app/build.gradle.kts). This supports direct testing, but a dedicated release signing configuration and the intended application ID must be established before publishing. The current application ID is `com.example.absensi_app_new`.

APK files, build outputs, local environment files, and signing key files are excluded from version control.

## Backend Integration

This repository contains the mobile client. Building or pushing it does **not** deploy the Laravel / Filament backend.

The client uses bearer-token authentication and endpoints under `/api/v1`. Endpoint constants are maintained in [api_constants.dart](lib/core/constants/api_constants.dart), and request handling is implemented in the repositories under `lib/data/repositories/`.

Before testing a module against production, ensure that its corresponding API routes and approval logic have been deployed. Reviewer access must be configured on the backend, including roles, reporting relationships, and the applicable approval stage. Mobile visibility alone does not grant permission to approve a request.

## Project Structure

```text
lib/
  core/
    constants/       Environment configuration and API paths
    network/         HTTP client and authentication handling
    utils/           Shared application utilities
    widgets/         Shared interface components
  data/
    models/          API response models
    repositories/    Module-specific API operations
  presentation/
    providers/       Application state and request flows
    screens/         Attendance, account, and business modules
  repositories/      Additional attendance repository code
  main.dart          Application entry point
assets/images/       Branding and image assets
android/             Android application and build configuration
test/                Automated application tests
```

## Quality Checks

```sh
flutter analyze
flutter test
```

Run a focused module test when working on a specific workflow:

```sh
flutter test test/stamp_approval_test.dart test/stamp_test.dart
```

Tests cover request handling, validation, approval decisions, session behavior, and interface interactions. They do not replace physical-device checks for camera permissions, GPS behavior, network conditions, or live backend integration.

## Troubleshooting

| Symptom | Checks |
| --- | --- |
| Login times out in the emulator | Confirm the local backend is running, the environment is development, and the `internal-system.test` virtual host is reachable through the emulator's host connection. |
| Login fails on a physical phone | Confirm the build uses production or an explicitly configured backend reachable from the phone. |
| An approval list is empty | Check the user's backend role, reporting relationships, pending request status, approval stage, and deployed API version. |
| A new module returns an API error | Confirm its backend routes and controller changes have been deployed to the selected environment. |
| Camera or location capture fails | Check Android permissions, location services, and device or emulator capabilities. |
| APK installation reports a signature conflict | Use an APK signed with the same key as the installed app. Uninstalling first removes local app data and requires signing in again. |

## Development Guidelines

Keep interface labels in professional English and follow the existing model, repository, provider, and screen structure when extending modules. Keep server-side authorization authoritative and add relevant tests when changing request or approval behavior.

Use development for routine local work and select production explicitly for a production build. Do not commit credentials, authentication tokens, signing keys, or employee data.
