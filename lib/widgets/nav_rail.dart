import 'package:material_ui/material_ui.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';
import 'package:fsphone/widgets/presence_dot.dart';

class PhoneNavRail extends StatelessWidget {
  const PhoneNavRail({super.key, required this.controller});

  final PhoneController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('nav-rail'),
      width: 132,
      color: FsColors.nav,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _StatusButton(controller: controller),
          const SizedBox(height: 18),
          _NavButton(
            label: 'Keypad',
            icon: Icons.dialpad,
            selected: controller.section == ShellSection.dialer,
            onTap: () => controller.open(ShellSection.dialer),
          ),
          _NavButton(
            label: 'Contacts',
            icon: Icons.people_outline,
            selected: controller.section == ShellSection.contacts,
            onTap: () => controller.open(ShellSection.contacts),
          ),
          _NavButton(
            label: 'Recents',
            icon: Icons.history,
            selected: controller.section == ShellSection.recents,
            badge: controller.missedCount,
            onTap: () => controller.open(ShellSection.recents),
          ),
          _NavButton(
            label: 'Voicemail',
            icon: Icons.voicemail,
            selected: controller.section == ShellSection.voicemail,
            badge: controller.unreadVoicemail,
            onTap: () => controller.open(ShellSection.voicemail),
          ),
          const Spacer(),
          _NavButton(
            label: 'Settings',
            icon: Icons.settings_outlined,
            selected: controller.section == ShellSection.settings,
            onTap: () => controller.open(ShellSection.settings),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.controller});

  final PhoneController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Status',
      offset: const Offset(72, 0),
      color: Colors.white,
      onSelected: (value) {
        if (value == 'signout') {
          controller.signOut();
          return;
        }
        controller.setPresence(PresenceStatus.values.byName(value));
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.displayName,
                style: const TextStyle(
                  color: FsColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Ext ${controller.extension}',
                style: const TextStyle(color: FsColors.muted, fontSize: 12),
              ),
              Text(
                controller.server,
                style: const TextStyle(color: FsColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        for (final status in PresenceStatus.values)
          PopupMenuItem<String>(
            value: status.name,
            child: Row(
              children: [
                PresenceDot(status: status),
                const SizedBox(width: 10),
                Text(status.label),
                const Spacer(),
                if (controller.presence == status)
                  const Icon(Icons.check, size: 16, color: FsColors.accent),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: FsColors.missed),
              SizedBox(width: 10),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Tooltip(
        message: controller.presence.label,
        child: AvatarBadge(
          initials: 'TU',
          status: controller.presence,
          radius: 22,
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : const Color(0xFFB7C0CE);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Material(
        color: selected ? FsColors.navActive : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          hoverColor: FsColors.navHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  backgroundColor: FsColors.missed,
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
