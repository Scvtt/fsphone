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
    final consulting = call.consulting;
    final title = consulting ? call.consultName ?? 'Consulting' : call.name;
    final subtitle = consulting ? call.consultNumber ?? '' : call.number;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        children: [
          if (call.held && !consulting)
            _banner('On hold', Icons.pause_circle_outline),
          if (consulting)
            _banner(
              'On hold: ${call.name}. Complete the transfer when you are ready.',
              Icons.swap_calls,
            ),
          if (call.recording) _banner('Recording', Icons.fiber_manual_record),
          const Spacer(),
          if (call.media == CallMedia.video && !consulting)
            Container(
              width: 460,
              height: 220,
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
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
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
          if (call.showKeypad)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: DialPad(diameter: 62, onDigit: controller.pushDigit),
            )
          else if (consulting)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: controller.completeAttendedTransfer,
                  icon: const Icon(Icons.check),
                  label: const Text('Complete transfer'),
                ),
                const SizedBox(width: 12),
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
                  label: call.media == CallMedia.video ? 'Stop video' : 'Video',
                  active: call.media == CallMedia.video,
                  onTap: controller.toggleVideo,
                ),
              ],
            ),
          const Spacer(),
          IconButton.filled(
            tooltip: 'Hang up',
            style: IconButton.styleFrom(
              backgroundColor: FsColors.hangup,
              foregroundColor: Colors.white,
              fixedSize: const Size(72, 72),
              iconSize: 32,
            ),
            onPressed: controller.hangUp,
            icon: const Icon(Icons.call_end),
          ),
        ],
      ),
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
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          IconButton.filledTonal(
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: active
                  ? const Color(0xFFDCE8FF)
                  : const Color(0xFFEEF1F5),
              fixedSize: const Size(56, 56),
            ),
            icon: Icon(icon, color: FsColors.ink),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _openTransfer(BuildContext context) async {
    final number = TextEditingController();
    var pickedName = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final query = number.text.trim().toLowerCase();
            final options = controller.contacts
                .where((contact) {
                  if (query.isEmpty) {
                    return true;
                  }
                  return contact.name.toLowerCase().contains(query) ||
                      contact.extension.toLowerCase().contains(query);
                })
                .take(5);
            return AlertDialog(
              title: const Text('Transfer call'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blind transfer sends the caller straight across. Attended transfer lets you speak to the other person first.',
                      style: TextStyle(color: FsColors.muted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: number,
                      decoration: const InputDecoration(
                        labelText: 'Extension or number',
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 8),
                    for (final contact in options)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(contact.name),
                        subtitle: Text(contact.extension),
                        onTap: () {
                          number.text = contact.extension;
                          pickedName = contact.name;
                          setLocal(() {});
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: number.text.trim().isEmpty
                      ? null
                      : () {
                          final target = number.text.trim();
                          final name = pickedName.isEmpty
                              ? controller.contactFor(target)?.name ?? target
                              : pickedName;
                          Navigator.pop(dialogContext);
                          controller.blindTransfer(number: target, name: name);
                        },
                  child: const Text('Blind'),
                ),
                FilledButton(
                  onPressed: number.text.trim().isEmpty
                      ? null
                      : () {
                          final target = number.text.trim();
                          final name = pickedName.isEmpty
                              ? controller.contactFor(target)?.name ?? target
                              : pickedName;
                          Navigator.pop(dialogContext);
                          controller.beginAttendedTransfer(
                            number: target,
                            name: name,
                          );
                        },
                  child: const Text('Attended'),
                ),
              ],
            );
          },
        );
      },
    );
    number.dispose();
  }
}
