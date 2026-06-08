import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';

import '../models/reading_models.dart';
import '../models/user_profile.dart';
import '../utils/csv_helper.dart';

class CsvImportResult {
  const CsvImportResult({required this.readings, required this.importCount});

  final List<LocalReadingHistory> readings;
  final int importCount;
}

class CsvIoService {
  static String buildCsv(
    List<LocalReadingHistory> readings,
    Map<String, String> profileNames,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('import_export.csv_header'.tr());
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final r in readings) {
      final profileName = r.profileId != null
          ? (profileNames[r.profileId] ?? '')
          : '';
      final date = dateFormat.format(r.date);
      buffer.writeln(
        CsvHelper.toCsvRow([
          profileName,
          date,
          r.valorContador1,
          r.valorContador2 ?? '',
          r.valorContador3 ?? '',
        ]),
      );
    }
    return buffer.toString();
  }

  static CsvImportResult parseCsvImport(
    String content,
    List<ContractProfile> profiles,
  ) {
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) throw Exception('Empty file');

    int importCount = 0;
    final newReadings = <LocalReadingHistory>[];

    // BOLT/SENTINEL: Key by id (not by name) for the id lookup later.
    // For name-to-id resolution (CSV stores names), use first-match to be
    // deterministic when two profiles share the same display name — avoids
    // silently attributing all readings to whichever profile happened to come
    // last when the map was built.
    final profileNameToId = <String, String>{};
    for (final p in profiles) {
      profileNameToId.putIfAbsent(p.name, () => p.id);
    }

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final fields = CsvHelper.parseCsvLine(line);
      if (fields.length < 5) continue;

      final rawName = CsvHelper.unescapeField(fields[0]);
      final profileName = rawName.length > 50
          ? rawName.substring(0, 50)
          : rawName;
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

      final n1 = double.tryParse(c1.replaceAll(',', '.'));
      if (n1 == null || !n1.isFinite || n1 < 0) continue;

      if (c2 != null) {
        final n2 = double.tryParse(c2.replaceAll(',', '.'));
        if (n2 == null || !n2.isFinite || n2 < 0) continue;
      }

      if (c3 != null) {
        final n3 = double.tryParse(c3.replaceAll(',', '.'));
        if (n3 == null || !n3.isFinite || n3 < 0) continue;
      }

      DateTime date;
      try {
        date = DateTime.parse(dateStr.replaceFirst(' ', 'T'));
      } catch (_) {
        continue;
      }

      if (c1.isEmpty) continue;

      newReadings.add(
        LocalReadingHistory(
          date: date,
          valorContador1: c1,
          valorContador2: c2,
          valorContador3: c3,
          profileId: profileNameToId[profileName],
        ),
      );
      importCount++;
    }

    return CsvImportResult(readings: newReadings, importCount: importCount);
  }
}
