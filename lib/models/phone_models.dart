enum PresenceStatus {
  available('Available'),
  away('Away'),
  doNotDisturb('Do not disturb'),
  lunch('Lunch'),
  businessTrip('Business trip');

  const PresenceStatus(this.label);
  final String label;
}

enum ShellSection { dialer, contacts, recents, voicemail, settings }

enum CallMedia { voice, video }

enum CallDirection { incoming, outgoing, missed }

enum RecentFilter { all, missed, incoming, outgoing }

enum ContactScope { all, company, personal }

enum LoginMode { password, token }

class DirectoryContact {
  const DirectoryContact({
    required this.id,
    required this.name,
    required this.extension,
    required this.department,
    required this.email,
    required this.presence,
    required this.company,
  });

  final String id;
  final String name;
  final String extension;
  final String department;
  final String email;
  final PresenceStatus presence;
  final bool company;

  String get initials {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class RecentCall {
  const RecentCall({
    required this.id,
    required this.name,
    required this.number,
    required this.direction,
    required this.media,
    required this.at,
    required this.length,
    this.detail,
  });

  final String id;
  final String name;
  final String number;
  final CallDirection direction;
  final CallMedia media;
  final DateTime at;
  final Duration length;
  final String? detail;
}

class VoicemailMessage {
  VoicemailMessage({
    required this.id,
    required this.name,
    required this.number,
    required this.at,
    required this.length,
    required this.unread,
  });

  final String id;
  final String name;
  final String number;
  final DateTime at;
  final Duration length;
  bool unread;
}

class ActiveCall {
  ActiveCall({
    required this.name,
    required this.number,
    required this.media,
    required this.started,
  });

  String name;
  final String number;
  CallMedia media;
  final DateTime started;
  bool muted = false;
  bool held = false;
  bool recording = false;
  bool showKeypad = false;
  String dtmf = '';
  bool consulting = false;

  /// True while the agent has switched back to the original caller and the
  /// consulted party is the one on hold.
  bool consultOnHold = false;
  String? consultName;
  String? consultNumber;

  Duration elapsed(DateTime now) => now.difference(started);
}

String formatClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatWhen(DateTime time, DateTime now) {
  final clock = formatClock(time);
  final sameDay =
      time.year == now.year && time.month == now.month && time.day == now.day;
  if (sameDay) {
    return clock;
  }
  return '${time.day}/${time.month} $clock';
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String presenceLabel(PresenceStatus status) => status.label;

/// A ringing call that has not been answered. No media path is attached.
class IncomingCall {
  const IncomingCall({required this.name, required this.number});

  final String name;
  final String number;
}
