import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/profile_icons.dart';
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
    HapticFeedback.selectionClick();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      widget.appState.userProfile.picturePath = image.path;
      await SecureStorageService().saveAppState(widget.appState);
      if (mounted) widget.onProfileChanged();
    }
  }

  Future<void> _editUserName() async {
    final controller = TextEditingController(
      text: widget.appState.userProfile.name,
    );
    // BOLT: Ensure the controller is disposed in all exit paths (including when
    // the dialog is cancelled or the widget is disposed mid-await).
    String? result;
    try {
      result = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('drawer.edit_user_name'.tr()),
              content: TextField(
                controller: controller,
                maxLength: 50,
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
                          tooltip: 'common.clear'.tr(),
                          onPressed: () {
                            HapticFeedback.selectionClick();
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
    } finally {
      // BOLT: Dispose the controller regardless of whether the dialog was
      // confirmed, cancelled, or the widget was disposed during the await.
      controller.dispose();
    }

    if (result != null && result.isNotEmpty && mounted) {
      HapticFeedback.lightImpact();
      widget.appState.userProfile.name = result;
      await SecureStorageService().saveAppState(widget.appState);
      if (mounted) widget.onProfileChanged();
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context, true);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('drawer.remove'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final profile = widget.appState.profiles[index];
      // BOLT: Use the centralised notificationId getter (avoids duplicating
      // the `int.parse(id) % 0x7FFFFFFF` derivation).
      await NotificationService().cancel(profile.notificationId);
      widget.appState.profiles.removeAt(index);
      if (widget.appState.profiles.isEmpty) {
        widget.appState.activeProfileIndex = 0;
      } else if (index <= widget.appState.activeProfileIndex) {
        widget.appState.activeProfileIndex =
            (widget.appState.activeProfileIndex - 1).clamp(
              0,
              widget.appState.profiles.length - 1,
            );
      }
      await SecureStorageService().saveAppState(widget.appState);
      if (mounted) widget.onProfileChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // PALETTE: Container replaces DrawerHeader for full edge-to-edge gradient control
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 160.0),
            padding: EdgeInsets.fromLTRB(
              16.0,
              MediaQuery.of(context).padding.top + 16.0,
              16.0,
              16.0,
            ),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    message: 'drawer.change_picture'.tr(),
                    child: InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(40),
                      child: Semantics(
                        label: 'drawer.change_picture'.tr(),
                        button: true,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white24,
                              backgroundImage:
                                  widget
                                      .appState
                                      .userProfile
                                      .picturePath
                                      .isNotEmpty
                                  ? (kIsWeb
                                        ? NetworkImage(
                                            widget
                                                .appState
                                                .userProfile
                                                .picturePath,
                                          )
                                        : FileImage(
                                                File(
                                                  widget
                                                      .appState
                                                      .userProfile
                                                      .picturePath,
                                                ),
                                              )
                                              as ImageProvider)
                                  : null,
                              child:
                                  widget
                                      .appState
                                      .userProfile
                                      .picturePath
                                      .isEmpty
                                  ? Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSecondary,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _editUserName,
                  borderRadius: BorderRadius.circular(8),
                  child: Tooltip(
                    message: 'drawer.edit_name_tooltip'.tr(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(width: 8),
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondary.withValues(alpha: 0.7),
                            semanticLabel: 'drawer.edit_name_tooltip'.tr(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount:
                  widget.appState.profiles.length + 1, // +1 for "Add" button
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

                return Semantics(
                  label:
                      '${profile.name}, CIL: ${profile.cil}${isActive ? ' (${'common.ok'.tr()})' : ''}',
                  selected: isActive,
                  button: true,
                  child: ListTile(
                    leading: Icon(
                      profileIconFromCodePoint(profile.iconCodePoint),
                    ),
                    title: Text(profile.name),
                    subtitle: Text('CIL: ${profile.cil}'),
                    selected: isActive,
                    mouseCursor: SystemMouseCursors.click,
                    trailing: IconButton(
                      tooltip: 'drawer.remove_profile_tooltip'.tr(),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                        _removeProfile(index);
                      },
                    ),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      widget.appState.activeProfileIndex = index;
                      await SecureStorageService().saveAppState(
                        widget.appState,
                      );
                      widget.onProfileChanged();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                  ),
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
              HapticFeedback.selectionClick();
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
