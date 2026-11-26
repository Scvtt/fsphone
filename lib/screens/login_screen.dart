import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';

/// Payload encoded in the test provisioning code.
const qrLoginServer = 'wss://pbx.example.com:7443';
const qrLoginExtension = '1001';
const qrLoginToken = 'test-token-1001';

String get qrLoginPayload =>
    'fsphone://login?token=$qrLoginToken&ext=$qrLoginExtension&server=${Uri.encodeComponent(qrLoginServer)}';

/// Signs the desktop app in by registering the extension over WSS.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final PhoneController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _server = TextEditingController();
  final _domain = TextEditingController();
  final _extension = TextEditingController();
  final _secret = TextEditingController();
  LoginMode _mode = LoginMode.password;
  bool _allowBadCertificate = true;
  bool _busy = false;
  bool _appliedSaved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_applySavedLogin);
    _applySavedLogin();
  }

  void _applySavedLogin() {
    final saved = widget.controller.remembered;
    if (saved == null || _appliedSaved) {
      return;
    }
    _appliedSaved = true;
    _server.text = saved.server;
    _domain.text = saved.domain;
    _extension.text = saved.extension;
    _secret.text = saved.password;
    _allowBadCertificate = saved.trustAnyCertificate;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_applySavedLogin);
    _server.dispose();
    _domain.dispose();
    _extension.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
    if (_mode == LoginMode.token) {
      setState(() {
        _error = 'One-time token provisioning is not connected yet. Sign in with the extension password.';
      });
      return;
    }
    if (secret.isEmpty) {
      setState(() => _error = 'Enter the extension password to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.controller.signIn(
      displayServer: server,
      displayExtension: extension,
      password: secret,
      domain: _domain.text,
      trustAnyCertificate: _allowBadCertificate,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
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
            'A PBX provisioning code will live here later. It does not register this app yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: FsColors.muted, height: 1.35),
          ),
          const SizedBox(height: 18),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              key: const Key('login-qr'),
              borderRadius: BorderRadius.circular(8),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: qrLoginPayload,
                  version: QrVersions.auto,
                  size: 168,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: FsColors.ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: FsColors.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the extension password on the right to register with FreeSWITCH.',
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
          'Registers this extension with FreeSWITCH over the Sofia WebSocket. A successful sign-in is remembered on this PC until you sign out.',
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
          key: const Key('login-domain'),
          controller: _domain,
          decoration: const InputDecoration(
            labelText: 'SIP domain',
            hintText: 'Leave blank to use the WebSocket host',
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
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _allowBadCertificate,
          onChanged: (value) {
            setState(() => _allowBadCertificate = value ?? false);
          },
          title: const Text('Allow the PBX certificate'),
          subtitle: const Text(
            'Needed when the Sofia WSS port uses a private or self-signed certificate.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
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
            onPressed: _busy || widget.controller.restoring ? null : _submit,
            child: Text(
              _busy || widget.controller.restoring ? 'Registering…' : 'Sign in',
            ),
          ),
        ),
      ],
    );
  }
}
