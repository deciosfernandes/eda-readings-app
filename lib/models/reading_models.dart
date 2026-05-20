/// Represents the response from the EDA API containing meter reading details.
///
/// This model encapsulates all metadata and current counter values for a specific
/// delivery point (CIL), including the security token required for submissions.
class ReadingResponse {
  /// Local Identification Code (Código de Identificação Local).
  /// A unique 10-digit number identifying the delivery point.
  final String cil;

  /// Security token associated with this CIL for submission.
  final String cilToken;

  /// Expiration timestamp for the [cilToken].
  final int cilTokenExpires;

  /// Meter serial number.
  final String serial;

  /// Meter material/type code.
  final String material;

  /// Electricity contract number associated with the [cil].
  final String contrato;

  /// Date of the most recent reading recorded in the EDA system.
  final String? data;

  /// Recommended date for sending the next reading ("data aconselhável de envio").
  /// The application uses this to schedule local reminders via the `NotificationService`.
  final String? dataAconselhavelEnvio;

  /// Origin of the last recorded reading (e.g., "Web", "App", "Estimativa").
  final String? origem;

  /// The active electricity tariff (e.g., "Simples", "Bi-horária", "Tri-horária").
  final String? tarifa;

  /// Description for Counter 1 (e.g., "Ponta", "Cheias", or "Simples").
  final String? descContador1;
  /// Current/Last value for Counter 1 in kWh as recorded in the system.
  final String? valorContador1;
  /// Minimum allowed value for the next Counter 1 reading to prevent submission errors.
  final String? valorMinContador1;
  /// Maximum allowed value for the next Counter 1 reading to prevent submission errors.
  final String? valorMaxContador1;
  /// Internal register code for Counter 1, required for the [SendReadingPayload].
  final String? register1;

  /// Description for Counter 2 (e.g., "Vazio" / Off-peak).
  final String? descContador2;
  /// Current/Last value for Counter 2 in kWh.
  final String? valorContador2;
  /// Minimum allowed value for the next Counter 2 reading.
  final String? valorMinContador2;
  /// Maximum allowed value for the next Counter 2 reading.
  final String? valorMaxContador2;
  /// Internal register code for Counter 2.
  final String? register2;

  /// Description for Counter 3 (e.g., "Super Vazio").
  final String? descContador3;
  /// Current/Last value for Counter 3 in kWh.
  final String? valorContador3;
  /// Minimum allowed value for the next Counter 3 reading.
  final String? valorMinContador3;
  /// Maximum allowed value for the next Counter 3 reading.
  final String? valorMaxContador3;
  /// Internal register code for Counter 3.
  final String? register3;

  // BOLT: Memoized numeric values to avoid redundant parsing in UI loops.
  final double? val1;
  final double? minVal1;
  final double? maxVal1;
  final double? val2;
  final double? minVal2;
  final double? maxVal2;
  final double? val3;
  final double? minVal3;
  final double? maxVal3;

  ReadingResponse({
    required this.cil,
    required this.cilToken,
    required this.cilTokenExpires,
    required this.serial,
    required this.material,
    required this.contrato,
    this.data,
    this.dataAconselhavelEnvio,
    this.origem,
    this.tarifa,
    this.descContador1,
    this.valorContador1,
    this.valorMinContador1,
    this.valorMaxContador1,
    this.register1,
    this.descContador2,
    this.valorContador2,
    this.valorMinContador2,
    this.valorMaxContador2,
    this.register2,
    this.descContador3,
    this.valorContador3,
    this.valorMinContador3,
    this.valorMaxContador3,
    this.register3,
    this.val1,
    this.minVal1,
    this.maxVal1,
    this.val2,
    this.minVal2,
    this.maxVal2,
    this.val3,
    this.minVal3,
    this.maxVal3,
  });

  factory ReadingResponse.fromJson(Map<String, dynamic> json) {
    final v1 = json['valorContador1'] as String?;
    final vMin1 = json['valorMinContador1'] as String?;
    final vMax1 = json['valorMaxContador1'] as String?;
    final v2 = json['valorContador2'] as String?;
    final vMin2 = json['valorMinContador2'] as String?;
    final vMax2 = json['valorMaxContador2'] as String?;
    final v3 = json['valorContador3'] as String?;
    final vMin3 = json['valorMinContador3'] as String?;
    final vMax3 = json['valorMaxContador3'] as String?;

    return ReadingResponse(
      cil: json['cil'] ?? '',
      cilToken: json['cilToken'] ?? '',
      cilTokenExpires: json['cilTokenExpires'] ?? 0,
      serial: json['serial'] ?? '',
      material: json['material'] ?? '',
      contrato: json['contrato'] ?? '',
      data: json['data'],
      dataAconselhavelEnvio: json['dataAconselhavelEnvio'],
      origem: json['origem'],
      tarifa: json['tarifa'],
      descContador1: json['descContador1'],
      valorContador1: v1,
      valorMinContador1: vMin1,
      valorMaxContador1: vMax1,
      register1: json['register1'],
      descContador2: json['descContador2'],
      valorContador2: v2,
      valorMinContador2: vMin2,
      valorMaxContador2: vMax2,
      register2: json['register2'],
      descContador3: json['descContador3'],
      valorContador3: v3,
      valorMinContador3: vMin3,
      valorMaxContador3: vMax3,
      register3: json['register3'],
      val1: _parseLocaleDouble(v1),
      minVal1: _parseLocaleDouble(vMin1),
      maxVal1: _parseLocaleDouble(vMax1),
      val2: _parseLocaleDouble(v2),
      minVal2: _parseLocaleDouble(vMin2),
      maxVal2: _parseLocaleDouble(vMax2),
      val3: _parseLocaleDouble(v3),
      minVal3: _parseLocaleDouble(vMin3),
      maxVal3: _parseLocaleDouble(vMax3),
    );
  }
}

/// Data payload for submitting a new reading to the EDA API.
class SendReadingPayload {
  /// Local Identification Code (CIL).
  final String cil;
  /// Security token obtained from [ReadingResponse].
  final String cilToken;
  /// Expiration timestamp for the [cilToken].
  final int cilTokenExpires;
  /// Meter serial number.
  final String serial;
  /// Meter material code.
  final String material;
  /// New value for Counter 1 in kWh.
  final String valorContador1;
  /// Internal register code for Counter 1.
  final String register1;
  /// Optional new value for Counter 2 in kWh.
  final String? valorContador2;
  /// Optional internal register code for Counter 2.
  final String? register2;
  /// Optional new value for Counter 3 in kWh.
  final String? valorContador3;
  /// Optional internal register code for Counter 3.
  final String? register3;

  SendReadingPayload({
    required this.cil,
    required this.cilToken,
    required this.cilTokenExpires,
    required this.serial,
    required this.material,
    required this.valorContador1,
    required this.register1,
    this.valorContador2,
    this.register2,
    this.valorContador3,
    this.register3,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'cil': cil,
      'cilToken': cilToken,
      'cilTokenExpires': cilTokenExpires,
      'serial': serial,
      'material': material,
      'valorContador1': valorContador1,
      'register1': register1,
    };
    if (valorContador2 != null && register2 != null) {
      data['valorContador2'] = valorContador2;
      data['register2'] = register2;
    }
    if (valorContador3 != null && register3 != null) {
      data['valorContador3'] = valorContador3;
      data['register3'] = register3;
    }
    return data;
  }
}

/// Represents a meter reading stored locally in the application's history.
///
/// **BOLT**: These objects are cached in-memory by the `HistoryService` and
/// indexed by `profileId` to allow O(1) lookups during dashboard rendering.
class LocalReadingHistory {
  /// Date and time when the reading was recorded locally.
  final DateTime date;
  /// Value for Counter 1 in kWh.
  final String valorContador1;
  /// Optional value for Counter 2 in kWh.
  final String? valorContador2;
  /// Optional value for Counter 3 in kWh.
  final String? valorContador3;
  /// ID of the [ContractProfile] this reading belongs to.
  final String? profileId;

  // BOLT: Memoized numeric values to avoid redundant parsing in UI loops.
  final double val1;
  final double? val2;
  final double? val3;

  LocalReadingHistory({
    required this.date,
    required this.valorContador1,
    this.valorContador2,
    this.valorContador3,
    this.profileId,
    this.val1 = 0.0,
    this.val2,
    this.val3,
  });

  factory LocalReadingHistory.fromJson(Map<String, dynamic> json) {
    final v1 = json['valorContador1'] as String? ?? '0';
    final v2 = json['valorContador2'] as String?;
    final v3 = json['valorContador3'] as String?;

    return LocalReadingHistory(
      date: DateTime.parse(json['date'] as String),
      valorContador1: v1,
      valorContador2: v2,
      valorContador3: v3,
      profileId: json['profileId'] as String?,
      val1: _parseLocaleDouble(v1) ?? 0.0,
      val2: _parseLocaleDouble(v2),
      val3: _parseLocaleDouble(v3),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'valorContador1': valorContador1,
      'valorContador2': valorContador2,
      'valorContador3': valorContador3,
      'profileId': profileId,
    };
  }
}

/// BOLT: Helper to parse numeric strings that may use European (comma) decimal separators.
double? _parseLocaleDouble(String? value) {
  if (value == null || value.isEmpty) return null;
  return double.tryParse(value.replaceAll(',', '.'));
}
