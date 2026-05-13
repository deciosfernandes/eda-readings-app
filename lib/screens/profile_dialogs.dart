import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/eda_client.dart';
import '../models/user_profile.dart';
import '../services/secure_storage_service.dart';
import 'reminder_dialog.dart';

class ProfileDialogs {
  static final List<IconData> _availableIcons = [
    Icons.home,
    Icons.apartment,
    Icons.villa,
    Icons.cottage,
    Icons.business,
    Icons.store,
    Icons.factory,
    Icons.flash_on,
  ];

  static Future<void> showAddProfileDialog({
    required BuildContext context,
    required AppStateData appState,
    required VoidCallback onSuccess,
  }) async {
    final nameCtrl = TextEditingController();
    final cilCtrl = TextEditingController();
    final contractCtrl = TextEditingController();
    final scrollController = ScrollController();
    int selectedIconCode = Icons.home.codePoint;

    // Validation error state (null = no error)
    String? nameError;
    String? cilError;
    String? contractError;
    String? apiError;
    bool isLoading = false;

    // BOLT: Pre-calculate all labels, hints, and error strings outside the builder
    // to avoid redundant tr() lookups on every keystroke (rebuild).
    final sErrorEmpty = 'login.error_empty'.tr();
    final sAddSuccess = 'drawer.add_success'.tr();
    final sErrorLogin = 'login.error_login'.tr();
    final sTitle = 'drawer.add_profile'.tr();
    final sCancel = 'common.cancel'.tr();
    final sClose = 'common.close'.tr();
    final sProfileName = 'drawer.profile_name'.tr();
    final sProfileNameHint = 'login.profile_name_hint'.tr();
    final sClear = 'common.clear'.tr();
    final sCil = 'drawer.cil'.tr();
    final sContract = 'drawer.contract'.tr();
    final sSelectIcon = 'drawer.select_icon'.tr();
    final sIconOption = 'drawer.icon_option'.tr();
    final sAdd = 'drawer.add'.tr();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            // BOLT: Hoist Theme and ColorScheme lookups to avoid redundant InheritedWidget traversals.
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final textTheme = theme.textTheme;

            String? validateField(String value) {
              return value.trim().isEmpty ? sErrorEmpty : null;
            }

          bool isValid() =>
              nameError == null &&
              cilError == null &&
              contractError == null &&
              nameCtrl.text.trim().isNotEmpty &&
              cilCtrl.text.trim().isNotEmpty &&
              contractCtrl.text.trim().isNotEmpty;

          Future<void> handleAdd() async {
            // Force-validate all fields on submit
            setModalState(() {
              nameError = validateField(nameCtrl.text);
              cilError = validateField(cilCtrl.text);
              contractError = validateField(contractCtrl.text);
            });

            if (!isValid()) return;

            setModalState(() => isLoading = true);

            final name = nameCtrl.text.trim();
            final cil = cilCtrl.text.trim();
            final contract = contractCtrl.text.trim();

            try {
              final client = EDAClient(
                clientNumber: cil,
                contractNumber: contract,
              );
              final readingData = await client.getReading();

              appState.profiles.add(
                ContractProfile(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  cil: cil,
                  contract: contract,
                  iconCodePoint: selectedIconCode,
                ),
              );
              appState.activeProfileIndex = appState.profiles.length - 1;
              await SecureStorageService().saveAppState(appState);

              HapticFeedback.lightImpact();

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(child: Text(sAddSuccess)),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              onSuccess();

              if (readingData.dataAconselhavelEnvio != null &&
                  context.mounted) {
                final newProfile = appState.profiles.last;
                final stableId = int.parse(newProfile.id) % 0x7FFFFFFF;
                await ReminderDialog.show(
                  context,
                  name,
                  readingData.dataAconselhavelEnvio!,
                  notificationId: stableId,
                );
              }
            } catch (e) {
              setModalState(() {
                isLoading = false;
                apiError = sErrorLogin;
              });
            }
          }

            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            sTitle,
                            style: textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            semanticLabel: sCancel,
                          ),
                          tooltip: sCancel,
                          isSelected: false,
                          onPressed: isLoading
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(context);
                                },
                        ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: apiError == null
                        ? const SizedBox.shrink()
                        : Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: colorScheme.onErrorContainer,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    apiError!,
                                    style: TextStyle(
                                      color: colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: colorScheme.onErrorContainer,
                                    semanticLabel: sClose,
                                  ),
                                  tooltip: sClose,
                                  isSelected: false,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setModalState(() => apiError = null);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) {
                        setModalState(() {
                          nameError = validateField(nameCtrl.text);
                        });
                      }
                    },
                    child: TextField(
                      controller: nameCtrl,
                      enabled: !isLoading,
                      maxLength: 50,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '$sProfileName *',
                        hintText: sProfileNameHint,
                        prefixIcon: const Icon(Icons.label_outline),
                        errorText: nameError,
                        suffixIcon: nameCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  semanticLabel: sClear,
                                ),
                                tooltip: sClear,
                                isSelected: false,
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  nameCtrl.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) {
                        setModalState(() {
                          if (nameError != null) {
                            nameError = validateField(nameCtrl.text);
                          }
                          apiError = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) {
                        setModalState(() {
                          cilError = validateField(cilCtrl.text);
                        });
                      }
                    },
                    child: TextField(
                      controller: cilCtrl,
                      enabled: !isLoading,
                      maxLength: 20,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: '$sCil *',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        errorText: cilError,
                        suffixIcon: cilCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  semanticLabel: sClear,
                                ),
                                tooltip: sClear,
                                isSelected: false,
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  cilCtrl.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) {
                        setModalState(() {
                          if (cilError != null) {
                            cilError = validateField(cilCtrl.text);
                          }
                          apiError = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Focus(
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) {
                        setModalState(() {
                          contractError = validateField(contractCtrl.text);
                        });
                      }
                    },
                    child: TextField(
                      controller: contractCtrl,
                      enabled: !isLoading,
                      maxLength: 20,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => handleAdd(),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: '$sContract *',
                        prefixIcon: const Icon(Icons.description_outlined),
                        errorText: contractError,
                        suffixIcon: contractCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  semanticLabel: sClear,
                                ),
                                tooltip: sClear,
                                isSelected: false,
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  contractCtrl.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) {
                        setModalState(() {
                          if (contractError != null) {
                            contractError = validateField(contractCtrl.text);
                          }
                          apiError = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      sSelectIcon,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    child: SizedBox(
                      height: 80,
                      child: ListView.builder(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _availableIcons.length,
                        itemBuilder: (context, index) {
                          final icon = _availableIcons[index];
                          final isSelected = selectedIconCode == icon.codePoint;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Semantics(
                              label: sIconOption,
                              selected: isSelected,
                              button: true,
                              child: InkWell(
                                onTap: isLoading
                                    ? null
                                    : () {
                                        HapticFeedback.selectionClick();
                                        setModalState(
                                          () => selectedIconCode = icon.codePoint,
                                        );
                                      },
                                mouseCursor: SystemMouseCursors.click,
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primaryContainer
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : theme.dividerColor,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        icon,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : null,
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: isLoading ? null : handleAdd,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add),
                    label: Text(sAdd),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledMouseCursor: SystemMouseCursors.click,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    } finally {
      // BOLT: Ensure all controllers are disposed to prevent memory leaks.
      nameCtrl.dispose();
      cilCtrl.dispose();
      contractCtrl.dispose();
      scrollController.dispose();
    }
  }
}
