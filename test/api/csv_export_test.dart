import 'package:flutter_test/flutter_test.dart';
import 'package:eda_app/utils/csv_helper.dart';

void main() {
  group('CsvHelper', () {
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
      expect(CsvHelper.escapeField('\tTab'), "'\tTab");
      expect(CsvHelper.escapeField('\rCR'), "'\rCR");
      expect(CsvHelper.escapeField('\nLF'), "'\nLF");
      expect(CsvHelper.escapeField("'Quote"), "''Quote");
    });

    test('escapeField should protect against Formula Injection with leading whitespace', () {
      expect(CsvHelper.escapeField(' =SUM(A1:B2)'), "' =SUM(A1:B2)");
      expect(CsvHelper.escapeField('  +123'), "'  +123");
      expect(CsvHelper.escapeField('\t-50'), "'\t-50");
      expect(CsvHelper.escapeField(' \n@hint'), "' \n@hint");
    });

    test('escapeField should handle combined quotes and formula injection', () {
      expect(CsvHelper.escapeField('="Quote"'), "'=\"\"Quote\"\"");
    });

    test('parseCsvLine should handle escaped quotes correctly', () {
      final line = '"Profile with ""quotes""","2024-01-01","123","",""';
      final fields = CsvHelper.parseCsvLine(line);

      expect(fields[0], 'Profile with "quotes"');
      expect(fields[1], '2024-01-01');
      expect(fields[2], '123');
    });

    test('CSV row generation and parsing roundtrip', () {
      final profileName = 'House "Main"';
      final csvLine = CsvHelper.toCsvRow([profileName, 'date', '100', '', '']);

      final parsed = CsvHelper.parseCsvLine(csvLine);
      expect(parsed[0], profileName);
    });

    test('Formula injection roundtrip and unescaping', () {
      final malicious = '=1+1';
      final csvLine = CsvHelper.toCsvRow([malicious]);

      final parsed = CsvHelper.parseCsvLine(csvLine);
      expect(parsed[0], "'$malicious");
      expect(CsvHelper.unescapeField(parsed[0]), malicious);
    });

    test('Legacy unescaping support (Tab)', () {
      expect(CsvHelper.unescapeField('\t=1+1'), '=1+1');
    });
  });
}
