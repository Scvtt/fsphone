import 'dart:ffi';
import 'dart:ui';

import 'package:ffi/ffi.dart';

/// Bottom-right of the Windows work area, sized for the incoming-call card.
Rect incomingCallFrame() {
  final user32 = DynamicLibrary.open('user32.dll');
  final workArea = user32
      .lookupFunction<
        Int32 Function(Uint32, Uint32, Pointer<Int32>, Uint32),
        int Function(int, int, Pointer<Int32>, int)
      >('SystemParametersInfoW');
  final rect = calloc<Int32>(4);
  try {
    workArea(0x0030, 0, rect, 0);
    var scale = 1.0;
    try {
      final dpi = user32.lookupFunction<Uint32 Function(), int Function()>(
        'GetDpiForSystem',
      )();
      if (dpi > 0) {
        scale = dpi / 96;
      }
    } catch (_) {
      scale = 1;
    }
    final width = 400 * scale;
    final height = 196 * scale;
    final margin = 16 * scale;
    return Rect.fromLTWH(
      rect[2] - width - margin,
      rect[3] - height - margin,
      width,
      height,
    );
  } finally {
    calloc.free(rect);
  }
}

/// Ask Windows not to throttle this process while it is in the background.
void keepProcessResponsive() {
  final kernel = DynamicLibrary.open('kernel32.dll');
  final info = calloc<Uint32>(3);
  try {
    info[0] = 1;
    info[1] = 0x1;
    info[2] = 0;
    kernel
        .lookupFunction<
          Int32 Function(IntPtr, Int32, Pointer<Uint32>, Uint32),
          int Function(int, int, Pointer<Uint32>, int)
        >('SetProcessInformation')(-1, 4, info, 12);
  } catch (_) {
    // Older Windows builds ignore the request. The phone still runs.
  } finally {
    calloc.free(info);
  }
}

int findMainWindow() {
  final user32 = DynamicLibrary.open('user32.dll');
  final findWindow = user32
      .lookupFunction<
        IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
        int Function(Pointer<Utf16>, Pointer<Utf16>)
      >('FindWindowW');
  final windowClass = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
  final title = 'FS Phone'.toNativeUtf16();
  try {
    final named = findWindow(windowClass, title);
    if (named != 0) {
      return named;
    }
    return findWindow(windowClass, nullptr);
  } finally {
    calloc.free(windowClass);
    calloc.free(title);
  }
}

/// Brings the phone window back from the tray.
void revealMainWindow() {
  final hwnd = findMainWindow();
  if (hwnd == 0) {
    return;
  }
  final user32 = DynamicLibrary.open('user32.dll');
  final show = user32
      .lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
        'ShowWindow',
      );
  show(hwnd, 5);
  show(hwnd, 9);
  user32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
    'SetForegroundWindow',
  )(hwnd);
}

/// Closing the window hides it, unless [hide] is false.
void setHideOnClose(bool hide) {
  final hwnd = findMainWindow();
  if (hwnd == 0) {
    return;
  }
  final user32 = DynamicLibrary.open('user32.dll');
  final setProp = user32
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Utf16>, IntPtr),
        int Function(int, Pointer<Utf16>, int)
      >('SetPropW');
  final removeProp = user32
      .lookupFunction<
        IntPtr Function(IntPtr, Pointer<Utf16>),
        int Function(int, Pointer<Utf16>)
      >('RemovePropW');
  final prop = 'FsPhoneQuitOnClose'.toNativeUtf16();
  try {
    if (hide) {
      removeProp(hwnd, prop);
    } else {
      setProp(hwnd, prop, 1);
    }
  } finally {
    calloc.free(prop);
  }
}
