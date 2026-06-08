import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/user_profile.dart';
import '../services/csv_io_service.dart';
import '../services/history_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/profile_icons.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  AppStateData? _appState;
  bool _isLoading = true;
  Set<String> _selectedProfileIds = {};
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadAppState();
  }

  Future<void> _loadAppState() async {
    final state = await SecureStorageService().getAppState();
    setState(() {
      _appState = state;
      _selectedProfileIds = state.profiles.map((p) => p.id).toSet();
      _isLoading = false;
    });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('import_export.title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final profiles = _appState?.profiles ?? [];

    return Scaffold(
      appBar: AppBar(title: Text('import_export.title'.tr())),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'import_export.select_properties'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (profiles.isNotEmpty) ...[
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
              ],
            ),
          ),
          if (profiles.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'import_export.no_properties'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else ...[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
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
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: (_isExporting || _selectedProfileIds.isEmpty)
                        ? null
                        : _exportReadings,
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
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isImporting ? null : _importReadings,
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
