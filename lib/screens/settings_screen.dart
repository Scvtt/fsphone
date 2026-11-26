import 'package:material_ui/material_ui.dart';
import 'package:fsphone/audio/windows_audio.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final PhoneController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      children: [
        _card(
          title: 'Account',
          child: Column(
            children: [
              _row('Name', controller.displayName),
              _row('Extension', controller.extension),
              _row('PBX', controller.server),
              _row('Transport', 'Secure WebSocket (WSS)'),
              _row(
                'Registration',
                controller.registered ? 'Registered' : 'Not registered',
              ),
            ],
          ),
        ),
        _card(
          title: 'Audio',
          child: Column(
            children: [
              _devicePicker(
                label: 'Microphone',
                value: controller.microphoneId,
                devices: controller.microphones,
                windowsDefault: controller.windowsDefaultMicrophone,
                onChanged: controller.setMicrophone,
              ),
              const SizedBox(height: 12),
              _devicePicker(
                label: 'Speaker',
                value: controller.speakerId,
                devices: controller.speakers,
                windowsDefault: controller.windowsDefaultSpeaker,
                onChanged: controller.setSpeaker,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: controller.refreshAudioDevices,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh devices'),
                ),
              ),
              if (controller.audioDeviceError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    controller.audioDeviceError!,
                    style: const TextStyle(
                      color: FsColors.missed,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _card(
          title: 'NAT traversal',
          child: Column(
            children: [
              _RememberedField(
                label: 'STUN server',
                initial: controller.stunServer,
                onChanged: controller.setStun,
              ),
              const SizedBox(height: 12),
              _RememberedField(
                label: 'TURN server',
                initial: controller.turnServer,
                onChanged: controller.setTurn,
              ),
              const SizedBox(height: 12),
              _RememberedField(
                label: 'TURN username',
                initial: controller.turnUsername,
                onChanged: controller.setTurnUsername,
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ICE uses these relays when the desktop app places a real call. They are stored locally for now.',
                  style: TextStyle(color: FsColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        _card(
          title: 'Desktop',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Stay registered'),
                subtitle: const Text(
                  'Keep the Windows app registered with the PBX while it is open.',
                ),
                value: controller.stayRegistered,
                onChanged: controller.setStayRegistered,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Run in the background'),
                subtitle: const Text(
                  'Leave the app running after the window is closed so it can keep its registration.',
                ),
                value: controller.runInBackground,
                onChanged: controller.setRunInBackground,
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Incoming-call alerts'),
                subtitle: Text(
                  'An incoming call rings. While this window is in the background, a card at the bottom-right of the screen offers Answer and Hang up. Closing the window leaves the app in the tray. Click the tray icon for Show FS Phone and Exit.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: FsColors.muted)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _devicePicker({
    required String label,
    required String value,
    required List<AudioDevice> devices,
    required String windowsDefault,
    required ValueChanged<String> onChanged,
  }) {
    final known = devices.any((device) => device.id == value);
    final selected = known ? value : '';
    final defaultText = windowsDefault.isEmpty
        ? 'Windows default has not been read yet.'
        : 'Windows default: $windowsDefault';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('$label-$selected-${devices.length}'),
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem(value: '', child: Text('Windows default')),
            for (final device in devices)
              DropdownMenuItem(
                value: device.id,
                child: Text(
                  device.label == windowsDefault
                      ? '${device.label} (Windows default)'
                      : device.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
        const SizedBox(height: 4),
        Text(
          defaultText,
          style: const TextStyle(color: FsColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _RememberedField extends StatefulWidget {
  const _RememberedField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_RememberedField> createState() => _RememberedFieldState();
}

class _RememberedFieldState extends State<_RememberedField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(labelText: widget.label),
      onChanged: widget.onChanged,
    );
  }
}
