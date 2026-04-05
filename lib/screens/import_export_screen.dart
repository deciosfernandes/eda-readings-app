import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/reading_models.dart';
import '../models/user_profile.dart';
import '../services/history_service.dart';
import '../services/secure_storage_service.dart';

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

  String _buildCsv(List<LocalReadingHistory> readings, Map<String, String> profileNames) {
    final buffer = StringBuffer();
    buffer.writeln('import_export.csv_header'.tr());
    for (final r in readings) {
      final profileName = r.profileId != null ? (profileNames[r.profileId] ?? '') : '';
      final date = DateFormat('yyyy-MM-dd HH:mm:ss').format(r.date);
      final c1 = r.valorContador1;
      final c2 = r.valorContador2 ?? '';
      final c3 = r.valorContador3 ?? '';
      buffer.writeln('"$profileName","$date","$c1","$c2","$c3"');
    }
    return buffer.toString();
  }

  Future<void> _exportReadings() async {
    if (_selectedProfileIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('import_export.no_selection'.tr())),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final readings = await HistoryService().getHistoryForProfiles(_selectedProfileIds.toList());

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

      final bytes = result.files.first.bytes;
      final path = result.files.first.path;

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
      // Skip header line
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final fields = _parseCsvLine(line);
        if (fields.length < 5) continue;

        final profileName = fields[0];
        final dateStr = fields[1];
        final c1 = fields[2];
        final c2 = fields[3].isEmpty ? null : fields[3];
        final c3 = fields[4].isEmpty ? null : fields[4];

        DateTime date;
        try {
          date = DateTime.parse(dateStr.replaceFirst(' ', 'T'));
        } catch (_) {
          continue;
        }

        if (c1.isEmpty) continue;

        // Find matching profile id by name
        final matchingProfiles = _appState?.profiles.where((p) => p.name == profileName) ?? [];
        final matchingProfile = matchingProfiles.isEmpty ? null : matchingProfiles.first;

        newReadings.add(LocalReadingHistory(
          date: date,
          valorContador1: c1,
          valorContador2: c2,
          valorContador3: c3,
          profileId: matchingProfile?.id,
        ));
        importCount++;
      }

      await HistoryService().addReadings(newReadings);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('import_export.import_success'.tr(args: [importCount.toString()])),
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

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'import_export.select_properties'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
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
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: (_isExporting || _selectedProfileIds.isEmpty) ? null : _exportReadings,
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
