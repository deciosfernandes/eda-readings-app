import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reading_models.dart';

/// Categories of errors that the EDA API client can produce.
///
/// Callers can inspect [EDAException.kind] to present context-aware error
/// messages (e.g. show "wrong credentials" for [auth] vs. "no internet" for
/// [network]).
enum EDAErrorKind {
  /// 401 / 403 — credentials rejected or not authorised.
  auth,
  /// 404 — resource not found.
  notFound,
  /// 5xx — upstream server error.
  server,
  /// Request timed out.
  timeout,
  /// Network unreachable / connection refused.
  network,
  /// Response body could not be parsed.
  parse,
}

/// Typed exception thrown by [EDAClient] instead of a generic [Exception].
///
/// Callers can `catch (e)` generically or narrow to `on EDAException` to
/// inspect [kind] and [statusCode] for user-facing messages.
class EDAException implements Exception {
  final EDAErrorKind kind;
  final int? statusCode;
  final String message;

  const EDAException(this.kind, this.message, {this.statusCode});

  @override
  String toString() => 'EDAException($kind, status=$statusCode): $message';
}

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

  // BOLT: Move RegExp to a static final instance to avoid repeated allocation in the constructor.
  static final RegExp _digitsRegex = RegExp(r'^\d+$');

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
    if (clientNumber.length != 10 || !_digitsRegex.hasMatch(clientNumber)) {
      throw ArgumentError(
        'Invalid CIL format. Must be a 10-digit numeric string.',
      );
    }
    // Sentinel: Validate Contract format (up to 20-digit numeric) as a defense-in-depth measure.
    if (contractNumber.isEmpty ||
        contractNumber.length > 20 ||
        !_digitsRegex.hasMatch(contractNumber)) {
      throw ArgumentError(
        'Invalid Contract format. Must be a numeric string up to 20 digits.',
      );
    }
  }

  /// Fetches the current meter status and reading metadata for the configured CIL/Contract.
  ///
  /// This must be called before [sendReading] to obtain a fresh [ReadingResponse.cilToken].
  ///
  /// Throws an [EDAException] describing the failure category.
  Future<ReadingResponse> getReading() async {
    // Sentinel: Use replace(queryParameters: ...) for safer URI construction.
    final uri = _baseUri.replace(
      queryParameters: {'cil': clientNumber, 'contrato': contractNumber},
    );

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const EDAException(EDAErrorKind.timeout, 'Request timed out');
    } catch (e) {
      // Covers SocketException, ClientException, and any other transport error.
      throw EDAException(EDAErrorKind.network, 'Network error: $e');
    }

    // Accept any 2xx status (consistent with sendReading behaviour).
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final dynamic data = json.decode(response.body);
        return ReadingResponse.fromJson(data as Map<String, dynamic>);
      } on FormatException catch (e) {
        throw EDAException(
          EDAErrorKind.parse,
          'Failed to parse EDA response as JSON: ${e.message}',
        );
      } catch (e) {
        throw EDAException(EDAErrorKind.parse, 'Failed to decode response: $e');
      }
    } else {
      throw EDAException(
        _kindFromStatus(response.statusCode),
        'Failed to get reading: ${response.statusCode} ${response.reasonPhrase}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Submits a new meter reading to the EDA API.
  ///
  /// Requires a valid [payload] constructed with a token from [getReading].
  ///
  /// Throws an [EDAException] describing the failure category. On API
  /// validation errors (e.g. value out of range) the response body is included
  /// in [EDAException.message] so it can be surfaced to the user.
  Future<void> sendReading(SendReadingPayload payload) async {
    // Sentinel: Use replace(queryParameters: ...) for safer URI construction.
    final uri = _baseUri.replace(queryParameters: {'cil': clientNumber});

    final http.Response response;
    try {
      response = await _client
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload.toJson()),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const EDAException(EDAErrorKind.timeout, 'Request timed out');
    } catch (e) {
      throw EDAException(EDAErrorKind.network, 'Network error: $e');
    }

    if (response.statusCode != 200 && response.statusCode != 204) {
      // SENTINEL: Include the response body in the exception so upstream
      // validation messages (e.g. "value out of allowed range") reach the user.
      final body = response.body.isNotEmpty ? response.body : '(no body)';
      throw EDAException(
        _kindFromStatus(response.statusCode),
        'Failed to send reading: ${response.statusCode} - $body',
        statusCode: response.statusCode,
      );
    }
  }

  static EDAErrorKind _kindFromStatus(int status) {
    if (status == 401 || status == 403) return EDAErrorKind.auth;
    if (status == 404) return EDAErrorKind.notFound;
    return EDAErrorKind.server;
  }
}
