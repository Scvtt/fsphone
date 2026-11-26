import 'package:material_ui/material_ui.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/screens/active_call_screen.dart';
import 'package:fsphone/screens/contacts_screen.dart';
import 'package:fsphone/screens/dialer_screen.dart';
import 'package:fsphone/screens/recents_screen.dart';
import 'package:fsphone/screens/settings_screen.dart';
import 'package:fsphone/screens/voicemail_screen.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';
import 'package:fsphone/widgets/nav_rail.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.controller});

  final PhoneController controller;

  @override
  Widget build(BuildContext context) {
    final onCall = controller.call != null;
    final showDialer = controller.section == ShellSection.dialer;
    return Scaffold(
      backgroundColor: FsColors.canvas,
      body: Row(
        children: [
          PhoneNavRail(controller: controller),
          Expanded(
            child: Column(
              children: [
                _TopBar(controller: controller),
                if (controller.incoming != null)
                  _IncomingBanner(controller: controller),
                if (onCall && !showDialer)
                  _ReturnToCall(controller: controller),
                Expanded(child: _body()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (controller.call != null && controller.section == ShellSection.dialer) {
      return ActiveCallScreen(controller: controller);
    }
    return switch (controller.section) {
      ShellSection.dialer => DialerScreen(controller: controller),
      ShellSection.contacts => ContactsScreen(controller: controller),
      ShellSection.recents => RecentsScreen(controller: controller),
      ShellSection.voicemail => VoicemailScreen(controller: controller),
      ShellSection.settings => SettingsScreen(controller: controller),
    };
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final PhoneController controller;

  String get _title {
    return switch (controller.section) {
      ShellSection.dialer => controller.call == null ? 'Keypad' : 'Call',
      ShellSection.contacts => 'Contacts',
      ShellSection.recents => 'Recents',
      ShellSection.voicemail => 'Voicemail',
      ShellSection.settings => 'Settings',
    };
  }

  bool get _searchable {
    return controller.section == ShellSection.contacts ||
        controller.section == ShellSection.recents ||
        controller.section == ShellSection.voicemail;
  }

  @override
  Widget build(BuildContext context) {
    final registered = controller.registered;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: FsColors.line)),
      ),
      child: Row(
        children: [
          Text(
            _title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 20),
          if (_searchable)
            SizedBox(
              width: 320,
              child: TextField(
                key: const Key('shell-search'),
                decoration: const InputDecoration(
                  hintText: 'Search',
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: controller.setSearch,
              ),
            ),
          const Spacer(),
          Tooltip(
            message:
                controller.statusMessage ??
                (registered
                    ? 'Registered with the PBX'
                    : 'Not registered with the PBX'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: registered
                    ? const Color(0xFFE7F6EE)
                    : const Color(0xFFFFF6E8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: registered ? FsColors.available : FsColors.away,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    registered ? 'Registered · WSS' : 'Not registered',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingBanner extends StatelessWidget {
  const _IncomingBanner({required this.controller});

  final PhoneController controller;

  @override
  Widget build(BuildContext context) {
    final ringing = controller.incoming;
    if (ringing == null) {
      return const SizedBox.shrink();
    }
    return Material(
      color: const Color(0xFFE7F0FF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.ring_volume, color: FsColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Incoming call · ${ringing.name} · ${ringing.number}',
              ),
            ),
            FilledButton(
              onPressed: controller.answerIncoming,
              child: const Text('Answer'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: controller.declineIncoming,
              child: const Text('Decline'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnToCall extends StatelessWidget {
  const _ReturnToCall({required this.controller});

  final PhoneController controller;

  @override
  Widget build(BuildContext context) {
    final call = controller.call!;
    final label = call.consulting
        ? 'Consulting ${call.consultName}'
        : call.name;
    return Material(
      color: const Color(0xFFE7F6EE),
      child: InkWell(
        onTap: () => controller.open(ShellSection.dialer),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.call, color: FsColors.call, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label · ${formatDuration(call.elapsed(DateTime.now()))}',
                ),
              ),
              const Text(
                'Return to call',
                style: TextStyle(
                  color: FsColors.call,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
