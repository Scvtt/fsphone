import 'package:material_ui/material_ui.dart';
import 'package:fsphone/desktop/desktop_alerts.dart';
import 'package:fsphone/screens/login_screen.dart';
import 'package:fsphone/screens/shell_screen.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';

/// Stage one is the Windows desktop UI.
///
/// Login is local and only exists so the shell can be tested. SIP over WSS,
/// media, transfers on a live call, and push are not connected yet. The shell
/// follows the 3CX Windows layout: status, keypad, contacts, recents,
/// voicemail, and settings, including the README items that belong on desktop
/// (dial pad and DTMF, voice and video actions, blind and attended transfer,
/// registration state, background running, and ICE/STUN/TURN fields).
void main() {
  runApp(const FsPhoneApp());
}

class FsPhoneApp extends StatefulWidget {
  const FsPhoneApp({super.key});

  @override
  State<FsPhoneApp> createState() => _FsPhoneAppState();
}

class _FsPhoneAppState extends State<FsPhoneApp> {
  final PhoneController _controller = PhoneController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DesktopAlerts.start(_controller);
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
