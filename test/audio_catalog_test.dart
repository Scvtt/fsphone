import 'package:flutter_test/flutter_test.dart';
import 'package:fsphone/audio/windows_audio.dart';

void main() {
  test(
    'Windows default is named and kept out of the duplicate role entries',
    () {
      final catalog = AudioCatalog.fromRaw(const [
        (id: 'default-mic', label: 'Default - Headset Microphone (Poly)'),
        (id: 'comms-mic', label: 'Communications - Headset Microphone (Poly)'),
        (id: 'poly', label: 'Headset Microphone (Poly)'),
        (id: 'realtek', label: 'Microphone (Realtek High Definition Audio)'),
      ]);

      expect(catalog.windowsDefaultName, 'Headset Microphone (Poly)');
      expect(catalog.windowsDefaultId, 'default-mic');
      expect(catalog.preferredId, 'poly');
    expect(catalog.idForName('Headset Microphone (Poly)'), 'poly');
    expect(catalog.idForLabel('Microphone (Realtek High Definition Audio)'), 'realtek');
      expect(catalog.devices.map((device) => device.id), ['poly', 'realtek']);
    },
  );

  test('The first device is the default when Windows does not prefix it', () {
    final catalog = AudioCatalog.fromRaw(const [
      (id: 'speakers', label: 'Speakers (Realtek)'),
      (id: 'hdmi', label: 'SAMSUNG'),
    ]);

    expect(catalog.windowsDefaultName, 'Speakers (Realtek)');
    expect(catalog.windowsDefaultId, 'speakers');
    expect(catalog.devices, hasLength(2));
  });
}
