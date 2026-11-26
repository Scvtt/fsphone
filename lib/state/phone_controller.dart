import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fsphone/audio/saved_audio.dart';
import 'package:fsphone/audio/windows_audio.dart';
import 'package:fsphone/audio/windows_endpoints.dart';
import 'package:fsphone/auth/saved_login.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/sip/softphone.dart';

/// Desktop session. Sign-in registers with FreeSWITCH over WSS. Calls are
/// real SIP dialogs. Contacts, recents, and voicemail start empty and only
/// grow from calls this session actually places or receives.
class PhoneController extends ChangeNotifier implements SoftphoneListener {
  PhoneController({Softphone? softphone})
    : _softphone = softphone ?? SofiaSoftphone(),
      contacts = <DirectoryContact>[],
      recents = <RecentCall>[],
      voicemails = <VoicemailMessage>[] {
    _softphone.listener = this;
  }

  final Softphone _softphone;
  Completer<String?>? _registerResult;
  bool _endingLocally = false;

  bool signedIn = false;
  bool sipRegistered = false;
  String? statusMessage;
  String displayName = '';
  String extension = '';
  String server = '';
  String sipDomain = '';
  bool allowBadCertificate = true;
  bool restoring = false;
  SavedLogin? remembered;
  PresenceStatus presence = PresenceStatus.available;
  ShellSection section = ShellSection.dialer;
  String dialed = '';
  String search = '';
  bool stayRegistered = true;
  bool runInBackground = true;
  String stunServer = 'stun:stun.l.google.com:19302';
  String turnServer = '';
  String turnUsername = '';

  /// Empty means follow the Windows communications device.
  String microphoneId = '';
  String speakerId = '';
  String _microphoneLabel = '';
  String _speakerLabel = '';
  bool _audioChoiceLoaded = false;
  List<AudioDevice> microphones = const <AudioDevice>[];
  List<AudioDevice> speakers = const <AudioDevice>[];
  String windowsDefaultMicrophone = '';
  String windowsDefaultSpeaker = '';
  String consoleMicrophone = '';
  String consoleSpeaker = '';
  String? defaultMicrophoneId;
  String? defaultSpeakerId;
  String? audioDeviceError;
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
  Future<void>? _audioRefresh;
  int _id = 0;
  int _dialGeneration = 0;

  int get missedCount => missedSeen
      ? 0
      : recents.where((call) => call.direction == CallDirection.missed).length;

  int get unreadVoicemail =>
      voicemails.where((message) => message.unread).length;

  bool get registered => signedIn && stayRegistered && sipRegistered;

  /// Registers with the PBX. Returns an error string, or null once Sofia
  /// accepts the REGISTER.
  Future<String?> signIn({
    required String displayServer,
    required String displayExtension,
    required String password,
    required String domain,
    required bool trustAnyCertificate,
  }) async {
    final websocket = displayServer.trim();
    final ext = displayExtension.trim();
    final host = _domainFor(websocket, domain);
    if (host.isEmpty) {
      return 'The WebSocket address has no host.';
    }
    server = websocket;
    extension = ext;
    sipDomain = host;
    allowBadCertificate = trustAnyCertificate;
    displayName = ext;
    statusMessage = 'Registering…';
    notifyListeners();

    final result = Completer<String?>();
    _registerResult = result;
    final ice = <Map<String, String>>[
      <String, String>{'urls': stunServer.trim()},
    ];
    if (turnServer.trim().isNotEmpty) {
      ice.add(<String, String>{
        'urls': turnServer.trim(),
        'username': turnUsername.trim(),
        'credential': '',
      });
    }
    try {
      await _softphone.connect(
        SipAccount(
          webSocketUrl: websocket,
          extension: ext,
          password: password,
          domain: host,
          allowBadCertificate: trustAnyCertificate,
          iceServers: ice,
        ),
      );
    } catch (error) {
      _registerResult = null;
      statusMessage = 'Could not open the WebSocket.';
      notifyListeners();
      return statusMessage;
    }
    final error = await result.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => 'Registration timed out. Check the WebSocket address, certificate, and extension password.',
    );
    if (error != null) {
      statusMessage = error;
      sipRegistered = false;
      notifyListeners();
      return error;
    }
    signedIn = true;
    section = ShellSection.dialer;
    dialed = '';
    search = '';
    statusMessage = null;
    final saved = SavedLogin(
      server: websocket,
      domain: domain.trim(),
      extension: ext,
      password: password,
      trustAnyCertificate: trustAnyCertificate,
    );
    remembered = saved;
    notifyListeners();
    await SavedLogin.write(saved);
    return null;
  }

  /// Registers again with the account saved on this PC.
  Future<void> restoreSignIn() async {
    final saved = await SavedLogin.read();
    if (saved == null || signedIn) {
      return;
    }
    remembered = saved;
    restoring = true;
    notifyListeners();
    await signIn(
      displayServer: saved.server,
      displayExtension: saved.extension,
      password: saved.password,
      domain: saved.domain,
      trustAnyCertificate: saved.trustAnyCertificate,
    );
    restoring = false;
    notifyListeners();
  }

  void signOut() {
    hangUp(record: false);
    signedIn = false;
    sipRegistered = false;
    statusMessage = null;
    remembered = null;
    dialed = '';
    search = '';
    section = ShellSection.dialer;
    notifyListeners();
    unawaited(_softphone.disconnect());
    unawaited(SavedLogin.clear());
  }

  String _domainFor(String websocket, String override) {
    final typed = override.trim();
    if (typed.isNotEmpty) {
      return typed;
    }
    return Uri.tryParse(websocket)?.host ?? '';
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
    if (next == ShellSection.settings) {
      unawaited(refreshAudioDevices());
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
        _softphone.sendDtmf(digit);
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

  Future<void> placeCall(
    String raw, {
    required CallMedia media,
    String? name,
    CallDirection direction = CallDirection.outgoing,
    bool sendInvite = true,
  }) async {
    final number = raw.trim();
    if (number.isEmpty || call != null) {
      return;
    }
    if (sendInvite && !sipRegistered) {
      statusMessage = 'Not registered with the PBX.';
      notifyListeners();
      return;
    }
    final generation = ++_dialGeneration;
    await _prepareAudio();
    if (generation != _dialGeneration || call != null) {
      return;
    }
    if (sendInvite && !sipRegistered) {
      statusMessage = 'Not registered with the PBX.';
      notifyListeners();
      return;
    }
    final known = name ?? contactFor(number)?.name ?? number;
    call = ActiveCall(
      name: known,
      number: number,
      media: media,
      started: DateTime.now(),
      direction: direction,
    );
    call!.connecting = !sendInvite;
    section = ShellSection.dialer;
    _ensureTicker();
    notifyListeners();
    if (!sendInvite) {
      return;
    }
    final sent = await _softphone.invite(
      number,
      video: media == CallMedia.video,
    );
    if (generation != _dialGeneration) {
      _softphone.hangup();
      return;
    }
    if (!sent && call != null) {
      hangUp(record: false);
      statusMessage =
          'The WebSocket is not connected, so the call was not sent.';
      notifyListeners();
    }
  }

  void hangUp({bool record = true}) {
    final current = call;
    if (current == null) {
      return;
    }
    _dialGeneration++;
    _endingLocally = true;
    try {
      _softphone.hangup();
      if (record) {
        final detail = current.consulting
            ? 'Consult with ${current.consultName} cancelled'
            : null;
        _pushRecent(
          name: current.name,
          number: current.number,
          direction: current.direction,
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
      _endingLocally = false;
      notifyListeners();
    }
  }

  void toggleMute() {
    final current = call;
    if (current == null) {
      return;
    }
    current.muted = !current.muted;
    _softphone.setMuted(current.muted);
    notifyListeners();
  }

  void toggleHold() {
    final current = call;
    if (current == null || current.consulting) {
      return;
    }
    current.held = !current.held;
    _softphone.setHeld(current.held);
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
    _endingLocally = true;
    _softphone.refer(number);
    _pushRecent(
      name: current.name,
      number: current.number,
      direction: current.direction,
      media: current.media,
      length: current.elapsed(DateTime.now()),
      detail: 'Blind transfer to $name',
    );
    call = null;
    _ticker?.cancel();
    _ticker = null;
    _endingLocally = false;
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
    unawaited(_softphone.startConsult(number));
  }

  /// Leave the consulted party on hold and talk to the original caller again.
  void switchBackToCaller() {
    final current = call;
    if (current == null || !current.consulting) {
      return;
    }
    current.consultOnHold = true;
    current.held = false;
    _softphone.switchToCaller();
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
    _softphone.switchToConsult();
    notifyListeners();
  }

  void completeAttendedTransfer() {
    final current = call;
    if (current == null || !current.consulting) {
      return;
    }
    _endingLocally = true;
    _pushRecent(
      name: current.name,
      number: current.number,
      direction: current.direction,
      media: current.media,
      length: current.elapsed(DateTime.now()),
      detail: 'Attended transfer to ${current.consultName}',
    );
    if (current.consultNumber != null) {
      _softphone.completeConsult(current.consultNumber!);
    }
    call = null;
    _ticker?.cancel();
    _ticker = null;
    _endingLocally = false;
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
    _softphone.cancelConsult();
    notifyListeners();
  }

  @override
  void onConsultEnded() {
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

  @override
  void onCallAccepted() {
    final current = call;
    if (current == null || current.live) {
      return;
    }
    current.connecting = true;
    notifyListeners();
  }

  @override
  void onMediaReady() {
    final current = call;
    if (current == null || current.live) {
      return;
    }
    current.connecting = false;
    current.connectedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> answerIncoming() async {
    final ringing = incoming;
    if (ringing == null) {
      return;
    }
    incoming = null;
    notifyListeners();
    await _prepareAudio();
    _softphone.answer(video: false);
    final number = ringing.number.trim().isEmpty
        ? ringing.name
        : ringing.number;
    placeCall(
      number,
      media: CallMedia.voice,
      name: ringing.name,
      direction: CallDirection.incoming,
      sendInvite: false,
    );
  }

  void declineIncoming() {
    final ringing = incoming;
    if (ringing == null) {
      return;
    }
    incoming = null;
    _softphone.decline();
    _pushRecent(
      name: ringing.name,
      number: ringing.number,
      direction: CallDirection.missed,
      media: CallMedia.voice,
      length: Duration.zero,
    );
    notifyListeners();
  }

  @override
  void onRegistered() {
    sipRegistered = true;
    statusMessage = null;
    final pending = _registerResult;
    _registerResult = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(null);
    }
    notifyListeners();
  }

  @override
  void onRegistrationFailed(String message) {
    sipRegistered = false;
    statusMessage = message;
    final pending = _registerResult;
    _registerResult = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(message);
    }
    notifyListeners();
  }

  @override
  void onUnregistered() {
    sipRegistered = false;
    if (signedIn) {
      statusMessage = 'Registration dropped.';
    }
    notifyListeners();
  }

  @override
  void onIncoming({
    required String name,
    required String number,
    required bool video,
  }) {
    final ringing = IncomingCall(name: name, number: number);
    incoming = ringing;
    notifyListeners();
    presentIncoming?.call(ringing);
  }

  @override
  bool acceptOutgoing() => call != null;

  @override
  void onCallEnded(String reason) {
    final ringing = incoming;
    if (ringing != null && call == null) {
      incoming = null;
      _pushRecent(
        name: ringing.name,
        number: ringing.number,
        direction: CallDirection.missed,
        media: CallMedia.voice,
        length: Duration.zero,
        detail: reason,
      );
      notifyListeners();
      return;
    }
    if (_endingLocally || call == null) {
      return;
    }
    final current = call!;
    _pushRecent(
      name: current.name,
      number: current.number,
      direction: current.direction,
      media: current.media,
      length: current.elapsed(DateTime.now()),
      detail: reason,
    );
    call = null;
    _ticker?.cancel();
    _ticker = null;
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
    if (signedIn) {
      if (value) {
        _softphone.register();
      } else {
        unawaited(_softphone.unregister());
      }
    }
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
    microphoneId = value;
    _microphoneLabel = _labelFor(microphones, value);
    unawaited(_rememberAudio());
    unawaited(_pushAudioDevices());
    notifyListeners();
  }

  void setSpeaker(String value) {
    speakerId = value;
    _speakerLabel = _labelFor(speakers, value);
    unawaited(_rememberAudio());
    unawaited(_pushAudioDevices());
    notifyListeners();
  }

  Future<void> restoreAudioChoice() async {
    final saved = await SavedAudio.read();
    _audioChoiceLoaded = true;
    if (saved == null) {
      return;
    }
    _microphoneLabel = saved.microphoneLabel;
    _speakerLabel = saved.speakerLabel;
  }

  Future<void> refreshAudioDevices() {
    final current = _audioRefresh;
    if (current != null) {
      return current;
    }
    late final Future<void> gated;
    gated = _loadAudioDevices().whenComplete(() {
      if (identical(_audioRefresh, gated)) {
        _audioRefresh = null;
      }
    });
    _audioRefresh = gated;
    return gated;
  }

  Future<void> _loadAudioDevices() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    if (!_audioChoiceLoaded) {
      await restoreAudioChoice();
    }
    try {
      final inputs = await WindowsAudio.microphones();
      final outputs = await WindowsAudio.speakers();
      final inputRoles = WindowsEndpoints.microphones();
      final outputRoles = WindowsEndpoints.speakers();
      microphones = inputs.devices;
      speakers = outputs.devices;
      consoleMicrophone = _roleName(
        inputRoles?.console,
        inputs.windowsDefaultName,
      );
      consoleSpeaker = _roleName(
        outputRoles?.console,
        outputs.windowsDefaultName,
      );
      windowsDefaultMicrophone = _roleName(
        inputRoles?.communications,
        consoleMicrophone,
      );
      windowsDefaultSpeaker = _roleName(
        outputRoles?.communications,
        consoleSpeaker,
      );
      defaultMicrophoneId = inputs.idForName(windowsDefaultMicrophone);
      defaultSpeakerId = outputs.idForName(windowsDefaultSpeaker);
      microphoneId = _resolveChoice(microphones, _microphoneLabel);
      speakerId = _resolveChoice(speakers, _speakerLabel);
      audioDeviceError = null;
      await _pushAudioDevices();
    } catch (_) {
      audioDeviceError = 'Could not read the Windows audio devices.';
    }
    notifyListeners();
  }

  String _roleName(String? live, String fallback) {
    final name = live?.trim() ?? '';
    return name.isEmpty ? fallback : name;
  }

  String _labelFor(List<AudioDevice> devices, String id) {
    if (id.isEmpty) {
      return '';
    }
    for (final device in devices) {
      if (device.id == id) {
        return device.label;
      }
    }
    return '';
  }

  String _resolveChoice(List<AudioDevice> devices, String label) {
    if (label.isEmpty) {
      return '';
    }
    for (final device in devices) {
      if (device.label.toLowerCase() == label.toLowerCase()) {
        return device.id;
      }
    }
    return '';
  }

  Future<void> _rememberAudio() {
    return SavedAudio.write(
      SavedAudio(
        microphoneLabel: _microphoneLabel,
        speakerLabel: _speakerLabel,
      ),
    );
  }

  Future<void> _prepareAudio() async {
    if (_audioRefresh != null || microphoneId.isEmpty || speakerId.isEmpty) {
      await refreshAudioDevices();
      return;
    }
    await _pushAudioDevices();
  }

  Future<void> _pushAudioDevices() {
    return _softphone.setAudioDevices(
      microphoneId: microphoneId.isEmpty ? defaultMicrophoneId : microphoneId,
      speakerId: speakerId.isEmpty ? defaultSpeakerId : speakerId,
    );
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
    unawaited(_softphone.disconnect());
    super.dispose();
  }
}
