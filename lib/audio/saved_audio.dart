import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// The microphone and speaker the user picked, kept across restarts.
///
/// An empty label means "follow the Windows communications device".
class SavedAudio {
  const SavedAudio({
    required this.microphoneLabel,
    required this.speakerLabel,
  });

  final String microphoneLabel;
  final String speakerLabel;

  bool get followMicrophone => microphoneLabel.isEmpty;
  bool get followSpeaker => speakerLabel.isEmpty;

  static const _mic = 'fsphone.microphone';
  static const _speaker = 'fsphone.speaker';
  static const _written = 'fsphone.audio.saved';

  static Future<SavedAudio?> read() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_written) != true) {
      return null;
    }
    return SavedAudio(
      microphoneLabel: prefs.getString(_mic) ?? '',
      speakerLabel: prefs.getString(_speaker) ?? '',
    );
  }

  static Future<void> write(SavedAudio audio) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_written, true);
    await prefs.setString(_mic, audio.microphoneLabel);
    await prefs.setString(_speaker, audio.speakerLabel);
  }
}
