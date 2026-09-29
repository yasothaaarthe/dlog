class InsuranceDetails {
  final String provider;
  final String policyNumber;
  final DateTime expiryDate;
  final String vehicleRegistration;
  final String roadsideNumber;

  const InsuranceDetails({
    required this.provider,
    required this.policyNumber,
    required this.expiryDate,
    required this.vehicleRegistration,
    required this.roadsideNumber,
  });

  Map<String, dynamic> toMap() => {
    'provider': provider,
    'policyNumber': policyNumber,
    'expiryDate': _dateOnly(expiryDate),
    'vehicleRegistration': vehicleRegistration,
    'roadsideNumber': roadsideNumber,
  };

  factory InsuranceDetails.fromMap(Map<String, dynamic> map) {
    return InsuranceDetails(
      provider: map['provider'] as String? ?? '',
      policyNumber: map['policyNumber'] as String? ?? '',
      expiryDate: _parseDate(map['expiryDate']),
      vehicleRegistration: map['vehicleRegistration'] as String? ?? '',
      roadsideNumber: map['roadsideNumber'] as String? ?? '',
    );
  }
}

class RoadTaxDetails {
  final String vehicleRegistration;
  final DateTime expiryDate;

  const RoadTaxDetails({
    required this.vehicleRegistration,
    required this.expiryDate,
  });

  Map<String, dynamic> toMap() => {
    'vehicleRegistration': vehicleRegistration,
    'expiryDate': _dateOnly(expiryDate),
  };

  factory RoadTaxDetails.fromMap(Map<String, dynamic> map) {
    return RoadTaxDetails(
      vehicleRegistration: map['vehicleRegistration'] as String? ?? '',
      expiryDate: _parseDate(map['expiryDate']),
    );
  }
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _parseDate(dynamic value) {
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
  }
  throw const FormatException('Vehicle document expiry date is missing.');
}
