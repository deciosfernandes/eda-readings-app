import 'package:flutter_test/flutter_test.dart';
import 'package:eda_app/models/reading_models.dart';

void main() {
  group('LocalReadingHistory.parseValue', () {
    test('returns null for null input', () {
      expect(LocalReadingHistory.parseValue(null), isNull);
    });

    test('returns null for empty string', () {
      expect(LocalReadingHistory.parseValue(''), isNull);
    });

    test('parses standard decimal strings', () {
      expect(LocalReadingHistory.parseValue('123.45'), 123.45);
      expect(LocalReadingHistory.parseValue('0'), 0.0);
    });

    test('parses European comma-based decimal strings', () {
      expect(LocalReadingHistory.parseValue('123,45'), 123.45);
      expect(LocalReadingHistory.parseValue('1.234,56'), isNull); // We don't support thousand separators yet, but it should be consistent
      expect(LocalReadingHistory.parseValue('0,1'), 0.1);
    });

    test('returns null for non-numeric strings', () {
      expect(LocalReadingHistory.parseValue('abc'), isNull);
      expect(LocalReadingHistory.parseValue('12.34.56'), isNull);
    });
  });

  group('Model Memoization', () {
    test('LocalReadingHistory memoizes values on instantiation', () {
      final reading = LocalReadingHistory(
        date: DateTime.now(),
        valorContador1: '100,5',
        valorContador2: '200.75',
        valorContador3: '',
      );

      expect(reading.val1, 100.5);
      expect(reading.val2, 200.75);
      expect(reading.val3, isNull);
    });

    test('ReadingResponse memoizes values on instantiation', () {
      final response = ReadingResponse(
        cil: '1234567890',
        cilToken: 'token',
        cilTokenExpires: 0,
        serial: 'S123',
        material: 'M1',
        contrato: 'C1',
        valorContador1: '10,1',
        valorMinContador1: '5',
        valorMaxContador1: '15,5',
      );

      expect(response.val1, 10.1);
      expect(response.minVal1, 5.0);
      expect(response.maxVal1, 15.5);
      expect(response.val2, isNull);
    });
  });
}
