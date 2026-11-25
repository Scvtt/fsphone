import 'package:material_ui/material_ui.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/theme/fs_colors.dart';

Color presenceColor(PresenceStatus status) {
  return switch (status) {
    PresenceStatus.available => FsColors.available,
    PresenceStatus.away => FsColors.away,
    PresenceStatus.doNotDisturb => FsColors.missed,
    PresenceStatus.lunch => const Color(0xFFEF7D32),
    PresenceStatus.businessTrip => const Color(0xFF3E8BFF),
  };
}

class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.status, this.size = 10});

  final PresenceStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: presenceColor(status),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.4),
      ),
    );
  }
}

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    super.key,
    required this.initials,
    required this.status,
    this.radius = 18,
    this.background = const Color(0xFF3D4E68),
    this.foreground = Colors.white,
  });

  final String initials;
  final PresenceStatus status;
  final double radius;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: background,
            foregroundColor: foreground,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.72,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: PresenceDot(status: status, size: radius * 0.48),
          ),
        ],
      ),
    );
  }
}
