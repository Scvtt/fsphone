import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';
import 'package:fsphone/widgets/dial_pad.dart';
import 'package:fsphone/widgets/presence_dot.dart';

class DialerScreen extends StatelessWidget {
  const DialerScreen({super.key, required this.controller});

  final PhoneController controller;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || controller.call != null) {
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (character != null && RegExp(r'^[0-9*#]$').hasMatch(character)) {
      controller.pushDigit(character);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      controller.backspace();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      controller.placeCall(controller.dialed, media: CallMedia.voice);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final matches = controller.matchesForDialed();
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 860;
          final pad = _padColumn(matches);
          if (!wide) {
            return pad;
          }
          return Row(
            children: [
              Expanded(child: pad),
              const VerticalDivider(width: 1),
              SizedBox(width: 340, child: _sideList()),
            ],
          );
        },
      ),
    );
  }

  Widget _padColumn(List<DirectoryContact> matches) {
    final dialed = controller.dialed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: const Key('dial-display'),
                  child: Text(
                    dialed.isEmpty ? 'Enter a number' : dialed,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      letterSpacing: dialed.isEmpty ? 0 : 1.4,
                      color: dialed.isEmpty ? FsColors.muted : FsColors.ink,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: dialed.isEmpty ? null : controller.backspace,
                onLongPress: dialed.isEmpty ? null : controller.clearDialed,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (matches.isEmpty && dialed.isEmpty)
            const Text(
              'Type a number or pick a speed dial. Enter places the call.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FsColors.muted),
            )
          else
            for (final contact in matches.take(2))
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: EdgeInsets.zero,
                leading: AvatarBadge(
                  initials: contact.initials,
                  status: contact.presence,
                  radius: 16,
                  background: const Color(0xFFE7EEF8),
                  foreground: FsColors.ink,
                ),
                title: Text(contact.name),
                subtitle: Text(contact.extension),
                trailing: const Icon(Icons.call, color: FsColors.call),
                onTap: () => controller.placeCall(
                  contact.extension,
                  media: CallMedia.voice,
                  name: contact.name,
                ),
              ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 360,
                  child: DialPad(
                    onDigit: controller.pushDigit,
                    onLongZero: () => controller.pushDigit('+'),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundAction(
                tooltip: 'Video call',
                color: FsColors.accent,
                icon: Icons.videocam,
                onPressed: dialed.isEmpty
                    ? null
                    : () =>
                          controller.placeCall(dialed, media: CallMedia.video),
              ),
              const SizedBox(width: 28),
              _RoundAction(
                key: const Key('place-call'),
                tooltip: 'Call',
                color: FsColors.call,
                icon: Icons.call,
                onPressed: dialed.isEmpty
                    ? null
                    : () =>
                          controller.placeCall(dialed, media: CallMedia.voice),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sideList() {
    final people = controller.contacts.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Text(
            'Speed dial',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: people.length,
            itemBuilder: (context, index) {
              final contact = people[index];
              return ListTile(
                leading: AvatarBadge(
                  initials: contact.initials,
                  status: contact.presence,
                  radius: 18,
                  background: const Color(0xFFE7EEF8),
                  foreground: FsColors.ink,
                ),
                title: Text(contact.name),
                subtitle: Text('${contact.department} · ${contact.extension}'),
                trailing: IconButton(
                  tooltip: 'Call',
                  onPressed: () => controller.placeCall(
                    contact.extension,
                    media: CallMedia.voice,
                    name: contact.name,
                  ),
                  icon: const Icon(Icons.call, color: FsColors.call),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.tooltip,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: onPressed == null ? FsColors.line : color,
        foregroundColor: Colors.white,
        fixedSize: const Size(68, 68),
        iconSize: 30,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}
