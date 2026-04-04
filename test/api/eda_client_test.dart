import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:eda_app/api/eda_client.dart';
import 'package:eda_app/models/reading_models.dart';

void main() {
  const testCil = 'PT001';
  const testContract = 'C001';

  final validReadingJson = {
    'cil': testCil,
    'cilToken': 'tok123',
    'cilTokenExpires': 1700000000,
    'serial': 'SN001',
    'material': 'MAT01',
    'contrato': testContract,
    'data': '2024-03-15',
    'valorContador1': '1234.56',
    'register1': 'R1',
  };

  group('EDAClient.getReading', () {
    test('returns ReadingResponse on HTTP 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(validReadingJson), 200);
      });

      final client = EDAClient(
        clientNumber: testCil,
        contractNumber: testContract,
        client: mockClient,
      );

      final result = await client.getReading();

      expect(result, isA<ReadingResponse>());
      expect(result.cil, testCil);
      expect(result.cilToken, 'tok123');
      expect(result.serial, 'SN001');
    });

    test('throws Exception on non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final client = EDAClient(
        clientNumber: testCil,
        contractNumber: testContract,
        client: mockClient,
      );

      expect(() => client.getReading(), throwsException);
    });

    test('sends GET request to correct URL with encoded CIL and contract', () async {
      Uri? capturedUri;
      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(validReadingJson), 200);
      });

      final client = EDAClient(
        clientNumber: 'PT 001',
        contractNumber: 'C 001',
        client: mockClient,
      );

      await client.getReading();

      expect(capturedUri, isNotNull);
      expect(capturedUri!.queryParameters['cil'], 'PT 001');
      expect(capturedUri!.queryParameters['contrato'], 'C 001');
    });

    test('throws Exception on HTTP 500', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = EDAClient(
        clientNumber: testCil,
        contractNumber: testContract,
        client: mockClient,
      );

      expect(() => client.getReading(), throwsException);
    });
  });

  group('EDAClient.sendReading', () {
    SendReadingPayload makePayload() => SendReadingPayload(
          cil: testCil,
          cilToken: 'tok123',
          cilTokenExpires: 1700000000,
          serial: 'SN001',
          material: 'MAT01',
          valorContador1: '1234.56',
          register1: 'R1',
        );

    test('succeeds without throwing on HTTP 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      final client = EDAClient(
        clientNumber: testCil,
        contractNumber: testContract,
        client: mockClient,
      );

      await expectLater(client.sendReading(makePayload()), completes);
    });

    test('succeeds without throwing on HTTP 204', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 204);
      });

      final client = EDAClient(
        clientNumber: testCil,
        contractNumber: testContract,
        client: mockClient,
      );

      await expectLater(client.sendReading(makePayload()), completes);
    });

    test('throws Exception on HTTP 400', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Bad Request', 400);
      });

      final client = EDAClient(
        clientNumber: testCil,
        contractNumber: testContract,
        client: mockClient,
      );

      expect(() => client.sendReading(makePayload()), throwsException);
    });

    test('sends PUT request with JSON body containing payload fields', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request as http.Request;
        return http.Response('', 204);
      });

      final payload = SendReadingPayload(
        cil: testCil,
        cilToken: 'tokXYZ',
        cilTokenExpires: 12345,
        serial: 'SN999',
        material: 'MAT99',
        valorContador1: '999.00',
        register1: 'REG1',
      );

      final client = EDAClient(
        clientNumber: testCil,
        contractNumber: testContract,
        client: mockClient,
      );

      await client.sendReading(payload);

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'PUT');

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['cil'], testCil);
      expect(body['cilToken'], 'tokXYZ');
      expect(body['valorContador1'], '999.00');
    });

    test('sends PUT request to URL with encoded CIL', () async {
      Uri? capturedUri;
      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('', 204);
      });

      final client = EDAClient(
        clientNumber: 'PT 001',
        contractNumber: testContract,
        client: mockClient,
      );

      await client.sendReading(makePayload());

      expect(capturedUri, isNotNull);
      expect(capturedUri!.queryParameters['cil'], 'PT 001');
    });
  });
}
