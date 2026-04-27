import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import '../services/secure_storage_service.dart';
import 'profile_dialogs.dart';

class ProfileDrawer extends StatefulWidget {
  final AppStateData appState;
  final VoidCallback onProfileChanged;

  const ProfileDrawer({
    super.key,
    required this.appState,
    required this.onProfileChanged,
  });

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      widget.appState.userProfile.picturePath = image.path;
      await SecureStorageService().saveAppState(widget.appState);
      widget.onProfileChanged(); // trigger rebuild
    }
  }

  Future<void> _editUserName() async {
    final controller =
        TextEditingController(text: widget.appState.userProfile.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('drawer.edit_user_name'.tr()),
            content: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (value) => setDialogState(() {}),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
              decoration: InputDecoration(
                labelText: 'drawer.name_label'.tr(),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          setDialogState(() {});
                        },
                      )
                    : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                onPressed: controller.text.isEmpty
                    ? null
                    : () => Navigator.pop(context, controller.text),
                child: Text('common.save'.tr()),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty) {
      HapticFeedback.lightImpact();
      widget.appState.userProfile.name = result;
      await SecureStorageService().saveAppState(widget.appState);
      widget.onProfileChanged(); // trigger rebuild
    }
  }

  Future<void> _addProfile() async {
    await ProfileDialogs.showAddProfileDialog(
      context: context,
      appState: widget.appState,
      onSuccess: widget.onProfileChanged,
    );
  }

  Future<void> _removeProfile(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('drawer.remove_profile_title'.tr()),
        content: Text('drawer.remove_profile_content'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('common.cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('drawer.remove'.tr())),
        ],
      ),
    );

    if (confirm == true) {
      widget.appState.profiles.removeAt(index);
      if (widget.appState.profiles.isEmpty) {
        widget.appState.activeProfileIndex = 0;
      }
      await SecureStorageService().saveAppState(widget.appState);
      widget.onProfileChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Tooltip(
                      message: 'drawer.change_picture'.tr(),
                      child: Semantics(
                        label: 'drawer.change_picture'.tr(),
                        button: true,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white24,
                          backgroundImage: widget.appState.userProfile.picturePath.isNotEmpty
                              ? (kIsWeb
                                  ? NetworkImage(widget.appState.userProfile.picturePath)
                                  : FileImage(File(widget.appState.userProfile.picturePath)) as ImageProvider)
                              : null,
                          child: widget.appState.userProfile.picturePath.isEmpty
                              ? Icon(Icons.person, size: 40, color: Theme.of(context).colorScheme.onSecondary)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.appState.userProfile.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      tooltip: 'drawer.edit_name_tooltip'.tr(),
                      icon: Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.onSecondary.withValues(alpha: 0.7)),
                      onPressed: _editUserName,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(left: 8),
                    )
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.appState.profiles.length + 1, // +1 for "Add" button
              itemBuilder: (context, index) {
                if (index == widget.appState.profiles.length) {
                  return ListTile(
                    leading: const Icon(Icons.add),
                    title: Text('drawer.add_profile'.tr()),
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context); // Close drawer
                      _addProfile();
                    },
                  );
                }

                final profile = widget.appState.profiles[index];
                final isActive = index == widget.appState.activeProfileIndex;

                return ListTile(
                  leading: Icon(IconData(profile.iconCodePoint, fontFamily: 'MaterialIcons')),
                  title: Text(profile.name),
                  subtitle: Text('CIL: ${profile.cil}'),
                  selected: isActive,
                  mouseCursor: SystemMouseCursors.click,
                  trailing: IconButton(
                    tooltip: 'drawer.remove_profile_tooltip'.tr(),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      _removeProfile(index);
                    },
                  ),
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    widget.appState.activeProfileIndex = index;
                    await SecureStorageService().saveAppState(widget.appState);
                    widget.onProfileChanged();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('settings.title'.tr()),
            mouseCursor: SystemMouseCursors.click,
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
