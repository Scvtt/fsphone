import 'package:material_ui/material_ui.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';

/// Test sign-in for the desktop UI. Credentials stay on this machine and are
/// not sent anywhere. The QR block stands in for the PBX provisioning code.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final PhoneController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _server = TextEditingController(text: 'wss://pbx.example.com:7443');
  final _extension = TextEditingController();
  final _secret = TextEditingController();
  LoginMode _mode = LoginMode.password;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _extension.dispose();
    _secret.dispose();
    super.dispose();
  }

  void _submit() {
    final server = _server.text.trim();
    final extension = _extension.text.trim();
    final secret = _secret.text.trim();
    if (!server.startsWith('wss://')) {
      setState(() {
        _error = 'Use a secure WebSocket address, starting with wss://.';
      });
      return;
    }
    if (!RegExp(r'^\d{2,6}$').hasMatch(extension)) {
      setState(() => _error = 'Enter the extension as 2 to 6 digits.');
      return;
    }
    if (_mode == LoginMode.password && secret.isEmpty) {
      setState(() => _error = 'Enter the extension password to continue.');
      return;
    }
    if (_mode == LoginMode.token && secret.length < 4) {
      setState(() => _error = 'Enter the one-time token from the PBX link.');
      return;
    }
    widget.controller.signIn(
      displayServer: server,
      displayExtension: extension,
    );
  }

  void _simulateQr() {
    setState(() {
      _mode = LoginMode.token;
      _error = null;
      if (_extension.text.trim().isEmpty) {
        _extension.text = '1001';
      }
      _secret.text = 'test-token-1001';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FsColors.nav,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 56,
              ),
              child: Center(child: _card()),
            ),
          );
        },
      ),
    );
  }

  Widget _card() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 980),
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _qrPane()),
              const SizedBox(width: 28),
              Expanded(flex: 2, child: _form()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qrPane() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Provision with QR',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: FsColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'The PBX shows a code that signs this desktop app in and keeps it registered.',
            textAlign: TextAlign.center,
            style: TextStyle(color: FsColors.muted, height: 1.35),
          ),
          const SizedBox(height: 18),
          const CustomPaint(
            painter: _QrPlaceholderPainter(),
            size: Size(168, 168),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _simulateQr,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Use a test scan'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Test stand-in. It fills a one-time token and does not read a camera.',
            textAlign: TextAlign.center,
            style: TextStyle(color: FsColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    final tokenMode = _mode == LoginMode.token;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FS Phone',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: FsColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sign in to the desktop app. This screen is for testing — nothing is registered with the PBX yet.',
          style: TextStyle(color: FsColors.muted, height: 1.4),
        ),
        const SizedBox(height: 18),
        SegmentedButton<LoginMode>(
          segments: const [
            ButtonSegment(
              value: LoginMode.password,
              label: Text('Password'),
              icon: Icon(Icons.lock_outline),
            ),
            ButtonSegment(
              value: LoginMode.token,
              label: Text('One-time token'),
              icon: Icon(Icons.link),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) {
            setState(() {
              _mode = selection.first;
              _secret.clear();
              _error = null;
            });
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('login-server'),
          controller: _server,
          decoration: const InputDecoration(
            labelText: 'PBX WebSocket',
            hintText: 'wss://pbx.example.com:7443',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('login-extension'),
          controller: _extension,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Extension'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('login-secret'),
          controller: _secret,
          obscureText: !tokenMode,
          decoration: InputDecoration(
            labelText: tokenMode ? 'One-time token' : 'Password',
            helperText: tokenMode
                ? 'Deep link shape: fsphone://login?token=…'
                : 'Extension password from the PBX',
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: FsColors.missed)),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('login-submit'),
            onPressed: _submit,
            child: const Text('Sign in'),
          ),
        ),
      ],
    );
  }
}

class _QrPlaceholderPainter extends CustomPainter {
  const _QrPlaceholderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = Colors.white;
    final ink = Paint()..color = FsColors.ink;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      background,
    );
    const modules = 21;
    final cell = size.width / modules;
    void finder(int ox, int oy) {
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 7; x++) {
          final edge = x == 0 || y == 0 || x == 6 || y == 6;
          final core = x >= 2 && x <= 4 && y >= 2 && y <= 4;
          if (edge || core) {
            canvas.drawRect(
              Rect.fromLTWH((ox + x) * cell, (oy + y) * cell, cell, cell),
              ink,
            );
          }
        }
      }
    }

    finder(0, 0);
    finder(modules - 7, 0);
    finder(0, modules - 7);
    for (var y = 0; y < modules; y++) {
      for (var x = 0; x < modules; x++) {
        final inFinder =
            (x < 7 && y < 7) || (x > 13 && y < 7) || (x < 7 && y > 13);
        if (inFinder) {
          continue;
        }
        if ((x * 17 + y * 13) % 3 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell - 0.4, cell - 0.4),
            ink,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
