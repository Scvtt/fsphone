import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fsphone/data/sample_directory.dart';
import 'package:fsphone/models/phone_models.dart';

/// In-memory desktop session. Login, calls, and settings are local so the
/// Windows UI can be tested before WSS registration and media exist.
class PhoneController extends ChangeNotifier {
  PhoneController()
    : contacts = sampleContacts(),
      recents = sampleRecents(DateTime.now()),
      voicemails = sampleVoicemail(DateTime.now());

  bool signedIn = false;
  String displayName = 'Test user';
  String extension = '';
  String server = '';
  PresenceStatus presence = PresenceStatus.available;
  ShellSection section = ShellSection.dialer;
  String dialed = '';
  String search = '';
  bool stayRegistered = true;
  bool runInBackground = true;
  String stunServer = 'stun:stun.example.com:3478';
  String turnServer = 'turn:turn.example.com:3478';
  String turnUsername = '';
  String microphone = 'Default microphone';
  String speaker = 'Default speaker';
  bool missedSeen = false;

  final List<DirectoryContact> contacts;
  final List<RecentCall> recents;
  final List<VoicemailMessage> voicemails;
  ActiveCall? call;
  IncomingCall? incoming;
  String? playingVoicemailId;

  /// Set by the Windows shell. Shows a system toast when the window is
  /// minimized, unfocused, or off-screen. Null in tests.
  Future<void> Function(IncomingCall call)? presentIncoming;

  Timer? _ticker;
  int _id = 0;

  int get missedCount => missedSeen
      ? 0
      : recents.where((call) => call.direction == CallDirection.missed).length;

  int get unreadVoicemail =>
      voicemails.where((message) => message.unread).length;

  bool get registered => signedIn && stayRegistered;

  void signIn({
    required String displayServer,
    required String displayExtension,
  }) {
    server = displayServer.trim();
    extension = displayExtension.trim();
    displayName = 'Test user';
    signedIn = true;
    section = ShellSection.dialer;
    dialed = '';
    search = '';
    notifyListeners();
  }

  void signOut() {
    hangUp(record: false);
    signedIn = false;
    dialed = '';
    search = '';
    section = ShellSection.dialer;
    notifyListeners();
  }

  void setPresence(PresenceStatus value) {
    presence = value;
    notifyListeners();
  }

  void open(ShellSection next) {
    section = next;
    search = '';
    if (next == ShellSection.recents) {
      missedSeen = true;
    }
    if (next == ShellSection.voicemail) {
      for (final message in voicemails) {
        message.unread = false;
      }
    }
    notifyListeners();
  }

  void setSearch(String value) {
    search = value;
    notifyListeners();
  }

  void pushDigit(String digit) {
    if (call != null) {
      if (call!.showKeypad) {
        call!.dtmf += digit;
        notifyListeners();
      }
      return;
    }
    dialed += digit;
    notifyListeners();
  }

  void backspace() {
    if (dialed.isEmpty) {
      return;
    }
    dialed = dialed.substring(0, dialed.length - 1);
    notifyListeners();
  }

  void clearDialed() {
    dialed = '';
    notifyListeners();
  }

  void setDialed(String value) {
    dialed = value;
    notifyListeners();
  }

  DirectoryContact? contactFor(String number) {
    final compact = number.replaceAll(' ', '');
    for (final contact in contacts) {
      if (contact.extension.replaceAll(' ', '') == compact) {
        return contact;
      }
    }
    return null;
  }

  List<DirectoryContact> matchesForDialed() {
    final query = dialed.replaceAll(' ', '').toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return contacts
        .where((contact) {
          final number = contact.extension.replaceAll(' ', '').toLowerCase();
          return number.contains(query) ||
              contact.name.toLowerCase().contains(query);
        })
        .take(4)
        .toList();
  }

  List<DirectoryContact> visibleContacts(ContactScope scope) {
    final query = search.trim().toLowerCase();
    return contacts.where((contact) {
      final scopeOk = switch (scope) {
        ContactScope.all => true,
        ContactScope.company => contact.company,
        ContactScope.personal => !contact.company,
      };
      if (!scopeOk) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return contact.name.toLowerCase().contains(query) ||
          contact.extension.toLowerCase().contains(query) ||
          contact.department.toLowerCase().contains(query);
    }).toList();
  }

  List<RecentCall> visibleRecents(RecentFilter filter) {
    final query = search.trim().toLowerCase();
    return recents.where((recent) {
      final filterOk = switch (filter) {
        RecentFilter.all => true,
        RecentFilter.missed => recent.direction == CallDirection.missed,
        RecentFilter.incoming => recent.direction == CallDirection.incoming,
        RecentFilter.outgoing => recent.direction == CallDirection.outgoing,
      };
      if (!filterOk) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return recent.name.toLowerCase().contains(query) ||
          recent.number.toLowerCase().contains(query);
    }).toList();
  }

  List<VoicemailMessage> visibleVoicemail() {
    final query = search.trim().toLowerCase();
    if (query.isEmpty) {
      return voicemails;
    }
    return voicemails
        .where(
          (message) =>
              message.name.toLowerCase().contains(query) ||
              message.number.toLowerCase().contains(query),
        )
        .toList();
  }

  void placeCall(String raw, {required CallMedia media, String? name}) {
    final number = raw.trim();
    if (number.isEmpty || call != null) {
      return;
    }
    final known = name ?? contactFor(number)?.name ?? number;
    call = ActiveCall(
      name: known,
      number: number,
      media: media,
      started: DateTime.now(),
    );
    section = ShellSection.dialer;
    _ensureTicker();
    notifyListeners();
  }

  void hangUp({bool record = true}) {
    final current = call;
    if (current == null) {
      return;
    }
    try {
      if (record) {
        final detail = current.consulting
            ? 'Consult with ${current.consultName} cancelled'
            : null;
        _pushRecent(
          name: current.name,
          number: current.number,
          direction: CallDirection.outgoing,
          media: current.media,
          length: current.elapsed(DateTime.now()),
          detail: detail,
        );
      }
    } finally {
      // Always drop the call, including after a failed transfer, so Hang up
      // still works when the user leaves the call screen and comes back.
      call = null;
      _ticker?.cancel();
      _ticker = null;
      notifyListeners();
    }
  }

  void toggleMute() {
    final current = call;
    if (current == null) {
      return;
    }
    current.muted = !current.muted;
    notifyListeners();
  }

  void toggleHold() {
    final current = call;
    if (current == null || current.consulting) {
      return;
    }
    current.held = !current.held;
    notifyListeners();
  }

  void toggleRecord() {
    final current = call;
    if (current == null) {
      return;
    }
    current.recording = !current.recording;
    notifyListeners();
  }

  void toggleVideo() {
    final current = call;
    if (current == null) {
      return;
    }
    current.media = current.media == CallMedia.video
        ? CallMedia.voice
        : CallMedia.video;
    notifyListeners();
  }

  void toggleKeypad() {
    final current = call;
    if (current == null) {
      return;
    }
    current.showKeypad = !current.showKeypad;
    notifyListeners();
  }

  void blindTransfer({required String number, required String name}) {
    final current = call;
    if (current == null) {
      return;
    }
    _pushRecent(
      name: current.name,
      number: current.number,
      direction: CallDirection.outgoing,
      media: current.media,
      length: current.elapsed(DateTime.now()),
      detail: 'Blind transfer to $name',
    );
    call = null;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void beginAttendedTransfer({required String number, required String name}) {
    final current = call;
    if (current == null) {
      return;
    }
    current.held = true;
    current.consulting = true;
    current.consultName = name;
    current.consultNumber = number;
    current.consultOnHold = false;
    current.showKeypad = false;
    notifyListeners();
  }

  /// Leave the consulted party on hold and talk to the original caller again.
  void switchBackToCaller() {
    final current = call;
    if (current == null || !current.consulting) {
      return;
    }
    current.consultOnHold = true;
    current.held = false;
    notifyListeners();
  }

  /// Return to the consulted party and put the original caller back on hold.
  void returnToConsult() {
    final current = call;
    if (current == null || !current.consulting) {
      return;
    }
    current.consultOnHold = false;
    current.held = true;
    notifyListeners();
  }

  void completeAttendedTransfer() {
    final current = call;
    if (current == null || !current.consulting) {
      return;
    }
    _pushRecent(
      name: current.name,
      number: current.number,
      direction: CallDirection.outgoing,
      media: current.media,
      length: current.elapsed(DateTime.now()),
      detail: 'Attended transfer to ${current.consultName}',
    );
    call = null;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void cancelAttendedTransfer() {
    final current = call;
    if (current == null || !current.consulting) {
      return;
    }
    current.consulting = false;
    current.consultOnHold = false;
    current.consultName = null;
    current.consultNumber = null;
    current.held = false;
    notifyListeners();
  }

  /// Raises a test incoming call. Audio is not connected; the shell shows the
  /// call, and Windows shows a toast when the window is not in front.
  void simulateIncomingCall() {
    final ringing = IncomingCall(
      name: contacts.first.name,
      number: contacts.first.extension,
    );
    incoming = ringing;
    notifyListeners();
    presentIncoming?.call(ringing);
  }

  void answerIncoming() {
    final ringing = incoming;
    if (ringing == null) {
      return;
    }
    incoming = null;
    if (call != null) {
      hangUp();
    }
    placeCall(ringing.number, media: CallMedia.voice, name: ringing.name);
  }

  void declineIncoming() {
    if (incoming == null) {
      return;
    }
    incoming = null;
    notifyListeners();
  }

  void deleteVoicemail(String id) {
    voicemails.removeWhere((message) => message.id == id);
    if (playingVoicemailId == id) {
      playingVoicemailId = null;
    }
    notifyListeners();
  }

  void toggleVoicemailPlayback(String id) {
    playingVoicemailId = playingVoicemailId == id ? null : id;
    notifyListeners();
  }

  void setStayRegistered(bool value) {
    stayRegistered = value;
    notifyListeners();
  }

  void setRunInBackground(bool value) {
    runInBackground = value;
    notifyListeners();
  }

  void setStun(String value) {
    stunServer = value;
    notifyListeners();
  }

  void setTurn(String value) {
    turnServer = value;
    notifyListeners();
  }

  void setTurnUsername(String value) {
    turnUsername = value;
    notifyListeners();
  }

  void setMicrophone(String value) {
    microphone = value;
    notifyListeners();
  }

  void setSpeaker(String value) {
    speaker = value;
    notifyListeners();
  }

  void _pushRecent({
    required String name,
    required String number,
    required CallDirection direction,
    required CallMedia media,
    required Duration length,
    String? detail,
  }) {
    _id += 1;
    recents.insert(
      0,
      RecentCall(
        id: 'local-$_id',
        name: name,
        number: number,
        direction: direction,
        media: media,
        at: DateTime.now(),
        length: length,
        detail: detail,
      ),
    );
  }

  void _ensureTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (call != null) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
