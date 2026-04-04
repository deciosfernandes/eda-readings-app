class ReadingResponse {
  final String cil;
  final String cilToken;
  final int cilTokenExpires;
  final String serial;
  final String material;
  final String contrato;
  final String? data;
  final String? dataAconselhavelEnvio;
  final String? origem;
  final String? tarifa;
  
  final String? descContador1;
  final String? valorContador1;
  final String? valorMinContador1;
  final String? valorMaxContador1;
  final String? register1;
  
  final String? descContador2;
  final String? valorContador2;
  final String? valorMinContador2;
  final String? valorMaxContador2;
  final String? register2;
  
  final String? descContador3;
  final String? valorContador3;
  final String? valorMinContador3;
  final String? valorMaxContador3;
  final String? register3;

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
  });

  factory ReadingResponse.fromJson(Map<String, dynamic> json) {
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
      valorContador1: json['valorContador1'],
      valorMinContador1: json['valorMinContador1'],
      valorMaxContador1: json['valorMaxContador1'],
      register1: json['register1'],
      descContador2: json['descContador2'],
      valorContador2: json['valorContador2'],
      valorMinContador2: json['valorMinContador2'],
      valorMaxContador2: json['valorMaxContador2'],
      register2: json['register2'],
      descContador3: json['descContador3'],
      valorContador3: json['valorContador3'],
      valorMinContador3: json['valorMinContador3'],
      valorMaxContador3: json['valorMaxContador3'],
      register3: json['register3'],
    );
  }
}

class SendReadingPayload {
  final String cil;
  final String cilToken;
  final int cilTokenExpires;
  final String serial;
  final String material;
  final String valorContador1;
  final String register1;
  final String? valorContador2;
  final String? register2;
  final String? valorContador3;
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

class LocalReadingHistory {
  final DateTime date;
  final String valorContador1;
  final String? valorContador2;
  final String? valorContador3;
  final String? profileId;

  LocalReadingHistory({
    required this.date,
    required this.valorContador1,
    this.valorContador2,
    this.valorContador3,
    this.profileId,
  });

  factory LocalReadingHistory.fromJson(Map<String, dynamic> json) {
    return LocalReadingHistory(
      date: DateTime.parse(json['date']),
      valorContador1: json['valorContador1'],
      valorContador2: json['valorContador2'],
      valorContador3: json['valorContador3'],
      profileId: json['profileId'],
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
