import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reading_models.dart';

/// Client for interacting with the EDA (Electricidade dos Açores) API.
///
/// It handles retrieving the current meter state and submitting new readings.
class EDAClient {
  // BOLT: Pre-parse base URL into a static Uri to avoid redundant string parsing on every request.
  static final Uri _baseUri = Uri.parse(
    kIsWeb
        ? 'http://localhost:8080/api/leitura'
        : 'https://smile.eda.pt/api/leitura',
  );

  // Sentinel: Enforce request timeouts to prevent resource exhaustion and hanging.
  static const Duration _timeout = Duration(seconds: 15);

  /// Local Identification Code (CIL) for the property.
  final String clientNumber;

  /// Electricity contract number.
  final String contractNumber;

  final http.Client _client;

  // BOLT: Shared client to enable connection pooling and reduce SSL handshake overhead.
  static final http.Client _sharedClient = http.Client();

  /// Creates a new [EDAClient] instance.
  ///
  /// [clientNumber] (CIL) and [contractNumber] are required for most API operations.
  EDAClient({
    required this.clientNumber,
    required this.contractNumber,
    http.Client? client,
  }) : _client = client ?? _sharedClient {
    // Sentinel: Validate CIL format (10-digit numeric) as a defense-in-depth measure.
    if (clientNumber.length != 10 || !RegExp(r'^\d+$').hasMatch(clientNumber)) {
      throw ArgumentError('Invalid CIL format. Must be a 10-digit numeric string.');
    }
  }

  /// Fetches the current meter status and reading metadata for the configured CIL/Contract.
  ///
  /// This must be called before [sendReading] to obtain a fresh [ReadingResponse.cilToken].
  ///
  /// Throws an [Exception] if the request fails or returns a non-200 status code.
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

  /// Submits a new meter reading to the EDA API.
  ///
  /// Requires a valid [payload] constructed with a token from [getReading].
  ///
  /// Throws an [Exception] if the submission fails.
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
