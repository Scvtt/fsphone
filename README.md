# FS Phone

FS Phone is a softphone for a FreeSWITCH PBX. The working app is the Windows desktop build on branch `windows-desktop-ui`. iOS and Android host projects are in the tree, and the phone itself has not been brought up on those platforms.

The Windows app registers and places calls directly with Sofia over secure WebSocket (`wss://`, typically port 7443). There is no provisioning plugin.

Remote: https://github.com/Scvtt/fsphone.git

## What works on Windows

- SIP registration over WSS, with the extension password. A successful registration is saved on this PC and restored when the app opens.
- Outbound and inbound voice calls, DTMF, mute, and hold.
- Blind transfer, and attended transfer: the consult extension is called first, and Complete sends a REFER with Replaces.
- The call screen stays on **Calling…** until the other party answers, then **Connecting…** until media is up. The talk timer starts then.
- Microphone and speaker choice. **Windows communications device** follows the Windows communications endpoint. A specific device is remembered by name across calls and restarts.
- Incoming calls ring in the foreground and in the background. The answer card is shown only when the main window is in the background.
- Closing the window hides the app to the tray. The tray menu can show the window or exit.
- STUN is used for ICE. The default server is `stun:stun.l.google.com:19302`.

Release build:

```text
build\windows\x64\runner\Release\fsphone.exe
```

Close any running FS Phone, including the tray icon, before starting a new build.

## Not done yet

- One-time token and QR login. The screen is there; it does not register. Sign in with the extension password.
- A directory of internal extensions, or presence (available, on a call, busy) from the PBX. The contacts screen has no PBX data.
- Mobile push (PushKit, CallKit, FCM) and a working iOS or Android phone.
- TURN. The settings fields are stored, and the credential sent to the stack is empty, so relay is not used. Calls that need TURN will be one-way or silent.

## sip_ua patches

Calls depend on local edits to `sip_ua` 1.1.0 in the Pub cache (`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\sip_ua-1.1.0`). Those edits are not in this repository. `flutter pub get` into a fresh cache removes them. The running Windows app expects these behaviours:

- Local tracks are added before the offer or answer is created, so an outbound call includes the microphone.
- A 183 with SDP is applied as a provisional answer, and a later 200 does not replace the original offer.
- ICE gathering is given up after the configured timeout even when Windows has not produced a candidate, so the INVITE is not held for tens of seconds.
- Hanging up before the INVITE is sent drops that invite. After it is sent, CANCEL goes out immediately.
- Attended transfer can read the consult dialog's call id, and a hold re-INVITE applies the answer.
- Hang up still terminates the SIP session if a media stream entry is missing.

## Project layout

- `lib/` — Flutter UI, SIP session (`lib/sip/softphone.dart`), and Windows audio (`lib/audio/`).
- `lib/desktop/` — ringtone, background incoming card, and tray behaviour.
- `windows/runner/` — Win32 window, tray icon, and hide-on-close.
- `test/` — widget tests and audio-catalog tests. They use a stand-in softphone, not a live PBX.
- `android/`, `ios/` — host projects, application id `au.com.levixit.fsphone`.

## Setup

- Flutter 3.50.1 stable (Dart 3.14).
- Visual Studio 2022 with the **Desktop development with C++** workload.
- Windows Developer Mode.

```bash
flutter pub get
flutter test
flutter run -d windows
flutter build windows
```

Sign-in asks for the WebSocket URL, domain, extension, and password. Trusting any certificate is available for a PBX that does not present a publicly trusted certificate.
