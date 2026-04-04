import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eda_app/models/reading_models.dart';
import 'package:eda_app/services/history_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  LocalReadingHistory makeReading({
    String valor1 = '100.00',
    String? profileId,
    DateTime? date,
  }) =>
      LocalReadingHistory(
        date: date ?? DateTime(2024, 1, 1),
        valorContador1: valor1,
        profileId: profileId,
      );

  group('HistoryService.addReading', () {
    test('adds a reading to an empty history', () async {
      final service = HistoryService();
      final reading = makeReading(valor1: '123.45', profileId: 'p1');

      await service.addReading(reading);
      final history = await service.getHistory();

      expect(history.length, 1);
      expect(history.first.valorContador1, '123.45');
    });

    test('prepends new reading so it appears first', () async {
      final service = HistoryService();
      final first = makeReading(valor1: '100.00', date: DateTime(2024, 1, 1));
      final second = makeReading(valor1: '200.00', date: DateTime(2024, 1, 2));

      await service.addReading(first);
      await service.addReading(second);
      final history = await service.getHistory();

      expect(history.length, 2);
      expect(history.first.valorContador1, '200.00');
      expect(history.last.valorContador1, '100.00');
    });

    test('persists reading across service instances', () async {
      await HistoryService().addReading(makeReading(valor1: '999.00'));

      final history = await HistoryService().getHistory();
      expect(history.length, 1);
      expect(history.first.valorContador1, '999.00');
    });
  });

  group('HistoryService.getHistory', () {
    test('returns empty list when no readings exist', () async {
      final history = await HistoryService().getHistory();
      expect(history, isEmpty);
    });

    test('returns all readings when profileId is null', () async {
      final service = HistoryService();
      await service.addReading(makeReading(profileId: 'p1'));
      await service.addReading(makeReading(profileId: 'p2'));

      final history = await service.getHistory();

      expect(history.length, 2);
    });

    test('filters readings by profileId', () async {
      final service = HistoryService();
      await service.addReading(makeReading(valor1: '100', profileId: 'p1'));
      await service.addReading(makeReading(valor1: '200', profileId: 'p2'));
      await service.addReading(makeReading(valor1: '300', profileId: 'p1'));

      final history = await service.getHistory(profileId: 'p1');

      expect(history.length, 2);
      expect(history.every((r) => r.profileId == 'p1'), isTrue);
    });

    test('returns empty list when no readings match profileId', () async {
      final service = HistoryService();
      await service.addReading(makeReading(profileId: 'p1'));

      final history = await service.getHistory(profileId: 'unknown');

      expect(history, isEmpty);
    });

    test('returns readings with null profileId when filtering returns no match', () async {
      final service = HistoryService();
      await service.addReading(makeReading(profileId: null));

      final history = await service.getHistory(profileId: 'p1');

      expect(history, isEmpty);
    });
  });

  group('HistoryService.addReadings', () {
    test('does nothing when list is empty', () async {
      final service = HistoryService();
      await service.addReadings([]);

      final history = await service.getHistory();
      expect(history, isEmpty);
    });

    test('adds multiple readings in order', () async {
      final service = HistoryService();
      final readings = [
        makeReading(valor1: 'A', date: DateTime(2024, 1, 1)),
        makeReading(valor1: 'B', date: DateTime(2024, 1, 2)),
        makeReading(valor1: 'C', date: DateTime(2024, 1, 3)),
      ];

      await service.addReadings(readings);
      final history = await service.getHistory();

      expect(history.length, 3);
      expect(history[0].valorContador1, 'A');
      expect(history[1].valorContador1, 'B');
      expect(history[2].valorContador1, 'C');
    });

    test('prepends all batch readings before existing ones', () async {
      final service = HistoryService();
      await service.addReading(makeReading(valor1: 'existing'));

      await service.addReadings([
        makeReading(valor1: 'new1'),
        makeReading(valor1: 'new2'),
      ]);

      final history = await service.getHistory();

      expect(history.length, 3);
      expect(history[0].valorContador1, 'new1');
      expect(history[1].valorContador1, 'new2');
      expect(history[2].valorContador1, 'existing');
    });
  });

  group('HistoryService.getHistoryForProfiles', () {
    test('returns all readings when profileIds list is empty', () async {
      final service = HistoryService();
      await service.addReading(makeReading(profileId: 'p1'));
      await service.addReading(makeReading(profileId: 'p2'));

      final history = await service.getHistoryForProfiles([]);

      expect(history.length, 2);
    });

    test('filters readings to specified profile IDs', () async {
      final service = HistoryService();
      await service.addReading(makeReading(valor1: 'A', profileId: 'p1'));
      await service.addReading(makeReading(valor1: 'B', profileId: 'p2'));
      await service.addReading(makeReading(valor1: 'C', profileId: 'p3'));

      final history = await service.getHistoryForProfiles(['p1', 'p3']);

      expect(history.length, 2);
      expect(history.every((r) => r.profileId == 'p1' || r.profileId == 'p3'), isTrue);
    });

    test('excludes readings with null profileId', () async {
      final service = HistoryService();
      await service.addReading(makeReading(valor1: 'A', profileId: null));
      await service.addReading(makeReading(valor1: 'B', profileId: 'p1'));

      final history = await service.getHistoryForProfiles(['p1']);

      expect(history.length, 1);
      expect(history.first.valorContador1, 'B');
    });

    test('returns empty list when no readings match specified profiles', () async {
      final service = HistoryService();
      await service.addReading(makeReading(profileId: 'p1'));

      final history = await service.getHistoryForProfiles(['unknown']);

      expect(history, isEmpty);
    });
  });
}
