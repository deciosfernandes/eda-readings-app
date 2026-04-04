import 'package:flutter_test/flutter_test.dart';
import 'package:eda_app/models/reading_models.dart';

void main() {
  group('ReadingResponse', () {
    test('fromJson maps all required fields', () {
      final json = {
        'cil': 'PT123',
        'cilToken': 'token_abc',
        'cilTokenExpires': 1700000000,
        'serial': 'SN001',
        'material': 'MAT01',
        'contrato': 'C001',
      };

      final response = ReadingResponse.fromJson(json);

      expect(response.cil, 'PT123');
      expect(response.cilToken, 'token_abc');
      expect(response.cilTokenExpires, 1700000000);
      expect(response.serial, 'SN001');
      expect(response.material, 'MAT01');
      expect(response.contrato, 'C001');
    });

    test('fromJson maps all optional fields', () {
      final json = {
        'cil': 'PT123',
        'cilToken': 'token_abc',
        'cilTokenExpires': 0,
        'serial': 'SN001',
        'material': 'MAT01',
        'contrato': 'C001',
        'data': '2024-01-15',
        'dataAconselhavelEnvio': '2024-01-20',
        'origem': 'SMART',
        'tarifa': 'BTN',
        'descContador1': 'Consumo',
        'valorContador1': '1234.56',
        'valorMinContador1': '1200.00',
        'valorMaxContador1': '1300.00',
        'register1': 'REG01',
        'descContador2': 'Vazio',
        'valorContador2': '500.00',
        'valorMinContador2': '480.00',
        'valorMaxContador2': '520.00',
        'register2': 'REG02',
        'descContador3': 'Super Vazio',
        'valorContador3': '200.00',
        'valorMinContador3': '190.00',
        'valorMaxContador3': '210.00',
        'register3': 'REG03',
      };

      final response = ReadingResponse.fromJson(json);

      expect(response.data, '2024-01-15');
      expect(response.dataAconselhavelEnvio, '2024-01-20');
      expect(response.origem, 'SMART');
      expect(response.tarifa, 'BTN');
      expect(response.descContador1, 'Consumo');
      expect(response.valorContador1, '1234.56');
      expect(response.valorMinContador1, '1200.00');
      expect(response.valorMaxContador1, '1300.00');
      expect(response.register1, 'REG01');
      expect(response.descContador2, 'Vazio');
      expect(response.valorContador2, '500.00');
      expect(response.valorMinContador2, '480.00');
      expect(response.valorMaxContador2, '520.00');
      expect(response.register2, 'REG02');
      expect(response.descContador3, 'Super Vazio');
      expect(response.valorContador3, '200.00');
      expect(response.valorMinContador3, '190.00');
      expect(response.valorMaxContador3, '210.00');
      expect(response.register3, 'REG03');
    });

    test('fromJson uses empty strings for missing required fields', () {
      final json = <String, dynamic>{};

      final response = ReadingResponse.fromJson(json);

      expect(response.cil, '');
      expect(response.cilToken, '');
      expect(response.cilTokenExpires, 0);
      expect(response.serial, '');
      expect(response.material, '');
      expect(response.contrato, '');
    });

    test('fromJson sets optional fields to null when absent', () {
      final json = {
        'cil': 'PT123',
        'cilToken': 'tok',
        'cilTokenExpires': 0,
        'serial': 'SN',
        'material': 'MAT',
        'contrato': 'C',
      };

      final response = ReadingResponse.fromJson(json);

      expect(response.data, isNull);
      expect(response.valorContador1, isNull);
      expect(response.valorContador2, isNull);
      expect(response.valorContador3, isNull);
    });
  });

  group('SendReadingPayload', () {
    test('toJson includes all required fields', () {
      final payload = SendReadingPayload(
        cil: 'PT123',
        cilToken: 'token_abc',
        cilTokenExpires: 1700000000,
        serial: 'SN001',
        material: 'MAT01',
        valorContador1: '1234.56',
        register1: 'REG01',
      );

      final json = payload.toJson();

      expect(json['cil'], 'PT123');
      expect(json['cilToken'], 'token_abc');
      expect(json['cilTokenExpires'], 1700000000);
      expect(json['serial'], 'SN001');
      expect(json['material'], 'MAT01');
      expect(json['valorContador1'], '1234.56');
      expect(json['register1'], 'REG01');
    });

    test('toJson omits optional counter fields when null', () {
      final payload = SendReadingPayload(
        cil: 'PT123',
        cilToken: 'tok',
        cilTokenExpires: 0,
        serial: 'SN',
        material: 'MAT',
        valorContador1: '100',
        register1: 'R1',
      );

      final json = payload.toJson();

      expect(json.containsKey('valorContador2'), isFalse);
      expect(json.containsKey('register2'), isFalse);
      expect(json.containsKey('valorContador3'), isFalse);
      expect(json.containsKey('register3'), isFalse);
    });

    test('toJson includes counter2 and counter3 when provided', () {
      final payload = SendReadingPayload(
        cil: 'PT123',
        cilToken: 'tok',
        cilTokenExpires: 0,
        serial: 'SN',
        material: 'MAT',
        valorContador1: '100',
        register1: 'R1',
        valorContador2: '200',
        register2: 'R2',
        valorContador3: '300',
        register3: 'R3',
      );

      final json = payload.toJson();

      expect(json['valorContador2'], '200');
      expect(json['register2'], 'R2');
      expect(json['valorContador3'], '300');
      expect(json['register3'], 'R3');
    });

    test('toJson omits counter fields when value is null even if register is set', () {
      final payload = SendReadingPayload(
        cil: 'PT',
        cilToken: 'tok',
        cilTokenExpires: 0,
        serial: 'SN',
        material: 'MAT',
        valorContador1: '100',
        register1: 'R1',
        valorContador2: null,
        register2: 'R2',
      );

      final json = payload.toJson();

      expect(json.containsKey('valorContador2'), isFalse);
      expect(json.containsKey('register2'), isFalse);
    });
  });

  group('LocalReadingHistory', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'date': '2024-03-15T10:30:00.000Z',
        'valorContador1': '1234.56',
        'valorContador2': '500.00',
        'valorContador3': '200.00',
        'profileId': 'profile_001',
      };

      final history = LocalReadingHistory.fromJson(json);

      expect(history.date, DateTime.parse('2024-03-15T10:30:00.000Z'));
      expect(history.valorContador1, '1234.56');
      expect(history.valorContador2, '500.00');
      expect(history.valorContador3, '200.00');
      expect(history.profileId, 'profile_001');
    });

    test('fromJson sets optional fields to null when absent', () {
      final json = {
        'date': '2024-03-15T10:30:00.000Z',
        'valorContador1': '1234.56',
        'valorContador2': null,
        'valorContador3': null,
        'profileId': null,
      };

      final history = LocalReadingHistory.fromJson(json);

      expect(history.valorContador2, isNull);
      expect(history.valorContador3, isNull);
      expect(history.profileId, isNull);
    });

    test('toJson serialises all fields including nulls', () {
      final date = DateTime(2024, 3, 15, 10, 30);
      final history = LocalReadingHistory(
        date: date,
        valorContador1: '1234.56',
        valorContador2: '500.00',
        valorContador3: '200.00',
        profileId: 'profile_001',
      );

      final json = history.toJson();

      expect(json['date'], date.toIso8601String());
      expect(json['valorContador1'], '1234.56');
      expect(json['valorContador2'], '500.00');
      expect(json['valorContador3'], '200.00');
      expect(json['profileId'], 'profile_001');
    });

    test('toJson round-trip preserves all values', () {
      final date = DateTime(2024, 6, 1, 9, 0);
      final original = LocalReadingHistory(
        date: date,
        valorContador1: '999.99',
        profileId: 'p1',
      );

      final restored = LocalReadingHistory.fromJson(original.toJson());

      expect(restored.date, original.date);
      expect(restored.valorContador1, original.valorContador1);
      expect(restored.valorContador2, isNull);
      expect(restored.valorContador3, isNull);
      expect(restored.profileId, original.profileId);
    });
  });
}
