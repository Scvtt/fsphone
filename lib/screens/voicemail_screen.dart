import 'package:material_ui/material_ui.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';

class VoicemailScreen extends StatelessWidget {
  const VoicemailScreen({super.key, required this.controller});

  final PhoneController controller;

  @override
  Widget build(BuildContext context) {
    final messages = controller.visibleVoicemail();
    if (messages.isEmpty) {
      return const Center(
        child: Text('No voicemail.', style: TextStyle(color: FsColors.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final message = messages[index];
        final playing = controller.playingVoicemailId == message.id;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: playing
                ? const Color(0xFFE7F6EE)
                : const Color(0xFFEEF1F5),
            child: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              color: playing ? FsColors.call : FsColors.ink,
            ),
          ),
          title: Text(
            message.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${message.number} · ${formatDuration(message.length)}'
            '${playing ? ' · Playing preview' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatWhen(message.at, DateTime.now()),
                style: const TextStyle(color: FsColors.muted),
              ),
              IconButton(
                tooltip: 'Call back',
                onPressed: () => controller.placeCall(
                  message.number,
                  media: CallMedia.voice,
                  name: message.name,
                ),
                icon: const Icon(Icons.call, color: FsColors.call),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => controller.deleteVoicemail(message.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          onTap: () => controller.toggleVoicemailPlayback(message.id),
        );
      },
    );
  }
}
