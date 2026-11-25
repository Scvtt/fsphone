import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:fsphone/models/phone_models.dart';
import 'package:fsphone/state/phone_controller.dart';
import 'package:fsphone/theme/fs_colors.dart';
import 'package:fsphone/widgets/presence_dot.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.controller});

  final PhoneController controller;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  ContactScope _scope = ContactScope.all;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final contacts = widget.controller.visibleContacts(_scope);
    final selected =
        contacts.where((contact) => contact.id == _selectedId).firstOrNull ??
        (contacts.isEmpty ? null : contacts.first);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 780;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: SegmentedButton<ContactScope>(
                      segments: const [
                        ButtonSegment(
                          value: ContactScope.all,
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: ContactScope.company,
                          label: Text('Company'),
                        ),
                        ButtonSegment(
                          value: ContactScope.personal,
                          label: Text('Personal'),
                        ),
                      ],
                      selected: {_scope},
                      onSelectionChanged: (value) {
                        setState(() => _scope = value.first);
                      },
                    ),
                  ),
                  Expanded(
                    child: contacts.isEmpty
                        ? const Center(
                            child: Text(
                              'No contacts match that search.',
                              style: TextStyle(color: FsColors.muted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: contacts.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final contact = contacts[index];
                              final active = selected?.id == contact.id;
                              return ListTile(
                                selected: active,
                                selectedTileColor: const Color(0xFFEAF2FF),
                                leading: AvatarBadge(
                                  initials: contact.initials,
                                  status: contact.presence,
                                  radius: 18,
                                  background: const Color(0xFFE7EEF8),
                                  foreground: FsColors.ink,
                                ),
                                title: Text(contact.name),
                                subtitle: Text(
                                  '${contact.department} · ${contact.extension}',
                                ),
                                trailing: Text(
                                  contact.presence.label,
                                  style: const TextStyle(
                                    color: FsColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  setState(() => _selectedId = contact.id);
                                  if (!wide) {
                                    _showDetail(context, contact);
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            if (wide && selected != null) ...[
              const VerticalDivider(width: 1),
              SizedBox(width: 340, child: _detail(selected, expand: true)),
            ],
          ],
        );
      },
    );
  }

  void _showDetail(BuildContext context, DirectoryContact contact) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(width: 380, child: _detail(contact, expand: false)),
      ),
    );
  }

  Widget _detail(DirectoryContact contact, {required bool expand}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: AvatarBadge(
              initials: contact.initials,
              status: contact.presence,
              radius: 36,
              background: const Color(0xFFE7EEF8),
              foreground: FsColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              contact.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              contact.presence.label,
              style: const TextStyle(color: FsColors.muted),
            ),
          ),
          const SizedBox(height: 18),
          _fact('Extension', contact.extension),
          _fact('Department', contact.department),
          _fact('Email', contact.email),
          _fact('Directory', contact.company ? 'Company' : 'Personal'),
          if (expand) const Spacer() else const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => widget.controller.placeCall(
                    contact.extension,
                    media: CallMedia.voice,
                    name: contact.name,
                  ),
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                  style: FilledButton.styleFrom(backgroundColor: FsColors.call),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Video call',
                onPressed: () => widget.controller.placeCall(
                  contact.extension,
                  media: CallMedia.video,
                  name: contact.name,
                ),
                icon: const Icon(Icons.videocam),
              ),
              IconButton(
                tooltip: 'Copy number',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: contact.extension));
                },
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: FsColors.muted)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
