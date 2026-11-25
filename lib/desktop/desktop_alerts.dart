import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows tray icon and toast plumbing.
///
/// Toasts are the system notification in the bottom-right. Answer and Decline
/// are wired back into the phone UI. No ringtone or audio device is opened.
class DesktopAlerts {
  DesktopAlerts._();

  // Held so the native tray icon and menu are not collected.
  // ignore: unused_field
  static TrayIcon? _tray;
  // ignore: unused_field
  static Menu? _menu;

  static Future<void> start(PhoneController controller) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    try {
      await localNotifier.setup(
        appName: 'FS Phone',
        shortcutPolicy: ShortcutPolicy.ignore,
      );
      controller.presentIncoming = (call) => _present(controller, call);
      await _installTray(controller);
    } catch (error) {
      debugPrint('Desktop alerts were not started: $error');
    }
  }

  static Future<void> _present(
    PhoneController controller,
    IncomingCall call,
  ) async {
    if (!_windowNeedsToast()) {
      return;
    }
    final notification = LocalNotification(
      identifier: 'incoming-${call.number}',
      title: 'Incoming call',
      body: '${call.name} · ${call.number}',
      actions: [
        LocalNotificationAction(text: 'Answer'),
        LocalNotificationAction(text: 'Decline'),
      ],
    );
    notification.onClick = () {
      _bringToFront();
    };
    notification.onClickAction = (index) {
      if (index == 0) {
        controller.answerIncoming();
        _bringToFront();
      } else {
        controller.declineIncoming();
      }
    };
    await notification.show();
  }

  static bool _windowNeedsToast() {
    final window = WindowManager.instance.getCurrent();
    if (window == null) {
      return true;
    }
    if (window.isMinimized || !window.isVisible || !window.isFocused) {
      return true;
    }
    return window.occlusionState == WindowOcclusionState.occluded;
  }

  static void _bringToFront() {
    final window = WindowManager.instance.getCurrent();
    if (window == null) {
      return;
    }
    if (window.isMinimized) {
      window.restore();
    }
    window.show();
    window.focus();
  }

  static Future<void> _installTray(PhoneController controller) async {
    final icon = ImageAsset.fromAsset('assets/app_icon.ico');
    final trayIcon = TrayIcon.create();
    final menu = Menu.create();
    if (icon == null || trayIcon == null || menu == null) {
      return;
    }
    final showWindow = MenuItem.createWithLabelAndType(
      'Show FS Phone',
      MenuItemType.normal,
    );
    final simulate = MenuItem.createWithLabelAndType(
      'Simulate incoming call',
      MenuItemType.normal,
    );
    final separator = MenuItem.createWithLabelAndType(
      '',
      MenuItemType.separator,
    );
    final exit = MenuItem.createWithLabelAndType('Exit', MenuItemType.normal);
    if (showWindow == null ||
        simulate == null ||
        separator == null ||
        exit == null) {
      return;
    }
    showWindow.addListener((event) {
      if (event is MenuItemClickedEvent) {
        _bringToFront();
      }
    });
    simulate.addListener((event) {
      if (event is MenuItemClickedEvent) {
        controller.simulateIncomingCall();
      }
    });
    exit.addListener((event) {
      if (event is MenuItemClickedEvent) {
        exitApplication();
      }
    });
    menu.addItem(showWindow);
    menu.addItem(simulate);
    menu.addItem(separator);
    menu.addItem(exit);
    trayIcon
      ..icon = icon
      ..setTooltip('FS Phone')
      ..setContextMenu(menu)
      ..setContextMenuTrigger(ContextMenuTrigger.rightClicked)
      ..setVisible(true);
    _tray = trayIcon;
    _menu = menu;
  }

  static void exitApplication() {
    exit(0);
  }
}
