import 'package:material_ui/material_ui.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';

class RecentsScreen extends StatefulWidget {
  const RecentsScreen({super.key, required this.controller});

  final PhoneController controller;

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen> {
  RecentFilter _filter = RecentFilter.all;

  @override
  Widget build(BuildContext context) {
    final calls = widget.controller.visibleRecents(_filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SegmentedButton<RecentFilter>(
            segments: const [
              ButtonSegment(value: RecentFilter.all, label: Text('All')),
              ButtonSegment(value: RecentFilter.missed, label: Text('Missed')),
              ButtonSegment(
                value: RecentFilter.incoming,
                label: Text('Incoming'),
              ),
              ButtonSegment(
                value: RecentFilter.outgoing,
                label: Text('Outgoing'),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.first),
          ),
        ),
        Expanded(
          child: calls.isEmpty
              ? const Center(
                  child: Text(
                    'No calls in this view.',
                    style: TextStyle(color: FsColors.muted),
                  ),
                )
              : ListView.separated(
                  itemCount: calls.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final call = calls[index];
                    final missed = call.direction == CallDirection.missed;
                    final icon = switch (call.direction) {
                      CallDirection.incoming => Icons.call_received,
                      CallDirection.outgoing => Icons.call_made,
                      CallDirection.missed => Icons.call_missed,
                    };
                    final color = missed ? FsColors.missed : FsColors.muted;
                    final when = formatWhen(call.at, DateTime.now());
                    final length = call.length == Duration.zero
                        ? ''
                        : ' · ${formatDuration(call.length)}';
                    return ListTile(
                      leading: Icon(icon, color: color),
                      title: Text(
                        call.name,
                        style: TextStyle(
                          color: missed ? FsColors.missed : FsColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${call.number}$length'
                        '${call.media == CallMedia.video ? ' · Video' : ''}'
                        '${call.detail == null ? '' : ' · ${call.detail}'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            when,
                            style: const TextStyle(color: FsColors.muted),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Call',
                            onPressed: () => widget.controller.placeCall(
                              call.number,
                              media: CallMedia.voice,
                              name: call.name,
                            ),
                            icon: const Icon(Icons.call, color: FsColors.call),
                          ),
                          IconButton(
                            tooltip: 'Video call',
                            onPressed: () => widget.controller.placeCall(
                              call.number,
                              media: CallMedia.video,
                              name: call.name,
                            ),
                            icon: const Icon(Icons.videocam_outlined),
                          ),
                        ],
                      ),
                      onTap: () => widget.controller.placeCall(
                        call.number,
                        media: call.media,
                        name: call.name,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
