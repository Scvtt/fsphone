import 'dart:ffi';
import 'dart:io';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:fsphone/desktop/window_chrome.dart';

typedef _WndProcNative =
    IntPtr Function(IntPtr hwnd, Uint32 message, IntPtr wParam, IntPtr lParam);

final class _WndClass extends Struct {
  @Uint32()
  external int style;

  external Pointer<NativeFunction<_WndProcNative>> lpfnWndProc;

  @Int32()
  external int cbClsExtra;

  @Int32()
  external int cbWndExtra;

  @IntPtr()
  external int hInstance;

  @IntPtr()
  external int hIcon;

  @IntPtr()
  external int hCursor;

  @IntPtr()
  external int hbrBackground;

  external Pointer<Utf16> lpszMenuName;
  external Pointer<Utf16> lpszClassName;
}

/// Bottom-right incoming card painted to match the phone: dark surface,
/// the caller's name, and red Hang up / green Answer buttons.
class IncomingCard {
  IncomingCard({required this.onAnswer, required this.onHangUp});

  final void Function() onAnswer;
  final void Function() onHangUp;

  static const _actionMessage = 0x8001;
  static IncomingCard? _active;

  final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  final DynamicLibrary _gdi32 = DynamicLibrary.open('gdi32.dll');
  late final NativeCallable<_WndProcNative> _callback =
      NativeCallable.isolateLocal(_handleMessage, exceptionalReturn: 0);

  int _hwnd = 0;
  int _hover = 0;
  bool _classReady = false;
  bool _trackingLeave = false;
  Pointer<Utf16>? _className;
  Pointer<Utf16>? _uiFontName;
  Pointer<Utf16>? _iconFontName;
  final Map<int, int> _fonts = {};

  bool get isOpen => _hwnd != 0;

  void show({required String name, required String number}) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _active = this;
    _caller = name;
    _number = number.trim().isEmpty || number.trim() == name ? '' : number;
    final frame = incomingCallFrame();
    if (_hwnd == 0) {
      _create(frame);
    }
    if (_hwnd == 0) {
      return;
    }
    _move(
      _hwnd,
      frame.left.round(),
      frame.top.round(),
      frame.width.round(),
      frame.height.round(),
    );
    _round(frame.width.round(), frame.height.round());
    _invalidate();
    _showWindow(_hwnd, 5);
  }

  String _caller = '';
  String _number = '';

  void close() {
    final hwnd = _hwnd;
    _hwnd = 0;
    _hover = 0;
    if (_active == this) {
      _active = null;
    }
    if (hwnd != 0) {
      _destroyWindow(hwnd);
    }
  }

  void _create(Rect frame) {
    _ensureClass();
    if (!_classReady || _className == null) {
      return;
    }
    const topmost = 0x00000008;
    const tool = 0x00000080;
    const popup = 0x80000000;
    const visible = 0x10000000;
    const clips = 0x04000000 | 0x02000000;
    final title = 'FS Phone incoming'.toNativeUtf16();
    _hwnd = _createWindow(
      topmost | tool,
      _className!,
      title,
      popup | visible | clips,
      frame.left.round(),
      frame.top.round(),
      frame.width.round(),
      frame.height.round(),
      0,
      0,
      _module(),
      nullptr,
    );
    calloc.free(title);
    if (_hwnd == 0) {
      return;
    }
    _round(frame.width.round(), frame.height.round());
  }

  void _ensureClass() {
    if (_classReady) {
      return;
    }
    _className = 'FS_PHONE_INCOMING'.toNativeUtf16();
    final klass = calloc<_WndClass>();
    klass.ref
      ..style = 0x00020000
      ..lpfnWndProc = _callback.nativeFunction
      ..cbClsExtra = 0
      ..cbWndExtra = 0
      ..hInstance = _module()
      ..hIcon = 0
      ..hCursor = _loadCursor(32512)
      ..hbrBackground = 0
      ..lpszMenuName = nullptr
      ..lpszClassName = _className!;
    _classReady = _registerClass(klass) != 0;
    calloc.free(klass);
  }

  int _handleMessage(int hwnd, int message, int wParam, int lParam) {
    const paint = 0x000F;
    const erase = 0x0014;
    const mouseMove = 0x0200;
    const mouseLeave = 0x02A3;
    const buttonUp = 0x0202;
    const setCursor = 0x0020;
    if (message == erase) {
      return 1;
    }
    if (message == paint) {
      _paint(hwnd);
      return 0;
    }
    if (message == mouseMove) {
      final next = _hit(hwnd, _low(lParam), _high(lParam));
      if (next != _hover) {
        _hover = next;
        _invalidate();
      }
      if (!_trackingLeave) {
        _trackLeave(hwnd);
        _trackingLeave = true;
      }
      return 0;
    }
    if (message == mouseLeave) {
      _trackingLeave = false;
      if (_hover != 0) {
        _hover = 0;
        _invalidate();
      }
      return 0;
    }
    if (message == buttonUp) {
      final hit = _hit(hwnd, _low(lParam), _high(lParam));
      if (hit != 0) {
        _post(hwnd, _actionMessage, hit, 0);
      }
      return 0;
    }
    if (message == _actionMessage) {
      final card = _active;
      if (wParam == 1) {
        card?.onHangUp();
      } else if (wParam == 2) {
        card?.onAnswer();
      }
      return 0;
    }
    if (message == setCursor && _hover != 0) {
      _setCursor(_loadCursor(32649));
      return 1;
    }
    return _defWindowProc(hwnd, message, wParam, lParam);
  }

  void _paint(int hwnd) {
    final paintStruct = calloc<Uint8>(80);
    final screen = _beginPaint(hwnd, paintStruct);
    final size = _clientSize(hwnd);
    final width = size.$1;
    final height = size.$2;
    final memory = _createCompatibleDc(screen);
    final bitmap = _createCompatibleBitmap(screen, width, height);
    final previous = _selectObject(memory, bitmap);
    _fill(memory, 0, 0, width, height, 0x0031241B);
    final scale = width / 400;
    final pad = (18 * scale).round();
    _text(
      memory,
      'Incoming call',
      pad,
      (16 * scale).round(),
      width - pad,
      (36 * scale).round(),
      0x00D4C3B7,
      _font((12 * scale).round(), 600),
      0x0020 | 0x8000 | 0x0800,
    );
    _text(
      memory,
      _caller,
      pad,
      (40 * scale).round(),
      width - pad,
      (70 * scale).round(),
      0x00FFFFFF,
      _font((22 * scale).round(), 700),
      0x0020 | 0x8000 | 0x0800,
    );
    if (_number.isNotEmpty) {
      _text(
        memory,
        _number,
        pad,
        (72 * scale).round(),
        width - pad,
        (96 * scale).round(),
        0x00D4C3B7,
        _font((14 * scale).round(), 400),
        0x0020 | 0x8000 | 0x0800,
      );
    }
    final buttons = _buttons(width, height);
    _button(
      memory,
      buttons.$1,
      'Hang up',
      0xE778,
      _hover == 1 ? 0x005050EA : 0x003B3BE2,
    );
    _button(
      memory,
      buttons.$2,
      'Answer',
      0xE717,
      _hover == 2 ? 0x0066BE4A : 0x0055A81F,
    );
    _bitBlt(screen, width, height, memory);
    _selectObject(memory, previous);
    _deleteObject(bitmap);
    _deleteDc(memory);
    _endPaint(hwnd, paintStruct);
    calloc.free(paintStruct);
  }

  void _button(int hdc, (int, int, int, int) rect, String label, int icon, int color) {
    final left = rect.$1;
    final top = rect.$2;
    final right = rect.$3;
    final bottom = rect.$4;
    final radius = ((bottom - top) * 0.42).round();
    _roundRect(hdc, left, top, right, bottom, radius, color);
    final iconFont = _iconFont(((bottom - top) * 0.38).round());
    final labelFont = _font(((bottom - top) * 0.34).round(), 600);
    final iconWidth = (bottom - top) * 0.7;
    _text(
      hdc,
      String.fromCharCode(icon),
      left + 8,
      top,
      left + iconWidth.round(),
      bottom,
      0x00FFFFFF,
      iconFont,
      0x0004 | 0x0020 | 0x0001,
    );
    _text(
      hdc,
      label,
      left + iconWidth.round(),
      top,
      right - 8,
      bottom,
      0x00FFFFFF,
      labelFont,
      0x0004 | 0x0020 | 0x0001,
    );
  }

  int _hit(int hwnd, int x, int y) {
    final size = _clientSize(hwnd);
    final buttons = _buttons(size.$1, size.$2);
    if (_contains(buttons.$1, x, y)) {
      return 1;
    }
    if (_contains(buttons.$2, x, y)) {
      return 2;
    }
    return 0;
  }

  ((int, int, int, int), (int, int, int, int)) _buttons(int width, int height) {
    final scale = width / 400;
    final pad = (18 * scale).round();
    final gap = (10 * scale).round();
    final buttonHeight = (46 * scale).round();
    final top = height - pad - buttonHeight;
    final buttonWidth = ((width - pad * 2 - gap) / 2).round();
    return (
      (pad, top, pad + buttonWidth, top + buttonHeight),
      (
        pad + buttonWidth + gap,
        top,
        pad + buttonWidth + gap + buttonWidth,
        top + buttonHeight,
      ),
    );
  }

  bool _contains((int, int, int, int) rect, int x, int y) {
    return x >= rect.$1 && x < rect.$3 && y >= rect.$2 && y < rect.$4;
  }

  int _font(int height, int weight) {
    final key = height * 1000 + weight;
    final cached = _fonts[key];
    if (cached != null) {
      return cached;
    }
    _uiFontName ??= 'Segoe UI'.toNativeUtf16();
    final font = _createFont(-height, weight, _uiFontName!);
    _fonts[key] = font;
    return font;
  }

  int _iconFont(int height) {
    final key = -height;
    final cached = _fonts[key];
    if (cached != null) {
      return cached;
    }
    _iconFontName ??= 'Segoe MDL2 Assets'.toNativeUtf16();
    final font = _createFont(-height, 400, _iconFontName!);
    _fonts[key] = font;
    return font;
  }

  int _createFont(int height, int weight, Pointer<Utf16> face) {
    return _gdi32.lookupFunction<
      IntPtr Function(
        Int32,
        Int32,
        Int32,
        Int32,
        Int32,
        Uint32,
        Uint32,
        Uint32,
        Uint32,
        Uint32,
        Uint32,
        Uint32,
        Uint32,
        Pointer<Utf16>,
      ),
      int Function(
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        Pointer<Utf16>,
      )
    >('CreateFontW')(height, 0, 0, 0, weight, 0, 0, 0, 0, 0, 0, 5, 0, face);
  }

  void _text(
    int hdc,
    String text,
    int left,
    int top,
    int right,
    int bottom,
    int color,
    int font,
    int format,
  ) {
    final previous = _selectObject(hdc, font);
    _gdi32.lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
      'SetBkMode',
    )(hdc, 1);
    _gdi32.lookupFunction<Uint32 Function(IntPtr, Uint32), int Function(int, int)>(
      'SetTextColor',
    )(hdc, color);
    final rect = calloc<Int32>(4);
    final native = text.toNativeUtf16();
    rect[0] = left;
    rect[1] = top;
    rect[2] = right;
    rect[3] = bottom;
    _user32.lookupFunction<
      Int32 Function(IntPtr, Pointer<Utf16>, Int32, Pointer<Int32>, Uint32),
      int Function(int, Pointer<Utf16>, int, Pointer<Int32>, int)
    >('DrawTextW')(hdc, native, -1, rect, format);
    calloc.free(native);
    calloc.free(rect);
    _selectObject(hdc, previous);
  }

  void _fill(int hdc, int left, int top, int right, int bottom, int color) {
    final brush = _createBrush(color);
    final rect = calloc<Int32>(4);
    rect[0] = left;
    rect[1] = top;
    rect[2] = right;
    rect[3] = bottom;
    _user32.lookupFunction<
      Int32 Function(IntPtr, Pointer<Int32>, IntPtr),
      int Function(int, Pointer<Int32>, int)
    >('FillRect')(hdc, rect, brush);
    calloc.free(rect);
    _deleteObject(brush);
  }

  void _roundRect(
    int hdc,
    int left,
    int top,
    int right,
    int bottom,
    int radius,
    int color,
  ) {
    final brush = _createBrush(color);
    final previousBrush = _selectObject(hdc, brush);
    final previousPen = _selectObject(hdc, _stock(8));
    _gdi32.lookupFunction<
      Int32 Function(IntPtr, Int32, Int32, Int32, Int32, Int32, Int32),
      int Function(int, int, int, int, int, int, int)
    >('RoundRect')(hdc, left, top, right, bottom, radius, radius);
    _selectObject(hdc, previousPen);
    _selectObject(hdc, previousBrush);
    _deleteObject(brush);
  }

  (int, int) _clientSize(int hwnd) {
    final rect = calloc<Int32>(4);
    _user32.lookupFunction<
      Int32 Function(IntPtr, Pointer<Int32>),
      int Function(int, Pointer<Int32>)
    >('GetClientRect')(hwnd, rect);
    final size = (rect[2], rect[3]);
    calloc.free(rect);
    return size;
  }

  void _round(int width, int height) {
    if (_hwnd == 0) {
      return;
    }
    final radius = (18 * width / 400).round();
    final region = _gdi32.lookupFunction<
      IntPtr Function(Int32, Int32, Int32, Int32, Int32, Int32),
      int Function(int, int, int, int, int, int)
    >('CreateRoundRectRgn')(0, 0, width + 1, height + 1, radius, radius);
    _user32.lookupFunction<
      Int32 Function(IntPtr, IntPtr, Int32),
      int Function(int, int, int)
    >('SetWindowRgn')(_hwnd, region, 1);
  }

  void _invalidate() {
    if (_hwnd == 0) {
      return;
    }
    _user32.lookupFunction<
      Int32 Function(IntPtr, Pointer<Int32>, Int32),
      int Function(int, Pointer<Int32>, int)
    >('InvalidateRect')(_hwnd, nullptr, 0);
  }

  void _trackLeave(int hwnd) {
    final event = calloc<Uint32>(6);
    event[0] = 24;
    event[1] = 2;
    event.cast<IntPtr>()[1] = hwnd;
    _user32.lookupFunction<
      Int32 Function(Pointer<Uint32>),
      int Function(Pointer<Uint32>)
    >('TrackMouseEvent')(event);
    calloc.free(event);
  }

  int _loadCursor(int id) {
    return _user32.lookupFunction<
      IntPtr Function(IntPtr, IntPtr),
      int Function(int, int)
    >('LoadCursorW')(0, id);
  }

  void _setCursor(int cursor) {
    _user32.lookupFunction<IntPtr Function(IntPtr), int Function(int)>(
      'SetCursor',
    )(cursor);
  }

  int _beginPaint(int hwnd, Pointer<Uint8> paint) {
    return _user32.lookupFunction<
      IntPtr Function(IntPtr, Pointer<Uint8>),
      int Function(int, Pointer<Uint8>)
    >('BeginPaint')(hwnd, paint);
  }

  void _endPaint(int hwnd, Pointer<Uint8> paint) {
    _user32.lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint8>),
      int Function(int, Pointer<Uint8>)
    >('EndPaint')(hwnd, paint);
  }

  int _createCompatibleDc(int hdc) {
    return _gdi32.lookupFunction<IntPtr Function(IntPtr), int Function(int)>(
      'CreateCompatibleDC',
    )(hdc);
  }

  int _createCompatibleBitmap(int hdc, int width, int height) {
    return _gdi32.lookupFunction<
      IntPtr Function(IntPtr, Int32, Int32),
      int Function(int, int, int)
    >('CreateCompatibleBitmap')(hdc, width, height);
  }

  void _bitBlt(int destination, int width, int height, int source) {
    _gdi32.lookupFunction<
      Int32 Function(
        IntPtr,
        Int32,
        Int32,
        Int32,
        Int32,
        IntPtr,
        Int32,
        Int32,
        Uint32,
      ),
      int Function(int, int, int, int, int, int, int, int, int)
    >('BitBlt')(destination, 0, 0, width, height, source, 0, 0, 0x00CC0020);
  }

  int _selectObject(int hdc, int object) {
    return _gdi32.lookupFunction<
      IntPtr Function(IntPtr, IntPtr),
      int Function(int, int)
    >('SelectObject')(hdc, object);
  }

  int _stock(int which) {
    return _gdi32.lookupFunction<IntPtr Function(Int32), int Function(int)>(
      'GetStockObject',
    )(which);
  }

  int _createBrush(int color) {
    return _gdi32.lookupFunction<IntPtr Function(Uint32), int Function(int)>(
      'CreateSolidBrush',
    )(color);
  }

  void _deleteObject(int object) {
    _gdi32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'DeleteObject',
    )(object);
  }

  void _deleteDc(int hdc) {
    _gdi32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'DeleteDC',
    )(hdc);
  }

  int _module() {
    return DynamicLibrary.open('kernel32.dll').lookupFunction<
      IntPtr Function(Pointer<Utf16>),
      int Function(Pointer<Utf16>)
    >('GetModuleHandleW')(nullptr);
  }

  int _registerClass(Pointer<_WndClass> klass) {
    return _user32.lookupFunction<
      Uint16 Function(Pointer<_WndClass>),
      int Function(Pointer<_WndClass>)
    >('RegisterClassW')(klass);
  }

  int _createWindow(
    int exStyle,
    Pointer<Utf16> klass,
    Pointer<Utf16> title,
    int style,
    int x,
    int y,
    int width,
    int height,
    int parent,
    int menu,
    int instance,
    Pointer<Void> param,
  ) {
    return _user32.lookupFunction<
      IntPtr Function(
        Uint32,
        Pointer<Utf16>,
        Pointer<Utf16>,
        Uint32,
        Int32,
        Int32,
        Int32,
        Int32,
        IntPtr,
        IntPtr,
        IntPtr,
        Pointer<Void>,
      ),
      int Function(
        int,
        Pointer<Utf16>,
        Pointer<Utf16>,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        Pointer<Void>,
      )
    >('CreateWindowExW')(
      exStyle,
      klass,
      title,
      style,
      x,
      y,
      width,
      height,
      parent,
      menu,
      instance,
      param,
    );
  }

  void _showWindow(int hwnd, int command) {
    _user32.lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
      'ShowWindow',
    )(hwnd, command);
  }

  void _move(int hwnd, int x, int y, int width, int height) {
    _user32.lookupFunction<
      Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
      int Function(int, int, int, int, int, int, int)
    >('SetWindowPos')(hwnd, -1, x, y, width, height, 0x0010 | 0x0040);
  }

  void _destroyWindow(int hwnd) {
    _user32.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'DestroyWindow',
    )(hwnd);
  }

  void _post(int hwnd, int message, int wParam, int lParam) {
    _user32.lookupFunction<
      Int32 Function(IntPtr, Uint32, IntPtr, IntPtr),
      int Function(int, int, int, int)
    >('PostMessageW')(hwnd, message, wParam, lParam);
  }

  int _defWindowProc(int hwnd, int message, int wParam, int lParam) {
    return _user32.lookupFunction<
      IntPtr Function(IntPtr, Uint32, IntPtr, IntPtr),
      int Function(int, int, int, int)
    >('DefWindowProcW')(hwnd, message, wParam, lParam);
  }

  int _low(int value) => value & 0xFFFF;
  int _high(int value) => (value >> 16) & 0xFFFF;
}
