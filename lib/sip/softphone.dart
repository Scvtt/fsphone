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

  /// [microphoneId] and [speakerId] are WebRTC device ids. Null follows the
  /// Windows default for the next call.
  void setAudioDevices({String? microphoneId, String? speakerId});
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
    final audio = <String, dynamic>{
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
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
      ..iceGatheringTimeout = 5000;
    settings.webSocketSettings.allowBadCertificate =
        account.allowBadCertificate;
    settings.iceServers = account.iceServers;
    await _helper.start(settings);
  }

  @override
  Future<void> disconnect() async {
    _active = null;
    _ringing = null;
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
    _active = null;
    _ringing = null;
    try {
      active?.hangup();
    } catch (_) {
      // The session can already be gone. The dialogs below are still closed.
    }
    try {
      ringing?.hangup(<String, dynamic>{'status_code': 486});
    } catch (_) {}
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
    final dial = target.contains('@') ? target : 'sip:$target@$_domain';
    _active?.refer(dial);
  }

  @override
  void setAudioDevices({String? microphoneId, String? speakerId}) {
    final helper = _helper;
    if (helper is FsSipHelper) {
      helper.microphoneSourceId = microphoneId;
      helper.speakerDeviceId = speakerId;
    }
    unawaited(_selectDevices(microphoneId, speakerId));
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
        } else if (_active != null || _listener?.acceptOutgoing() != true) {
          // A cancelled or extra INVITE must not stay up and ring later.
          call.hangup();
        } else {
          _active = call;
        }
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
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
      case CallStateEnum.NONE:
      case CallStateEnum.STREAM:
      case CallStateEnum.UNMUTED:
      case CallStateEnum.MUTED:
      case CallStateEnum.CONNECTING:
      case CallStateEnum.PROGRESS:
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
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
