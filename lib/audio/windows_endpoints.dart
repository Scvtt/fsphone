import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// The two Windows roles for one direction (microphone or speaker).
class WindowsEndpointNames {
  const WindowsEndpointNames({
    required this.console,
    required this.communications,
  });

  /// The general Windows default device.
  final String console;

  /// The device Windows uses for calls.
  final String communications;
}

/// Reads the live Windows default devices. WebRTC's "Default - …" label is
/// the general device and can stay on a virtual cable after the
/// communications device has been changed.
class WindowsEndpoints {
  static WindowsEndpointNames? microphones() => _read(1);

  static WindowsEndpointNames? speakers() => _read(0);

  static WindowsEndpointNames? _read(int dataFlow) {
    if (Platform.environment.containsKey('FLUTTER_TEST') &&
        !Platform.environment.containsKey('FSPHONE_READ_ENDPOINTS')) {
      return null;
    }
    try {
      return _Endpoints().read(dataFlow);
    } catch (_) {
      return null;
    }
  }
}

final class _Guid extends Struct {
  @Uint32()
  external int data1;
  @Uint16()
  external int data2;
  @Uint16()
  external int data3;
  @Uint8()
  external int b0;
  @Uint8()
  external int b1;
  @Uint8()
  external int b2;
  @Uint8()
  external int b3;
  @Uint8()
  external int b4;
  @Uint8()
  external int b5;
  @Uint8()
  external int b6;
  @Uint8()
  external int b7;
}

final class _PropertyKey extends Struct {
  external _Guid fmtid;
  @Uint32()
  external int pid;
}

class _Endpoints {
  _Endpoints() {
    _ole32 = DynamicLibrary.open('ole32.dll');
    _coInitialize = _ole32
        .lookupFunction<Int32 Function(Pointer<Void>, Uint32), int Function(Pointer<Void>, int)>(
          'CoInitializeEx',
        );
    _coCreate = _ole32
        .lookupFunction<
          Int32 Function(Pointer<_Guid>, Pointer<Void>, Uint32, Pointer<_Guid>, Pointer<Pointer<Void>>),
          int Function(Pointer<_Guid>, Pointer<Void>, int, Pointer<_Guid>, Pointer<Pointer<Void>>)
        >('CoCreateInstance');
    _propClear = _ole32
        .lookupFunction<Int32 Function(Pointer<Uint8>), int Function(Pointer<Uint8>)>(
          'PropVariantClear',
        );
  }

  late final DynamicLibrary _ole32;
  late final int Function(Pointer<Void>, int) _coInitialize;
  late final int Function(
    Pointer<_Guid>,
    Pointer<Void>,
    int,
    Pointer<_Guid>,
    Pointer<Pointer<Void>>,
  )
  _coCreate;
  late final int Function(Pointer<Uint8>) _propClear;

  WindowsEndpointNames? read(int dataFlow) {
    _coInitialize(nullptr, 2);
    final clsid = _guid(0xBCDE0395, 0xE52F, 0x467C, [
      0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E, // ignore: unused
    ]);
    final iid = _guid(0xA95664D2, 0x9614, 0x4F35, [
      0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6,
    ]);
    final enumeratorOut = calloc<Pointer<Void>>();
    try {
      final created = _coCreate(clsid, nullptr, 1, iid, enumeratorOut);
      if (created < 0 || enumeratorOut.value == nullptr) {
        return null;
      }
      final enumerator = enumeratorOut.value;
      final console = _friendlyName(enumerator, dataFlow, 0) ?? '';
      final communications = _friendlyName(enumerator, dataFlow, 2) ?? '';
      _release(enumerator);
      if (console.isEmpty && communications.isEmpty) {
        return null;
      }
      return WindowsEndpointNames(
        console: console,
        communications: communications.isEmpty ? console : communications,
      );
    } finally {
      calloc.free(clsid);
      calloc.free(iid);
      calloc.free(enumeratorOut);
    }
  }

  String? _friendlyName(Pointer<Void> enumerator, int dataFlow, int role) {
    final deviceOut = calloc<Pointer<Void>>();
    try {
      final hr = _vtable(enumerator, 4)
          .cast<
            NativeFunction<
              Int32 Function(Pointer<Void>, Int32, Int32, Pointer<Pointer<Void>>)
            >
          >()
          .asFunction<
            int Function(Pointer<Void>, int, int, Pointer<Pointer<Void>>)
          >()(enumerator, dataFlow, role, deviceOut);
      if (hr < 0 || deviceOut.value == nullptr) {
        return null;
      }
      final device = deviceOut.value;
      final storeOut = calloc<Pointer<Void>>();
      try {
        final opened = _vtable(device, 4)
            .cast<
              NativeFunction<
                Int32 Function(Pointer<Void>, Uint32, Pointer<Pointer<Void>>)
              >
            >()
            .asFunction<
              int Function(Pointer<Void>, int, Pointer<Pointer<Void>>)
            >()(device, 0, storeOut);
        if (opened < 0 || storeOut.value == nullptr) {
          return null;
        }
        final store = storeOut.value;
        final name = _readFriendlyName(store);
        _release(store);
        return name;
      } finally {
        calloc.free(storeOut);
        _release(device);
      }
    } finally {
      calloc.free(deviceOut);
    }
  }

  String? _readFriendlyName(Pointer<Void> store) {
    final key = calloc<_PropertyKey>();
    final variant = calloc<Uint8>(24);
    try {
      final fmtid = key.ref.fmtid;
      fmtid.data1 = 0xA45C254E;
      fmtid.data2 = 0xDF1C;
      fmtid.data3 = 0x4EFD;
      fmtid.b0 = 0x80;
      fmtid.b1 = 0x20;
      fmtid.b2 = 0x67;
      fmtid.b3 = 0xD1;
      fmtid.b4 = 0x46;
      fmtid.b5 = 0xA8;
      fmtid.b6 = 0x50;
      fmtid.b7 = 0xE0;
      key.ref.pid = 14;
      final hr = _vtable(store, 5)
          .cast<
            NativeFunction<
              Int32 Function(Pointer<Void>, Pointer<_PropertyKey>, Pointer<Uint8>)
            >
          >()
          .asFunction<
            int Function(Pointer<Void>, Pointer<_PropertyKey>, Pointer<Uint8>)
          >()(store, key, variant);
      if (hr < 0) {
        return null;
      }
      final vt = variant.cast<Uint16>().value;
      if (vt != 31) {
        return null;
      }
      final text = (variant + 8).cast<Pointer<Utf16>>().value;
      if (text == nullptr) {
        return null;
      }
      return text.toDartString().trim();
    } finally {
      _propClear(variant);
      calloc.free(variant);
      calloc.free(key);
    }
  }

  Pointer<Void> _vtable(Pointer<Void> object, int index) {
    final table = object.cast<Pointer<Pointer<Void>>>().value;
    return table[index];
  }

  void _release(Pointer<Void> object) {
    if (object == nullptr) {
      return;
    }
    _vtable(object, 2)
        .cast<NativeFunction<Uint32 Function(Pointer<Void>)>>()
        .asFunction<int Function(Pointer<Void>)>()(object);
  }

  Pointer<_Guid> _guid(int data1, int data2, int data3, List<int> rest) {
    final guid = calloc<_Guid>();
    guid.ref
      ..data1 = data1
      ..data2 = data2
      ..data3 = data3
      ..b0 = rest[0]
      ..b1 = rest[1]
      ..b2 = rest[2]
      ..b3 = rest[3]
      ..b4 = rest[4]
      ..b5 = rest[5]
      ..b6 = rest[6]
      ..b7 = rest[7];
    return guid;
  }
}
