import 'package:fsphone/sip/softphone.dart';

/// Completes registration immediately so widget tests can open the shell
/// without a PBX. The Windows app does not use this.
class TestSoftphone implements Softphone {
  @override
  SoftphoneListener? listener;

  @override
  Future<void> connect(SipAccount account) async {
    listener?.onRegistered();
  }

  @override
  Future<void> disconnect() async {}

  @override
  void register() {}

  @override
  Future<void> unregister() async {}

  @override
  Future<bool> invite(String target, {required bool video}) async => true;

  @override
  void answer({required bool video}) {}

  @override
  void decline() {}

  @override
  void hangup() {}

  @override
  void setMuted(bool muted) {}

  @override
  void setHeld(bool held) {}

  @override
  void sendDtmf(String tones) {}

  @override
  void refer(String target) {}

  @override
  Future<void> startConsult(String target) async {}

  @override
  void switchToCaller() {}

  @override
  void switchToConsult() {}

  @override
  void completeConsult(String target) {}

  @override
  void cancelConsult() {}

  @override
  Future<void> setAudioDevices({
    String? microphoneId,
    String? speakerId,
  }) async {}
}
