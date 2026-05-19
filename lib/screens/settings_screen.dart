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

import '../models/reading_models.dart';
import '../models/user_profile.dart';
import '../services/history_service.dart';
import '../services/secure_storage_service.dart';
import '../services/theme_service.dart';
import '../utils/csv_helper.dart';

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
    if (!await launchUrl(_githubIssuesUri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('about.github_issue'.tr())),
        );
      }
    }
  }

  String _buildCsv(
    List<LocalReadingHistory> readings,
    Map<String, String> profileNames,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('import_export.csv_header'.tr());
    // BOLT: Instantiate DateFormat once outside the loop to avoid redundant allocations.
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final r in readings) {
      final profileName = r.profileId != null ? (profileNames[r.profileId] ?? '') : '';
      final date = dateFormat.format(r.date);
      buffer.writeln(CsvHelper.toCsvRow([
        profileName,
        date,
        r.valorContador1,
        r.valorContador2 ?? '',
        r.valorContador3 ?? '',
      ]));
    }
    return buffer.toString();
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
      final readings = await HistoryService()
          .getHistoryForProfiles(_selectedProfileIds.toList());

      final profileNames = {
        for (final p in _appState!.profiles) p.id: p.name,
      };

      final csv = _buildCsv(readings, profileNames);

      if (kIsWeb) {
        await Share.share(
          csv,
          subject: 'import_export.share_subject'.tr(),
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/eda_readings_export.csv');
        await file.writeAsString(csv);
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'import_export.share_subject'.tr(),
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
        setState(() => _isImporting = false);
        return;
      }

      final file = result.files.first;

      // SENTINEL: Enforce a 1MB file size limit to prevent client-side DoS or memory issues.
      if (file.size > 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('File too large. Maximum size is 1MB.'),
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

      final lines = const LineSplitter().convert(content);
      if (lines.isEmpty) throw Exception('Empty file');

      int importCount = 0;
      final newReadings = <LocalReadingHistory>[];

      // BOLT: Create a lookup map to avoid O(N) list scans inside the loop.
      // This achieves O(1) profile lookup by name during import.
      final profileNameToId = {
        for (final p in _appState?.profiles ?? <ContractProfile>[]) p.name: p.id
      };

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final fields = CsvHelper.parseCsvLine(line);
        if (fields.length < 5) continue;

        // Sentinel: Security hardening for CSV import.
        // Enforce length limits and validate numeric formats to prevent malformed data injection.
        final rawName = CsvHelper.unescapeField(fields[0]);
        final profileName = rawName.length > 50 ? rawName.substring(0, 50) : rawName;
        final rawDate = CsvHelper.unescapeField(fields[1]);
        final dateStr = rawDate.length > 30 ? rawDate.substring(0, 30) : rawDate;
        final rawC1 = CsvHelper.unescapeField(fields[2]);
        final c1 = rawC1.length > 15 ? rawC1.substring(0, 15) : rawC1;
        final rawC2 = CsvHelper.unescapeField(fields[3]);
        final c2Raw = rawC2.length > 15 ? rawC2.substring(0, 15) : rawC2;
        final c2 = c2Raw.isEmpty ? null : c2Raw;
        final rawC3 = CsvHelper.unescapeField(fields[4]);
        final c3Raw = rawC3.length > 15 ? rawC3.substring(0, 15) : rawC3;
        final c3 = c3Raw.isEmpty ? null : c3Raw;

        // Sentinel: Validate that readings are finite non-negative numbers if present.
        // BOLT: Use centralized parseValue utility for consistency.
        final n1 = LocalReadingHistory.parseValue(c1);
        if (n1 == null || !n1.isFinite || n1 < 0) continue;

        if (c2 != null) {
          final n2 = LocalReadingHistory.parseValue(c2);
          if (n2 == null || !n2.isFinite || n2 < 0) continue;
        }

        if (c3 != null) {
          final n3 = LocalReadingHistory.parseValue(c3);
          if (n3 == null || !n3.isFinite || n3 < 0) continue;
        }

        DateTime date;
        try {
          date = DateTime.parse(dateStr.replaceFirst(' ', 'T'));
        } catch (_) {
          continue;
        }

        if (c1.isEmpty) continue;

        // BOLT: Use O(1) map lookup instead of O(N) where() filter.
        final matchingProfileId = profileNameToId[profileName];

        newReadings.add(
          LocalReadingHistory(
            date: date,
            valorContador1: c1,
            valorContador2: c2,
            valorContador3: c3,
            profileId: matchingProfileId,
          ),
        );
        importCount++;
      }

      await HistoryService().addReadings(newReadings);

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
                  'import_export.import_success'
                      .tr(args: [importCount.toString()]),
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
      appBar: AppBar(
        title: Text('settings.title'.tr())
      ),
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
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: Text('common.select_all'.tr()),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedProfileIds.clear();
                      });
                    },
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
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
                  IconData(profile.iconCodePoint, fontFamily: 'MaterialIcons'),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
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

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader(
            title: 'about.title'.tr(),
            colorScheme: colorScheme,
          ),
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
            child: Text(
              '© 2026 Décio Fernandes',
              style: textTheme.bodySmall,
            ),
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
