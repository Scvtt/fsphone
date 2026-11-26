import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';

/// Credentials for a direct FreeSWITCH Sofia registration. The PBX is reached
/// over its existing WSS binding. No provisioning plugin is involved.
class SipAccount {
  const SipAccount({
    required this.webSocketUrl,
    required this.extension,
    required this.password,
    required this.domain,
    required this.allowBadCertificate,
    required this.iceServers,
  });

  final String webSocketUrl;
  final String extension;
  final String password;
  final String domain;
  final bool allowBadCertificate;
  final List<Map<String, String>> iceServers;
}

/// Events the SIP stack reports back into the phone session.
abstract class SoftphoneListener {
  void onRegistered();
  void onRegistrationFailed(String message);
  void onUnregistered();
  void onIncoming({
    required String name,
    required String number,
    required bool video,
  });
  void onCallEnded(String reason);

  /// The SIP dialog is up, but media may still be negotiating.
  void onCallAccepted();

  /// ICE is connected, so audio can pass.
  void onMediaReady();

  /// The consulted party left. The original call is still up.
  void onConsultEnded();

  /// False when the user already cancelled, so a late INVITE is hung up.
  bool acceptOutgoing();
}

/// A SIP user agent the phone session can drive without knowing the stack.
abstract class Softphone {
  set listener(SoftphoneListener? listener);

  Future<void> connect(SipAccount account);
  Future<void> disconnect();
  void register();
  Future<void> unregister();

  /// Returns false when the WebSocket is not up, so no INVITE was sent.
  Future<bool> invite(String target, {required bool video});
  void answer({required bool video});
  void decline();
  void hangup();
  void setMuted(bool muted);
  void setHeld(bool held);
  void sendDtmf(String tones);
  void refer(String target);

  /// Holds the current call and invites [target] so an attended transfer can
  /// be spoken to before it is completed.
  Future<void> startConsult(String target);

  /// Talk to the original caller again and hold the consult.
  void switchToCaller();

  /// Talk to the consulted party again and hold the original caller.
  void switchToConsult();

  /// REFER the original caller to [target], replacing the consult dialog.
  void completeConsult(String target);

  /// Hang up the consult and resume the original caller.
  void cancelConsult();

  /// [microphoneId] and [speakerId] are WebRTC device ids. Null follows the
  /// Windows default for the next call.
  Future<void> setAudioDevices({String? microphoneId, String? speakerId});
}

/// Puts the chosen Windows devices into the media constraints sip_ua sends
/// to getUserMedia. A microphone is `sourceId`. A speaker is `deviceId`.
class FsSipHelper extends SIPUAHelper {
  String? microphoneSourceId;
  String? speakerDeviceId;

  @override
  Map<String, dynamic> buildCallOptions([bool voiceonly = false]) {
    final options = super.buildCallOptions(voiceonly);
    final media = Map<String, dynamic>.from(
      options['mediaConstraints'] as Map<dynamic, dynamic>,
    );
    // Software echo cancellation holds the microphone until it can line
    // the mic up with the speaker. On Windows those are often different
    // devices, so the other party hears silence for a long time, or the
    // mic never opens. A headset already does this processing.
    final audio = <String, dynamic>{
      'echoCancellation': false,
      'googEchoCancellation': false,
      'googEchoCancellation2': false,
      'googDAEchoCancellation': false,
      'noiseSuppression': false,
      'googNoiseSuppression': false,
      'autoGainControl': false,
      'googAutoGainControl': false,
    };
    final microphone = microphoneSourceId;
    // Windows reads the capture device from optional.sourceId. A top-level
    // sourceId is ignored, and an empty one forces the virtual default
    // device, which does not capture.
    if (microphone != null && microphone.isNotEmpty) {
      audio['optional'] = <Map<String, String>>[
        <String, String>{'sourceId': microphone},
      ];
    }
    final speaker = speakerDeviceId;
    if (speaker != null && speaker.isNotEmpty) {
      audio['deviceId'] = speaker;
    }
    media['audio'] = audio;
    options['mediaConstraints'] = media;
    return options;
  }
}

/// SIP over WSS via sip_ua, with WebRTC media from flutter_webrtc.
class SofiaSoftphone extends Softphone implements SipUaHelperListener {
  SofiaSoftphone({SIPUAHelper? helper}) : _helper = helper ?? FsSipHelper();

  final SIPUAHelper _helper;
  SoftphoneListener? _listener;
  Call? _active;
  Call? _ringing;
  Call? _primary;
  Call? _consult;
  bool _consultPending = false;
  Timer? _mediaWatch;
  final Set<String> _microphoneOpened = <String>{};
  String _domain = '';
  bool _listening = false;

  @override
  set listener(SoftphoneListener? listener) => _listener = listener;

  @override
  Future<void> connect(SipAccount account) async {
    _domain = account.domain;
    if (!_listening) {
      _helper.addSipUaHelperListener(this);
      _listening = true;
    }
    final settings = UaSettings()
      ..webSocketUrl = account.webSocketUrl
      ..uri = 'sip:${account.extension}@${account.domain}'
      ..authorizationUser = account.extension
      ..password = account.password
      ..displayName = account.extension
      ..realm = account.domain
      ..transportType = TransportType.WS
      ..register = true
      ..register_expires = 300
      ..userAgent = 'FS Phone'
      ..dtmfMode = DtmfMode.RFC2833
      ..iceGatheringTimeout = 500;
    settings.webSocketSettings.allowBadCertificate =
        account.allowBadCertificate;
    settings.iceServers = account.iceServers;
    await _helper.start(settings);
  }

  @override
  Future<void> disconnect() async {
    _clearCalls();
    _helper.stop();
  }

  @override
  void register() => _helper.register();

  @override
  Future<void> unregister() async {
    try {
      await _helper.unregister();
    } catch (_) {
      // The stack throws if REGISTER has not completed. The toggle still
      // reflects what the user asked for.
    }
  }

  @override
  Future<bool> invite(String target, {required bool video}) {
    final dial = target.contains('@') ? target : 'sip:$target@$_domain';
    return _helper.call(dial, voiceOnly: !video);
  }

  @override
  void answer({required bool video}) {
    final ringing = _ringing;
    if (ringing == null) {
      return;
    }
    _active = ringing;
    _ringing = null;
    ringing.answer(_helper.buildCallOptions(!video));
    _armMediaWatch(ringing);
  }

  @override
  void decline() {
    final ringing = _ringing;
    _ringing = null;
    ringing?.hangup(<String, dynamic>{'status_code': 486});
  }

  @override
  void hangup() {
    final active = _active;
    final ringing = _ringing;
    final primary = _primary;
    final consult = _consult;
    _clearCalls();
    try {
      active?.hangup();
    } catch (_) {
      // The session can already be gone. The dialogs below are still closed.
    }
    try {
      ringing?.hangup(<String, dynamic>{'status_code': 486});
    } catch (_) {}
    if (primary != null && primary.id != active?.id) {
      try {
        primary.hangup();
      } catch (_) {}
    }
    if (consult != null && consult.id != active?.id) {
      try {
        consult.hangup();
      } catch (_) {}
    }
    try {
      _helper.terminateSessions(<String, dynamic>{});
    } catch (_) {
      // No user agent yet, so there is no dialog to cancel.
    }
  }

  @override
  void setMuted(bool muted) {
    final active = _active;
    if (active == null) {
      return;
    }
    if (muted) {
      active.mute(true, false);
    } else {
      active.unmute(true, false);
    }
  }

  @override
  void setHeld(bool held) {
    final active = _active;
    if (active == null) {
      return;
    }
    if (held) {
      active.hold();
    } else {
      active.unhold();
    }
  }

  @override
  void sendDtmf(String tones) => _active?.sendDTMF(tones);

  @override
  void refer(String target) {
    _talking?.refer(_dial(target));
  }

  @override
  Future<void> startConsult(String target) async {
    final primary = _active;
    if (primary == null) {
      return;
    }
    _primary = primary;
    _consult = null;
    _consultPending = true;
    try {
      primary.hold();
    } catch (_) {
      // The consult can still be placed if the hold re-INVITE fails.
    }
    final sent = await invite(target, video: false);
    if (!sent) {
      _consultPending = false;
      _primary = null;
      try {
        primary.unhold();
      } catch (_) {}
    }
  }

  @override
  void switchToCaller() {
    _hold(_consult, true);
    _hold(_primary, false);
    _active = _primary;
  }

  @override
  void switchToConsult() {
    _hold(_primary, true);
    _hold(_consult, false);
    if (_consult != null) {
      _active = _consult;
    }
  }

  @override
  void completeConsult(String target) {
    final primary = _primary ?? _active;
    final consult = _consult;
    _clearCalls();
    if (primary == null) {
      return;
    }
    final session = consult?.session;
    final callId = session?.call_id;
    final fromTag = session?.from_tag;
    final toTag = session?.to_tag;
    if (session != null &&
        callId != null &&
        callId.isNotEmpty &&
        fromTag != null &&
        fromTag.isNotEmpty &&
        toTag != null &&
        toTag.isNotEmpty) {
      primary.refer(_dial(target), <String, dynamic>{
        'replaces': session,
        'extraHeaders': <dynamic>[],
      });
      return;
    }
    primary.refer(_dial(target));
  }

  @override
  void cancelConsult() {
    final consult = _consult;
    final primary = _primary;
    _consult = null;
    _consultPending = false;
    _primary = null;
    _active = primary;
    try {
      consult?.hangup();
    } catch (_) {}
    _hold(primary, false);
  }

  @override
  Future<void> setAudioDevices({
    String? microphoneId,
    String? speakerId,
  }) async {
    final helper = _helper;
    if (helper is FsSipHelper) {
      helper.microphoneSourceId = microphoneId;
      helper.speakerDeviceId = speakerId;
    }
    await _selectDevices(microphoneId, speakerId);
  }

  Call? get _talking => _active;

  void _clearCalls() {
    _mediaWatch?.cancel();
    _mediaWatch = null;
    _microphoneOpened.clear();
    _active = null;
    _ringing = null;
    _primary = null;
    _consult = null;
    _consultPending = false;
  }

  void _armMediaWatch(Call call) {
    _mediaWatch?.cancel();
    var ticks = 0;
    _mediaWatch = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      ticks++;
      final stillHere = call.id == _active?.id ||
          call.id == _consult?.id ||
          call.id == _primary?.id;
      if (!stillHere) {
        timer.cancel();
        return;
      }
      final ice = call.peerConnection?.iceConnectionState;
      final ready =
          ice == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          ice == RTCIceConnectionState.RTCIceConnectionStateCompleted;
      if (ready || ticks >= 20) {
        timer.cancel();
        _mediaWatch = null;
        unawaited(_announceReady(call));
      }
    });
  }

  Future<void> _announceReady(Call call) async {
    await _ensureMicrophone(call);
    final id = call.id;
    if (id == _active?.id || id == _consult?.id || id == _primary?.id) {
      _listener?.onMediaReady();
    }
  }

  /// Opens the microphone as soon as the other party answers. Waiting for
  /// ICE left the track silent for about twelve seconds, which is when the
  /// old fallback restarted it.
  Future<void> _ensureMicrophone(Call call, {bool retry = true}) async {
    final id = call.id;
    if (id == null || call.direction == Direction.incoming) {
      return;
    }
    if (id != _active?.id && id != _consult?.id && id != _primary?.id) {
      return;
    }
    if (_microphoneOpened.contains(id)) {
      return;
    }
    _microphoneOpened.add(id);
    final opened = await _restartMicrophone(call);
    if (opened) {
      return;
    }
    _microphoneOpened.remove(id);
    if (!retry) {
      return;
    }
    if (id != _active?.id && id != _consult?.id && id != _primary?.id) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _ensureMicrophone(call, retry: false);
  }

  Future<bool> _restartMicrophone(Call call) async {
    final connection = call.peerConnection;
    if (connection == null) {
      return false;
    }
    final tracks = <MediaStreamTrack>[];
    for (final MediaStream? stream in connection.getLocalStreams()) {
      if (stream == null) {
        continue;
      }
      tracks.addAll(stream.getAudioTracks());
    }
    if (tracks.isEmpty) {
      return false;
    }
    // A disabled track is the mute button. Leave it alone.
    if (tracks.any((MediaStreamTrack track) => !track.enabled)) {
      return true;
    }
    for (final MediaStreamTrack track in tracks) {
      track.enabled = false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final helper = _helper;
    if (helper is FsSipHelper) {
      await _selectDevices(helper.microphoneSourceId, null);
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final id = call.id;
    if (id != _active?.id && id != _consult?.id && id != _primary?.id) {
      return false;
    }
    for (final MediaStreamTrack track in tracks) {
      track.enabled = true;
    }
    return true;
  }

  String _dial(String target) {
    return target.contains('@') ? target : 'sip:$target@$_domain';
  }

  void _hold(Call? call, bool held) {
    if (call == null) {
      return;
    }
    try {
      if (held) {
        call.hold();
      } else {
        call.unhold();
      }
    } catch (_) {}
  }

  Future<void> _selectDevices(String? microphoneId, String? speakerId) async {
    final microphone = microphoneId;
    if (microphone != null && microphone.isNotEmpty) {
      try {
        await Helper.selectAudioInput(microphone);
      } catch (_) {
        // The id can disappear if Windows unplugs the device.
      }
    }
    final speaker = speakerId;
    if (speaker != null && speaker.isNotEmpty) {
      try {
        await Helper.selectAudioOutput(speaker);
      } catch (_) {
        // Playback stays on the previous device when the id is gone.
      }
    }
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    switch (state.state) {
      case RegistrationStateEnum.REGISTERED:
        _listener?.onRegistered();
      case RegistrationStateEnum.REGISTRATION_FAILED:
        _listener?.onRegistrationFailed(_cause(state.cause));
      case RegistrationStateEnum.UNREGISTERED:
        _listener?.onUnregistered();
      case RegistrationStateEnum.NONE:
      case null:
        break;
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        if (call.direction == Direction.incoming) {
          if (_active != null) {
            call.hangup(<String, dynamic>{'status_code': 486});
            return;
          }
          _ringing = call;
          var video = false;
          try {
            video = call.remote_has_video;
          } catch (_) {
            video = false;
          }
          _listener?.onIncoming(
            name: _label(call),
            number: call.remote_identity ?? '',
            video: video,
          );
        } else if (_consultPending) {
          _consult = call;
          _consultPending = false;
          _active = call;
        } else if (_active != null || _listener?.acceptOutgoing() != true) {
          // A cancelled or extra INVITE must not stay up and ring later.
          call.hangup();
        } else {
          _active = call;
        }
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        if (_consult?.id == call.id) {
          _consult = null;
          _consultPending = false;
          if (_primary != null) {
            _active = _primary;
            _hold(_primary, false);
            _listener?.onConsultEnded();
          }
          break;
        }
        if (_primary?.id == call.id) {
          _primary = null;
          final consult = _consult;
          _consult = null;
          _consultPending = false;
          try {
            consult?.hangup();
          } catch (_) {}
        }
        final endedActive = _active?.id == call.id;
        final endedRinging = _ringing?.id == call.id;
        if (endedRinging) {
          _ringing = null;
        }
        if (endedActive) {
          _active = null;
        }
        if (endedActive || endedRinging) {
          _listener?.onCallEnded(_cause(state.cause));
        }
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        if (call.id == _active?.id ||
            call.id == _consult?.id ||
            call.id == _primary?.id) {
          // Ringing and early media stay on "Calling…". The timer and
          // "Connecting…" start only after the other party answers.
          _listener?.onCallAccepted();
          unawaited(_ensureMicrophone(call));
          _armMediaWatch(call);
        }
      case CallStateEnum.NONE:
      case CallStateEnum.STREAM:
      case CallStateEnum.UNMUTED:
      case CallStateEnum.MUTED:
      case CallStateEnum.CONNECTING:
      case CallStateEnum.PROGRESS:
      case CallStateEnum.REFER:
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
        break;
    }
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}

  String _label(Call call) {
    final name = call.remote_display_name?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    final number = call.remote_identity?.trim() ?? '';
    return number.isEmpty ? 'Unknown' : number;
  }

  String _cause(Object? cause) {
    if (cause == null) {
      return 'The PBX ended the request.';
    }
    final dynamic details = cause;
    final reason = (details.reason_phrase as String?)?.trim();
    if (reason != null && reason.isNotEmpty) {
      return reason;
    }
    final text = (details.cause as String?)?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    return cause.toString();
  }
}
