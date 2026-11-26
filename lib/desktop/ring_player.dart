import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Loops a generated North-American ring (440 Hz and 480 Hz, then a pause)
/// through the Windows default playback device until [stop] is called.
class RingPlayer {
  RingPlayer._();

  static final DynamicLibrary _winmm = DynamicLibrary.open('winmm.dll');
  static final int Function(Pointer<Uint8>, int, int) _play = _winmm
      .lookupFunction<
        Int32 Function(Pointer<Uint8>, IntPtr, Uint32),
        int Function(Pointer<Uint8>, int, int)
      >('PlaySoundW');

  static Pointer<Uint8>? _wav;

  static void start() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    stop();
    final bytes = _ringWav();
    final wav = calloc<Uint8>(bytes.length);
    wav.asTypedList(bytes.length).setAll(0, bytes);
    _wav = wav;
    // Async, in memory, loop, and do not fall back to a system beep.
    _play(wav, 0, 0x0001 | 0x0004 | 0x0008 | 0x0002);
  }

  static void stop() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _play(nullptr, 0, 0x0040);
    final wav = _wav;
    if (wav != null) {
      calloc.free(wav);
      _wav = null;
    }
  }

  static Uint8List _ringWav() {
    const sampleRate = 22050;
    const onSeconds = 1.2;
    const offSeconds = 2.4;
    final onSamples = (sampleRate * onSeconds).round();
    final offSamples = (sampleRate * offSeconds).round();
    final total = onSamples + offSamples;
    final data = ByteData(44 + total * 2);
    void text(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    data.setUint32(4, 36 + total * 2, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    text(36, 'data');
    data.setUint32(40, total * 2, Endian.little);
    for (var i = 0; i < onSamples; i++) {
      final t = i / sampleRate;
      var envelope = 1.0;
      const fade = 0.03;
      if (t < fade) {
        envelope = t / fade;
      } else if (t > onSeconds - fade) {
        envelope = (onSeconds - t) / fade;
      }
      final sample =
          envelope * 0.22 * (sin(2 * pi * 440 * t) + sin(2 * pi * 480 * t));
      data.setInt16(
        44 + i * 2,
        (sample * 32767).round().clamp(-32767, 32767),
        Endian.little,
      );
    }
    return data.buffer.asUint8List();
  }
}
