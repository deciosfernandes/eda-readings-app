import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reading_models.dart';

class EDAClient {
  // Use local proxy on Web due to CORS. Otherwise use the real API directly.
  static const String baseUrl = kIsWeb 
      ? 'http://localhost:8080/api/leitura' 
      : 'https://smile.eda.pt/api/leitura';
  final String clientNumber; // CIL
  final String contractNumber;
  final http.Client _client;

  EDAClient({required this.clientNumber, required this.contractNumber, http.Client? client})
      : _client = client ?? http.Client();

  Future<ReadingResponse> getReading() async {
    final uri = Uri.parse('$baseUrl?cil=${Uri.encodeComponent(clientNumber)}&contrato=${Uri.encodeComponent(contractNumber)}');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ReadingResponse.fromJson(data);
    } else {
      throw Exception('Failed to get reading: ${response.statusCode} ${response.reasonPhrase}');
    }
  }

  Future<void> sendReading(SendReadingPayload payload) async {
    final uri = Uri.parse('$baseUrl?cil=${Uri.encodeComponent(clientNumber)}');
    final response = await _client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to send reading: ${response.statusCode} ${response.reasonPhrase}');
    }
  }
}
