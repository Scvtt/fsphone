import 'package:material_ui/material_ui.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';
import 'package:fsphone/widgets/dial_pad.dart';

class ActiveCallScreen extends StatelessWidget {
  const ActiveCallScreen({super.key, required this.controller});

  final PhoneController controller;

  @override
  Widget build(BuildContext context) {
    final call = controller.call;
    if (call == null) {
      return const SizedBox.shrink();
    }
    final elapsed = formatDuration(call.elapsed(DateTime.now()));
    final onConsult = call.consulting && !call.consultOnHold;
    final title = onConsult ? call.consultName ?? 'Consulting' : call.name;
    final subtitle = onConsult ? call.consultNumber ?? '' : call.number;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
            child: Column(
              children: [
                if (call.held && !call.consulting)
                  _banner('On hold', Icons.pause_circle_outline),
                if (onConsult)
                  _banner(
                    'On hold: ${call.name}. Switch back to speak to them before you complete the transfer.',
                    Icons.swap_calls,
                  ),
                if (call.consulting && call.consultOnHold)
                  _banner(
                    '${call.consultName} is on hold.',
                    Icons.pause_circle_outline,
                  ),
                if (call.recording)
                  _banner('Recording', Icons.fiber_manual_record),
                if (call.media == CallMedia.video && !onConsult)
                  Container(
                    width: 460,
                    height: 180,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101722),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam, color: Colors.white70, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'Video preview',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: FsColors.muted)),
                const SizedBox(height: 6),
                Text(
                  elapsed,
                  style: const TextStyle(
                    fontSize: 18,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (call.dtmf.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'DTMF ${call.dtmf}',
                    style: const TextStyle(color: FsColors.muted),
                  ),
                ],
                const SizedBox(height: 22),
                if (call.showKeypad) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('keypad-back'),
                      onPressed: controller.toggleKeypad,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to call'),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: DialPad(
                        diameter: 62,
                        onDigit: controller.pushDigit,
                      ),
                    ),
                  ),
                ] else if (call.consulting)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: controller.completeAttendedTransfer,
                        icon: const Icon(Icons.check),
                        label: const Text('Complete transfer'),
                      ),
                      OutlinedButton(
                        onPressed: call.consultOnHold
                            ? controller.returnToConsult
                            : controller.switchBackToCaller,
                        child: Text(
                          call.consultOnHold
                              ? 'Return to consult'
                              : 'Switch back',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: controller.cancelAttendedTransfer,
                        child: const Text('Cancel'),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 18,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _action(
                        icon: call.muted ? Icons.mic_off : Icons.mic_none,
                        label: call.muted ? 'Unmute' : 'Mute',
                        active: call.muted,
                        onTap: controller.toggleMute,
                      ),
                      _action(
                        icon: Icons.pause,
                        label: call.held ? 'Resume' : 'Hold',
                        active: call.held,
                        onTap: controller.toggleHold,
                      ),
                      _action(
                        key: const Key('open-keypad'),
                        icon: Icons.dialpad,
                        label: 'Keypad',
                        active: false,
                        onTap: controller.toggleKeypad,
                      ),
                      _action(
                        icon: Icons.phone_forwarded,
                        label: 'Transfer',
                        active: false,
                        onTap: () => _openTransfer(context),
                      ),
                      _action(
                        icon: Icons.fiber_manual_record,
                        label: call.recording ? 'Stop' : 'Record',
                        active: call.recording,
                        onTap: controller.toggleRecord,
                      ),
                      _action(
                        icon: call.media == CallMedia.video
                            ? Icons.videocam_off
                            : Icons.videocam,
                        label: call.media == CallMedia.video
                            ? 'Stop video'
                            : 'Video',
                        active: call.media == CallMedia.video,
                        onTap: controller.toggleVideo,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: IconButton.filled(
            key: const Key('hang-up'),
            tooltip: 'Hang up',
            style: IconButton.styleFrom(
              backgroundColor: FsColors.hangup,
              foregroundColor: Colors.white,
              fixedSize: const Size(72, 72),
              iconSize: 32,
            ),
            onPressed: () => controller.hangUp(),
            icon: const Icon(Icons.call_end),
          ),
        ),
      ],
    );
  }

  Widget _banner(String text, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9A6700)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _action({
    Key? key,
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 84,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Material(
              color: active ? const Color(0xFFDCE8FF) : const Color(0xFFEEF1F5),
              shape: const CircleBorder(),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(icon, color: FsColors.ink),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _openTransfer(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _TransferDialog(
          controller: controller,
          onBlind: (number, name) {
            Navigator.pop(dialogContext);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.blindTransfer(number: number, name: name);
            });
          },
          onAttended: (number, name) {
            Navigator.pop(dialogContext);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.beginAttendedTransfer(number: number, name: name);
            });
          },
        );
      },
    );
  }
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({
    required this.controller,
    required this.onBlind,
    required this.onAttended,
  });

  final PhoneController controller;
  final void Function(String number, String name) onBlind;
  final void Function(String number, String name) onAttended;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _number = TextEditingController();
  String _pickedName = '';

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  String _targetName(String number) {
    if (_pickedName.isNotEmpty) {
      return _pickedName;
    }
    return widget.controller.contactFor(number)?.name ?? number;
  }

  @override
  Widget build(BuildContext context) {
    final query = _number.text.trim().toLowerCase();
    final options = widget.controller.contacts.where((contact) {
      if (query.isEmpty) {
        return true;
      }
      return contact.name.toLowerCase().contains(query) ||
          contact.extension.toLowerCase().contains(query);
    });
    final ready = _number.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Transfer call'),
      content: SizedBox(
        width: 420,
        height: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Blind transfer sends the caller straight across. Attended transfer lets you speak to the other person first.',
              style: TextStyle(color: FsColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('transfer-number'),
              controller: _number,
              decoration: const InputDecoration(
                labelText: 'Extension or number',
              ),
              onChanged: (_) => setState(() => _pickedName = ''),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final contact in options)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(contact.name),
                      subtitle: Text(contact.extension),
                      onTap: () {
                        setState(() {
                          _number.text = contact.extension;
                          _pickedName = contact.name;
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: ready
              ? () {
                  final number = _number.text.trim();
                  widget.onBlind(number, _targetName(number));
                }
              : null,
          child: const Text('Blind'),
        ),
        FilledButton(
          onPressed: ready
              ? () {
                  final number = _number.text.trim();
                  widget.onAttended(number, _targetName(number));
                }
              : null,
          child: const Text('Attended'),
        ),
      ],
    );
  }
}
