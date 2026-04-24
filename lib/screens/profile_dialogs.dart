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
    int selectedIconCode = Icons.home.codePoint;

    // Validation error state (null = no error)
    String? nameError;
    String? cilError;
    String? contractError;
    String? apiError;
    bool isLoading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final scrollController = ScrollController();

          String? validateField(String value) {
            return value.trim().isEmpty ? 'login.error_empty'.tr() : null;
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

              if (context.mounted) Navigator.pop(context);
              onSuccess();

              if (readingData.dataAconselhavelEnvio != null &&
                  context.mounted) {
                await ReminderDialog.show(
                  context,
                  name,
                  readingData.dataAconselhavelEnvio!,
                );
              }
            } catch (e) {
              setModalState(() {
                isLoading = false;
                apiError = 'login.error_login'.tr();
              });
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
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
                      Text(
                        'drawer.add_profile'.tr(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'common.cancel'.tr(),
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pop(context),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    apiError!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                  onPressed: () =>
                                      setModalState(() => apiError = null),
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
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'drawer.profile_name'.tr(),
                        hintText: 'login.profile_name_hint'.tr(),
                        prefixIcon: const Icon(Icons.label_outline),
                        errorText: nameError,
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
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'drawer.cil'.tr(),
                        prefixIcon: const Icon(Icons.badge_outlined),
                        errorText: cilError,
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
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => handleAdd(),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'drawer.contract'.tr(),
                        prefixIcon: const Icon(Icons.description_outlined),
                        errorText: contractError,
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
                  Text(
                    'drawer.select_icon'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
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
                            child: InkWell(
                              onTap: isLoading
                                  ? null
                                  : () => setModalState(
                                      () => selectedIconCode = icon.codePoint,
                                    ),
                              mouseCursor: SystemMouseCursors.click,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 60,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).dividerColor,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icon,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
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
                    label: Text('drawer.add'.tr()),
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
  }
}
