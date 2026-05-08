import 'package:flutter_test/flutter_test.dart';
import 'package:eda_app/utils/csv_helper.dart';

List<String> parseCsvLine(String line) {
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

void main() {
  group('CsvHelper.escapeField', () {
    test('escapeField should double-quote double-quotes', () {
      expect(CsvHelper.escapeField('Normal'), 'Normal');
      expect(CsvHelper.escapeField('With "quotes"'), 'With ""quotes""');
      expect(CsvHelper.escapeField('"Leading and trailing"'), '""Leading and trailing""');
    });

    test('escapeField should protect against Formula Injection', () {
      expect(CsvHelper.escapeField('=SUM(A1:B2)'), "'=SUM(A1:B2)");
      expect(CsvHelper.escapeField('+123'), "'+123");
      expect(CsvHelper.escapeField('-50'), "'-50");
      expect(CsvHelper.escapeField('@hint'), "'@hint");
    });

    test('escapeField should handle combined quotes and formula injection', () {
      expect(CsvHelper.escapeField('="Quote"'), "'=\"\"Quote\"\"");
    });

    test('parseCsvLine should handle escaped quotes correctly', () {
      final line = '"Profile with ""quotes""","2024-01-01","123","",""';
      final fields = parseCsvLine(line);

      expect(fields[0], 'Profile with "quotes"');
      expect(fields[1], '2024-01-01');
      expect(fields[2], '123');
    });

    test('CSV row generation and parsing roundtrip', () {
      final profileName = 'House "Main"';
      final escaped = CsvHelper.escapeField(profileName);
      final csvLine = '"$escaped","date","100","",""';

      final parsed = parseCsvLine(csvLine);
      expect(parsed[0], profileName);
    });

    test('Formula injection roundtrip', () {
      final malicious = '=1+1';
      final escaped = CsvHelper.escapeField(malicious);
      final csvLine = '"$escaped"';

      final parsed = parseCsvLine(csvLine);
      expect(parsed[0], "'$malicious");
    });
  });
}
