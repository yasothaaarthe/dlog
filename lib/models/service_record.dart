import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRecord {
  final String id;

  final String vehicleId;

  /// What maintenance was performed or what component was inspected.
  ///
  /// Examples:
  /// Engine Oil
  /// Engine Oil Filter
  /// Brake Fluid
  /// Brake System
  /// Tyres
  /// Battery
  final String maintenanceItem;

  /// Date the service or inspection was performed.
  final DateTime serviceDate;

  /// Vehicle mileage when the service or inspection was performed.
  final int mileageAtService;

  /// Result of a condition-based inspection.
  ///
  /// true  = condition is okay / passed
  /// false = attention or replacement is required
  /// null  = no condition assessment was recorded
  ///
  /// This is primarily used for condition-based maintenance such as:
  /// Brake System, Tyres and Battery.
  final bool? conditionPassed;

  /// Optional oil specification recorded during the service.
  ///
  /// Example:
  /// 5W-30 API SN
  final String? oilSpecification;

  /// Optional notes entered by the user.
  final String? notes;

  /// When this service record was created in DLog.
  final DateTime createdAt;

  const ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.maintenanceItem,
    required this.serviceDate,
    required this.mileageAtService,
    this.conditionPassed,
    this.oilSpecification,
    this.notes,
    required this.createdAt,
  });

  /// Convert the model into a Firestore document.
  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'maintenanceItem': maintenanceItem,
      'serviceDate': Timestamp.fromDate(serviceDate),
      'mileageAtService': mileageAtService,
      'conditionPassed': conditionPassed,
      'oilSpecification': oilSpecification,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create a ServiceRecord from a Firestore document.
  factory ServiceRecord.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return ServiceRecord(
      id: id,
      vehicleId: map['vehicleId'] as String? ?? '',
      maintenanceItem:
          map['maintenanceItem'] as String? ?? '',
      serviceDate:
          _dateTimeFromFirestore(map['serviceDate']),
      mileageAtService:
          (map['mileageAtService'] as num?)?.toInt() ?? 0,
      conditionPassed:
          _boolFromFirestore(map['conditionPassed']),
      oilSpecification:
          map['oilSpecification'] as String?,
      notes:
          map['notes'] as String?,
      createdAt:
          _dateTimeFromFirestore(map['createdAt']),
    );
  }

  /// Safely converts Firestore Timestamp or DateTime.
  static DateTime _dateTimeFromFirestore(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    // Fallback for incomplete/older records.
    return DateTime.now();
  }

  /// Safely converts a Firestore value into a nullable bool.
  ///
  /// Older service records may not contain conditionPassed at all.
  /// Those records therefore return null instead of causing an error.
  static bool? _boolFromFirestore(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is bool) {
      return value;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      if (normalized == 'true') {
        return true;
      }

      if (normalized == 'false') {
        return false;
      }
    }

    return null;
  }

  /// Create a copy while changing selected fields.
  ServiceRecord copyWith({
    String? id,
    String? vehicleId,
    String? maintenanceItem,
    DateTime? serviceDate,
    int? mileageAtService,
    bool? conditionPassed,
    String? oilSpecification,
    String? notes,
    DateTime? createdAt,
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      maintenanceItem:
          maintenanceItem ?? this.maintenanceItem,
      serviceDate:
          serviceDate ?? this.serviceDate,
      mileageAtService:
          mileageAtService ?? this.mileageAtService,
      conditionPassed:
          conditionPassed ?? this.conditionPassed,
      oilSpecification:
          oilSpecification ?? this.oilSpecification,
      notes: notes ?? this.notes,
      createdAt:
          createdAt ?? this.createdAt,
    );
  }
}