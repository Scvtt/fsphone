import 'package:material_ui/material_ui.dart';
import 'package:fsphone/desktop/desktop_alerts.dart';
import 'package:fsphone/screens/login_screen.dart';
import 'package:fsphone/screens/shell_screen.dart';
import 'package:fsphone/sip/softphone.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';

/// Windows desktop phone. Sign-in registers directly with FreeSWITCH Sofia
/// over WSS. Calls use SIP and WebRTC media. Provisioning and push are later.
void main() {
  runApp(const FsPhoneApp());
}

class FsPhoneApp extends StatefulWidget {
  const FsPhoneApp({super.key, this.softphone});

  /// Tests pass a stand-in. The Windows app uses [SofiaSoftphone].
  final Softphone? softphone;

  @override
  State<FsPhoneApp> createState() => _FsPhoneAppState();
}

class _FsPhoneAppState extends State<FsPhoneApp> {
  late final PhoneController _controller = PhoneController(
    softphone: widget.softphone,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DesktopAlerts.start(_controller);
      _controller.refreshAudioDevices();
      _controller.restoreSignIn();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'FS Phone',
          debugShowCheckedModeBanner: false,
          theme: buildFsTheme(),
          home: _controller.signedIn
              ? ShellScreen(controller: _controller)
              : LoginScreen(controller: _controller),
        );
      },
    );
  }
}
