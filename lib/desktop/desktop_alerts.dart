import 'dart:io';

import 'package:fsphone/desktop/incoming_card.dart';
import 'package:fsphone/desktop/ring_player.dart';
import 'package:fsphone/desktop/window_chrome.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

/// Ringtone and the bottom-right incoming-call card.
///
/// The tray icon and its menu live in the Windows window, so a click there
/// does not wait for the Flutter window to wake up.
class DesktopAlerts {
  DesktopAlerts._();

  static IncomingCall? _shown;
  static bool _cardOpen = false;
  static bool? _hideOnClose;
  static PhoneController? _controller;
  static final IncomingCard _card = IncomingCard(
    onAnswer: _answer,
    onHangUp: _hangUp,
  );

  static Future<void> start(PhoneController controller) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _controller = controller;
    try {
      keepProcessResponsive();
      setHideOnClose(controller.runInBackground);
      controller.addListener(() => _onController(controller));
      _watchWindow(controller);
    } catch (error) {
      debugPrint('Desktop alerts were not started: $error');
    }
  }

  static void _watchWindow(PhoneController controller) {
    final window = WindowManager.instance.getCurrent();
    if (window == null) {
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        () => _watchWindow(controller),
      );
      return;
    }
    window.addListener((event) {
      if (event is WindowCloseRequestedEvent && controller.runInBackground) {
        event.request.cancel();
        window.hide();
      }
      _syncIncoming(controller);
    });
  }

  static void _onController(PhoneController controller) {
    if (_hideOnClose != controller.runInBackground) {
      _hideOnClose = controller.runInBackground;
      setHideOnClose(_hideOnClose!);
    }
    _syncIncoming(controller);
  }

  static void _answer() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    controller.answerIncoming();
    revealMainWindow();
    WidgetsBinding.instance.scheduleFrame();
  }

  static void _hangUp() {
    _controller?.declineIncoming();
    revealMainWindow();
    WidgetsBinding.instance.scheduleFrame();
  }

  static void _syncIncoming(PhoneController controller) {
    final ringing = controller.incoming;
    if (ringing == null) {
      if (_shown == null && !_cardOpen) {
        return;
      }
      _shown = null;
      _cardOpen = false;
      RingPlayer.stop();
      _card.close();
      return;
    }
    if (!identical(_shown, ringing)) {
      _shown = ringing;
      RingPlayer.start();
    }
    if (_inBackground()) {
      _card.show(name: ringing.name, number: ringing.number);
      _cardOpen = _card.isOpen;
    } else if (_cardOpen) {
      _cardOpen = false;
      _card.close();
    }
  }

  static bool _inBackground() {
    final window = WindowManager.instance.getCurrent();
    if (window == null) {
      return true;
    }
    if (window.isMinimized || !window.isVisible || !window.isFocused) {
      return true;
    }
    return window.occlusionState == WindowOcclusionState.occluded;
  }
}
