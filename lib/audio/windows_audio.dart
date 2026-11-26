import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// One microphone or speaker the user can pick.
class AudioDevice {
  const AudioDevice({required this.id, required this.label});

  final String id;
  final String label;
}

/// Physical devices plus the name Windows is currently using as the default.
class AudioCatalog {
  const AudioCatalog({
    required this.devices,
    required this.windowsDefaultName,
    required this.windowsDefaultId,
  });

  final List<AudioDevice> devices;
  final String windowsDefaultName;
  final String? windowsDefaultId;

  /// Physical device that matches [name]. The role entry named "Default - …"
  /// is not a real capture device, so the Windows friendly name is matched
  /// against the real endpoints.
  String? idForName(String name) {
    final wanted = name.trim().toLowerCase();
    if (wanted.isEmpty) {
      return preferredId;
    }
    for (final device in devices) {
      if (device.label.toLowerCase() == wanted) {
        return device.id;
      }
    }
    for (final device in devices) {
      final label = device.label.toLowerCase();
      if (label.contains(wanted) || wanted.contains(label)) {
        return device.id;
      }
    }
    return preferredId;
  }

  String? idForLabel(String label) {
    final wanted = label.trim().toLowerCase();
    for (final device in devices) {
      if (device.label.toLowerCase() == wanted) {
        return device.id;
      }
    }
    return null;
  }

  /// Physical device that matches the Windows default. The role entry named
  /// "Default - …" is not a real capture device.
  String? get preferredId {
    for (final device in devices) {
      if (device.label == windowsDefaultName) {
        return device.id;
      }
    }
    return windowsDefaultId;
  }

  static const empty = AudioCatalog(
    devices: <AudioDevice>[],
    windowsDefaultName: '',
    windowsDefaultId: null,
  );

  /// WebRTC lists the Windows default and communications roles ahead of the
  /// physical endpoints, with labels such as "Default - Headset".
  factory AudioCatalog.fromRaw(List<({String id, String label})> raw) {
    const defaultPrefixes = <String>['default - ', 'default – ', 'default — '];
    const communicationPrefixes = <String>[
      'communications - ',
      'communications – ',
      'communications — ',
      'communication - ',
      'communication – ',
      'communication — ',
    ];

    String? stripped(String label, List<String> prefixes) {
      final lower = label.toLowerCase();
      for (final prefix in prefixes) {
        if (lower.startsWith(prefix)) {
          return label.substring(prefix.length).trim();
        }
      }
      return null;
    }

    String? defaultName;
    String? defaultId;
    final physical = <AudioDevice>[];
    for (final device in raw) {
      final label = device.label.trim();
      if (label.isEmpty || device.id.isEmpty) {
        continue;
      }
      final asDefault = stripped(label, defaultPrefixes);
      if (asDefault != null) {
        defaultName ??= asDefault.isEmpty ? label : asDefault;
        defaultId ??= device.id;
        continue;
      }
      if (stripped(label, communicationPrefixes) != null) {
        continue;
      }
      physical.add(AudioDevice(id: device.id, label: label));
    }

    if (defaultName == null && physical.isNotEmpty) {
      defaultName = physical.first.label;
      defaultId = physical.first.id;
    }

    return AudioCatalog(
      devices: physical,
      windowsDefaultName: defaultName ?? '',
      windowsDefaultId: defaultId,
    );
  }
}

/// Reads capture and playback devices from the Windows WebRTC audio layer.
class WindowsAudio {
  static Future<AudioCatalog> microphones() => _load('audioinput');

  static Future<AudioCatalog> speakers() => _load('audiooutput');

  static Future<AudioCatalog> _load(String kind) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return AudioCatalog.empty;
    }
    final found = await Helper.enumerateDevices(kind);
    return AudioCatalog.fromRaw([
      for (final device in found) (id: device.deviceId, label: device.label),
    ]);
  }
}
