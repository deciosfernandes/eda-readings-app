import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reading_models.dart';

class EDAClient {
  // BOLT: Pre-parse base URL into a static Uri to avoid redundant string parsing on every request.
  static final Uri _baseUri = Uri.parse(
    kIsWeb
        ? 'http://localhost:8080/api/leitura'
        : 'https://smile.eda.pt/api/leitura',
  );

  // Sentinel: Enforce request timeouts to prevent resource exhaustion and hanging.
  static const Duration _timeout = Duration(seconds: 15);

  final String clientNumber; // CIL
  final String contractNumber;
  final http.Client _client;

  // BOLT: Shared client to enable connection pooling and reduce SSL handshake overhead.
  static final http.Client _sharedClient = http.Client();

  EDAClient({
    required this.clientNumber,
    required this.contractNumber,
    http.Client? client,
  }) : _client = client ?? _sharedClient;

  Future<ReadingResponse> getReading() async {
    // Sentinel: Use replace(queryParameters: ...) for safer URI construction.
    final uri = _baseUri.replace(queryParameters: {
      'cil': clientNumber,
      'contrato': contractNumber,
    });

    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ReadingResponse.fromJson(data);
    } else {
      throw Exception(
        'Failed to get reading: ${response.statusCode} ${response.reasonPhrase}',
      );
    }
  }

  Future<void> sendReading(SendReadingPayload payload) async {
    // Sentinel: Use replace(queryParameters: ...) for safer URI construction.
    final uri = _baseUri.replace(queryParameters: {
      'cil': clientNumber,
    });

    final response = await _client
        .put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload.toJson()),
        )
        .timeout(_timeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'Failed to send reading: ${response.statusCode} ${response.reasonPhrase}',
      );
    }
  }
}
