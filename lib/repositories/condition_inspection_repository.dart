import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/maintenance_rules.dart';
import '../models/maintenance_rule.dart';
import '../models/condition_inspection_record.dart';

class ConditionInspectionRepository {
  ConditionInspectionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> saveCompletedInspection({
    required String vehicleId,
    required String maintenanceItem,
    required DateTime inspectionDate,
    required int odometerAtInspection,
    required Map<String, bool> completedChecklist,
    required bool conditionPassed,
    String notes = '',
  }) async {
    if (vehicleId.trim().isEmpty) {
      throw ArgumentError('A vehicle is required for this inspection.');
    }
    if (maintenanceItem.trim().isEmpty) {
      throw ArgumentError('A maintenance item is required.');
    }
    if (odometerAtInspection < 0) {
      throw ArgumentError('The inspection odometer cannot be negative.');
    }

    final vehicleReference = _firestore.collection('vehicles').doc(vehicleId);
    final recordReference = _firestore.collection('serviceRecords').doc();

    await _firestore.runTransaction((transaction) async {
      final vehicleSnapshot = await transaction.get(vehicleReference);
      if (!vehicleSnapshot.exists) {
        throw StateError('Vehicle record no longer exists.');
      }

      final ruleGroupId =
          vehicleSnapshot.data()?['ruleGroupId']?.toString() ?? '';
      MaintenanceRule? matchingRule;
      for (final rule in MaintenanceRules.forRuleGroup(ruleGroupId)) {
        if (rule.maintenanceItem.trim().toLowerCase() ==
            maintenanceItem.trim().toLowerCase()) {
          matchingRule = rule;
          break;
        }
      }
      final policy = matchingRule?.conditionInspectionPolicy;
      if (matchingRule == null ||
          !matchingRule.isConditionBased ||
          policy == null) {
        throw StateError(
          'This vehicle has no configured inspection checklist.',
        );
      }
      if (completedChecklist.length != policy.checklistItems.length ||
          policy.checklistItems.any(
            (item) => completedChecklist[item] != true,
          )) {
        throw ArgumentError('Complete every checklist item before confirming.');
      }

      final persistedMileage =
          (vehicleSnapshot.data()?['currentMileage'] as num?)?.round() ?? 0;
      final record = ConditionInspectionRecord(
        vehicleId: vehicleId,
        maintenanceItem: maintenanceItem,
        inspectionDate: inspectionDate,
        // Preserve the odometer reading the user actually recorded for this
        // inspection. Never replace historical inspection mileage with the
        // vehicle's newer current odometer.
        odometerAtInspection: odometerAtInspection,
        completedChecklist: Map<String, bool>.unmodifiable(completedChecklist),
        conditionPassed: conditionPassed,
        notes: notes.trim(),
      );

      transaction.set(recordReference, {
        ...record.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (odometerAtInspection > persistedMileage) {
        transaction.update(vehicleReference, {
          'currentMileage': odometerAtInspection,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return recordReference.id;
  }
}
