# FS Phone

FS Phone is a cross-platform softphone for FreeSWITCH PBX (FS PBX) covering iOS, Android and Windows.

This repository is a bare Flutter skeleton (the default counter app). Softphone features have not been implemented yet.

## Features still to implement

- [ ] SIP registration over secure WebSocket (WSS)
- [ ] Voice calling
- [ ] Video calling
- [ ] Call transfer (blind and attended)
- [ ] Dial pad / DTMF
- [ ] Push notifications for incoming calls on mobile (PushKit/CallKit on iOS, FCM on Android)
- [ ] Background operation
- [ ] NAT traversal via ICE/STUN/TURN
- [ ] Persistent login via QR code and deep-link one-time token flow
- [ ] Desktop app staying registered

## Project structure

- `lib/` — Dart application source. The current entry point is `lib/main.dart` (the default Flutter counter app).
- `test/` — Widget and unit tests that ship with the Flutter template.
- `android/` — Android host project, Gradle configuration, and the application id `au.com.levixit.fsphone`.
- `ios/` — Xcode iOS host project and the bundle identifier `au.com.levixit.fsphone`.
- `windows/` — Windows desktop runner (CMake / Visual Studio) for the Win32 host app.
- `pubspec.yaml` — Package name, SDK constraints, and dependencies.
- `analysis_options.yaml` — Dart analyser and lint rules for this project.

## Setup

Prerequisites:

- Flutter **3.50.1** stable (Dart 3.14.0)
- Confirm your toolchain with:

```bash
flutter --version
flutter doctor
```

From the `fsphone` project root, fetch packages:

```bash
flutter pub get
```

### Android

- Install Android Studio and the Android SDK (including a platform and an emulator or a USB-debugging device).
- Then run:

```bash
flutter run -d android
```

### iOS

iOS builds require macOS, Xcode, and CocoaPods. After opening the project on a Mac, install pods and run:

```bash
cd ios && pod install && cd ..
flutter run -d ios
```

Before a device or App Store build, set the signing team and certificates in Xcode (`ios/Runner.xcworkspace`).

### Windows

- Install Visual Studio 2022 with the **Desktop development with C++** workload.
- Enable Windows Developer Mode.
- Then run:

```bash
flutter run -d windows
```

## Source control

A GitHub remote will be added later:

```bash
git remote add origin <url>
```
