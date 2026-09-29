import 'package:cloud_firestore/cloud_firestore.dart';

/// Persisted result of a completed condition checklist.
///
/// These records share the existing `serviceRecords` collection so the
/// maintenance history screens can show inspections alongside repairs. The
/// explicit record type prevents the UI from presenting one as a replacement
/// or mileage-based service.
class ConditionInspectionRecord {
  const ConditionInspectionRecord({
    required this.vehicleId,
    required this.maintenanceItem,
    required this.inspectionDate,
    required this.odometerAtInspection,
    required this.completedChecklist,
    required this.conditionPassed,
    this.notes = '',
  });

  static const String recordType = 'condition_inspection';

  final String vehicleId;
  final String maintenanceItem;
  final DateTime inspectionDate;
  final int odometerAtInspection;
  final Map<String, bool> completedChecklist;
  final bool conditionPassed;
  final String notes;

  Map<String, dynamic> toFirestore() => {
    'recordType': recordType,
    'vehicleId': vehicleId,
    'maintenanceItem': maintenanceItem,
    // Keep the existing history fields populated for backwards-compatible
    // sorting and rendering in the service-record screens.
    'serviceDate': Timestamp.fromDate(inspectionDate),
    'inspectionDate': Timestamp.fromDate(inspectionDate),
    'mileageAtService': odometerAtInspection,
    'mileageAtInspection': odometerAtInspection,
    'conditionChecklist': completedChecklist,
    'inspectionStatus': conditionPassed ? 'good' : 'attention_required',
    'conditionPassed': conditionPassed,
    'notes': notes,
  };

  factory ConditionInspectionRecord.fromFirestore(Map<String, dynamic> data) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime(2000);
    }

    final rawChecklist = data['conditionChecklist'];
    final checklist = <String, bool>{};
    if (rawChecklist is Map) {
      for (final entry in rawChecklist.entries) {
        checklist[entry.key.toString()] = entry.value == true;
      }
    }

    final mileage = data['mileageAtInspection'] ?? data['mileageAtService'];

    return ConditionInspectionRecord(
      vehicleId: data['vehicleId']?.toString() ?? '',
      maintenanceItem: data['maintenanceItem']?.toString() ?? '',
      inspectionDate: readDate(data['inspectionDate'] ?? data['serviceDate']),
      odometerAtInspection: mileage is num
          ? mileage.round()
          : int.tryParse(mileage?.toString() ?? '') ?? 0,
      completedChecklist: Map<String, bool>.unmodifiable(checklist),
      conditionPassed: data['conditionPassed'] == true,
      notes: data['notes']?.toString() ?? '',
    );
  }
}
