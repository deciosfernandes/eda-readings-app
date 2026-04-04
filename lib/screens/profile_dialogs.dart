import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final scrollController = ScrollController();
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24, left: 24, right: 24
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('drawer.add_profile'.tr(), style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl, 
                    decoration: InputDecoration(
                      labelText: 'drawer.profile_name'.tr(),
                      prefixIcon: const Icon(Icons.label_outline),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cilCtrl, 
                    decoration: InputDecoration(
                      labelText: 'drawer.cil'.tr(),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    )
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contractCtrl, 
                    decoration: InputDecoration(
                      labelText: 'drawer.contract'.tr(),
                      prefixIcon: const Icon(Icons.description_outlined),
                    )
                  ),
                  const SizedBox(height: 24),
                  Text('drawer.select_icon'.tr(), style: Theme.of(context).textTheme.titleMedium),
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
                              onTap: () => setModalState(() => selectedIconCode = icon.codePoint),
                              mouseCursor: SystemMouseCursors.click,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 60,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                    ? Theme.of(context).colorScheme.primaryContainer 
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
                                    : null
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
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty && cilCtrl.text.isNotEmpty && contractCtrl.text.isNotEmpty) {
                      Navigator.pop(context, true);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text('drawer.add'.tr()),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    if (result == true) {
      final name = nameCtrl.text.trim();
      final cil = cilCtrl.text.trim();
      final contract = contractCtrl.text.trim();

      try {
        final client = EDAClient(clientNumber: cil, contractNumber: contract);
        final readingData = await client.getReading();

        appState.profiles.add(ContractProfile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          cil: cil,
          contract: contract,
          iconCodePoint: selectedIconCode,
        ));
        appState.activeProfileIndex = appState.profiles.length - 1;
        await SecureStorageService().saveAppState(appState);
        onSuccess();

        if (readingData.dataAconselhavelEnvio != null && context.mounted) {
          await ReminderDialog.show(context, name, readingData.dataAconselhavelEnvio!);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('login.error_login'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
