import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/eda_client.dart';
import '../models/user_profile.dart';
import '../services/csv_io_service.dart';
import '../services/history_service.dart';
import '../services/notification_service.dart';
import '../services/secure_storage_service.dart';
import '../services/theme_service.dart';
import '../utils/profile_icons.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeService _themeService = ThemeService();
  AppStateData? _appState;
  bool _isLoading = true;
  Set<String> _selectedProfileIds = {};
  bool _isExporting = false;
  bool _isImporting = false;
  // SENTINEL: Re-entrancy guard for the reminder picker (prevents stacking
  // date-picker dialogs when Switch/edit button are tapped rapidly).
  bool _isPickingReminder = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _loadData();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _loadData() async {
    final state = await SecureStorageService().getAppState();
    setState(() {
      _appState = state;
      _selectedProfileIds = state.profiles.map((p) => p.id).toSet();
      _isLoading = false;
    });
  }

  // BOLT: Pre-parse static URI to avoid redundant string parsing on every tap.
  static final Uri _githubIssuesUri = Uri.parse(
    'https://github.com/deciosfernandes/eda-readings-app/issues',
  );

  Future<void> _launchURL() async {
    if (!await launchUrl(
      _githubIssuesUri,
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('about.github_issue'.tr())));
      }
    }
  }

  Future<void> _exportReadings() async {
    if (_selectedProfileIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('import_export.no_selection'.tr())),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final readings = await HistoryService().getHistoryForProfiles(
        _selectedProfileIds.toList(),
      );

      final profileNames = {for (final p in _appState!.profiles) p.id: p.name};

      final csv = CsvIoService.buildCsv(readings, profileNames);

      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(text: csv, subject: 'import_export.share_subject'.tr()),
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/eda_readings_export.csv');
        await file.writeAsString(csv);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'import_export.share_subject'.tr(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('import_export.export_error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importReadings() async {
    setState(() => _isImporting = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final file = result.files.first;

      // SENTINEL: Enforce a 1MB file size limit to prevent client-side DoS or memory issues.
      if (file.size > 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('import_export.file_too_large'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final bytes = file.bytes;
      final path = file.path;

      String content;
      if (bytes != null) {
        content = utf8.decode(bytes);
      } else if (path != null) {
        content = await File(path).readAsString();
      } else {
        throw Exception('Could not read file');
      }

      final importResult = CsvIoService.parseCsvImport(
        content,
        _appState?.profiles ?? <ContractProfile>[],
      );

      await HistoryService().addReadings(importResult.readings);

      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'import_export.import_success'.tr(
                    args: [importResult.importCount.toString()],
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('import_export.import_error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // PALETTE: Opens date + time pickers for a per-profile reminder.
  // Best-effort pre-fills with the API-advised date at 09:00; falls back
  // to tomorrow if the API call fails or returns no date.
  Future<void> _pickReminder(ContractProfile profile) async {
    // SENTINEL: Guard against re-entrant calls (e.g. rapid Switch toggles or
    // multiple edit-button taps stacking date pickers + network calls).
    if (_isPickingReminder) return;
    if (mounted) setState(() => _isPickingReminder = true);
    try {
      await _doPickReminder(profile);
    } finally {
      if (mounted) setState(() => _isPickingReminder = false);
    }
  }

  Future<void> _doPickReminder(ContractProfile profile) async {
    // Try to get the API advised date as the default suggestion.
    DateTime defaultDate = DateTime.now().add(const Duration(days: 1));
    try {
      final client = EDAClient(
        clientNumber: profile.cil,
        contractNumber: profile.contract,
      );
      final readingData = await client.getReading();
      if (readingData.dataAconselhavelEnvio != null) {
        final advised = DateTime.tryParse(readingData.dataAconselhavelEnvio!);
        if (advised != null && advised.isAfter(DateTime.now())) {
          defaultDate = advised;
        }
      }
    } catch (_) {
      // Network optional — use fallback date silently.
    }

    if (!mounted) return;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: defaultDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (pickedTime == null || !mounted) return;

    final chosen = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (chosen.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reminders.past_error'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    try {
      await NotificationService().scheduleReadingReminder(
        id: profile.notificationId,
        profileName: profile.name,
        scheduledDate: chosen,
        title: 'notification.title'.tr(),
        body: 'notification.message'.tr(
          args: [
            profile.name,
            DateFormat.yMMMMd(context.locale.languageCode).add_jm().format(chosen),
          ],
        ),
      );

      profile.reminderEnabled = true;
      profile.reminderDateTime = chosen.toIso8601String();
      // SENTINEL: Guard against _appState being null after the long async chain.
      if (_appState == null || !mounted) return;
      await SecureStorageService().saveAppState(_appState!);

      if (!mounted) return;
      HapticFeedback.lightImpact();
      final displayDate =
          DateFormat.yMMMMd(context.locale.languageCode).add_jm().format(chosen);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('notification.scheduled'.tr(args: [displayDate])),
              ),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('notification.error_schedule'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _removeReminder(ContractProfile profile) async {
    await NotificationService().cancel(profile.notificationId);
    profile.reminderEnabled = false;
    profile.reminderDateTime = null;
    await SecureStorageService().saveAppState(_appState!);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('reminders.removed'.tr())),
    );
    setState(() {});
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'settings.theme_light'.tr();
      case ThemeMode.dark:
        return 'settings.theme_dark'.tr();
      case ThemeMode.system:
        return 'settings.theme_system'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profiles = _appState?.profiles ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Appearance ─────────────────────────────────────────────────────
          _SectionHeader(
            title: 'settings.section_appearance'.tr(),
            colorScheme: colorScheme,
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text('settings.theme_label'.tr()),
            subtitle: Text(_themeModeLabel(_themeService.themeMode)),
            trailing: DropdownButton<ThemeMode>(
              value: _themeService.themeMode,
              underline: const SizedBox(),
              onChanged: (ThemeMode? newMode) {
                if (newMode != null) {
                  HapticFeedback.selectionClick();
                  _themeService.setThemeMode(newMode);
                }
              },
              items: ThemeMode.values.map((mode) {
                IconData icon;
                switch (mode) {
                  case ThemeMode.light:
                    icon = Icons.light_mode_outlined;
                    break;
                  case ThemeMode.dark:
                    icon = Icons.dark_mode_outlined;
                    break;
                  case ThemeMode.system:
                    icon = Icons.settings_brightness_outlined;
                    break;
                }
                return DropdownMenuItem<ThemeMode>(
                  value: mode,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 12),
                      Text(_themeModeLabel(mode)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // ── Data ──────────────────────────────────────────────────────────
          _SectionHeader(
            title: 'settings.section_data'.tr(),
            colorScheme: colorScheme,
          ),
          if (profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'import_export.no_properties'.tr(),
                style: textTheme.bodyLarge,
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'import_export.select_properties'.tr(),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedProfileIds = profiles.map((p) => p.id).toSet();
                      });
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text('common.select_all'.tr()),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedProfileIds.clear();
                      });
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text('common.deselect_all'.tr()),
                  ),
                ],
              ),
            ),
            ...profiles.map((profile) {
              final isSelected = _selectedProfileIds.contains(profile.id);
              return CheckboxListTile(
                value: isSelected,
                onChanged: (checked) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (checked == true) {
                      _selectedProfileIds.add(profile.id);
                    } else {
                      _selectedProfileIds.remove(profile.id);
                    }
                  });
                },
                secondary: Icon(
                  profileIconFromCodePoint(profile.iconCodePoint),
                ),
                title: Text(profile.name),
                subtitle: Text('CIL: ${profile.cil}'),
              );
            }),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_isExporting || _selectedProfileIds.isEmpty)
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _exportReadings();
                            },
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text('import_export.export'.tr()),
                      style: FilledButton.styleFrom(
                        enabledMouseCursor: SystemMouseCursors.click,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isImporting
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _importReadings();
                            },
                      icon: _isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text('import_export.import'.tr()),
                      style: OutlinedButton.styleFrom(
                        enabledMouseCursor: SystemMouseCursors.click,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),

          // ── Reminders ─────────────────────────────────────────────────────
          _SectionHeader(
            title: 'settings.section_reminders'.tr(),
            colorScheme: colorScheme,
          ),
          if (profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'import_export.no_properties'.tr(),
                style: textTheme.bodyLarge,
              ),
            )
          else
            ...profiles.map((profile) {
              final hasReminder =
                  profile.reminderEnabled && profile.reminderDateTime != null;
              String subtitle;
              if (hasReminder) {
                final dt = DateTime.tryParse(profile.reminderDateTime!);
                subtitle = dt != null
                    ? 'reminders.scheduled_for'.tr(
                        args: [
                          DateFormat.yMMMMd(context.locale.languageCode)
                              .add_jm()
                              .format(dt),
                        ],
                      )
                    : 'reminders.none'.tr();
              } else {
                subtitle = 'reminders.none'.tr();
              }
              return ListTile(
                leading: Icon(profileIconFromCodePoint(profile.iconCodePoint)),
                title: Text(profile.name),
                subtitle: Text(subtitle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // PALETTE: Edit button only when a reminder is active.
                    if (hasReminder)
                      Semantics(
                        label: 'reminders.edit'.tr(),
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.edit_calendar_outlined),
                          tooltip: 'reminders.edit'.tr(),
                          // SENTINEL: _pickReminder is guarded by _isPickingReminder;
                          // disable the button while a pick is in progress.
                          onPressed: _isPickingReminder
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  _pickReminder(profile);
                                },
                        ),
                      ),
                    Semantics(
                      label: 'reminders.enable_hint'.tr(),
                      child: Switch(
                        value: hasReminder,
                        // SENTINEL: Disable switch while a picker flow is in progress
                        // to prevent stacked date-picker dialogs.
                        onChanged: _isPickingReminder
                            ? null
                            : (enabled) {
                                HapticFeedback.selectionClick();
                                if (enabled) {
                                  _pickReminder(profile);
                                } else {
                                  _removeReminder(profile);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              );
            }),
          const Divider(height: 1),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader(title: 'about.title'.tr(), colorScheme: colorScheme),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'about.description'.tr(),
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: Text('about.open_source'.tr()),
            subtitle: Text('about.github_issue'.tr()),
            trailing: const Icon(Icons.open_in_new),
            mouseCursor: SystemMouseCursors.click,
            onTap: () async => _launchURL(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Text('© 2026 Décio Fernandes', style: textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  // BOLT: Hoist ColorScheme lookup to avoid redundant InheritedWidget traversals in the list.
  final ColorScheme colorScheme;

  const _SectionHeader({required this.title, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
