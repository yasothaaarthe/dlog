import 'package:cloud_firestore/cloud_firestore.dart';

import '../repositories/vehicle_repository.dart';
import 'maintenance_calculator.dart';
import '../data/maintenance_rules.dart';

class MaintenanceStatusSnapshot {
  const MaintenanceStatusSnapshot({
    required this.vehicle,
    required this.results,
    required this.latestServiceByItem,
    required this.serviceRecordsByItem,
  });

  final Map<String, dynamic> vehicle;
  final List<MaintenanceResult> results;
  final Map<String, Map<String, dynamic>> latestServiceByItem;
  final Map<String, List<Map<String, dynamic>>> serviceRecordsByItem;
}

/// Single source of truth for DLog maintenance status.
///
/// Every screen that needs maintenance status should call this service
/// instead of loading rules and calling MaintenanceCalculator itself.
class MaintenanceStatusService {
  const MaintenanceStatusService();

  Future<List<MaintenanceResult>> calculateForVehicle(
    Map<String, dynamic> inputVehicle, {
    int? currentMileageOverride,
    DateTime? currentDateOverride,
  }) async {
    final snapshot = await loadForVehicle(
      inputVehicle,
      currentMileageOverride: currentMileageOverride,
      currentDateOverride: currentDateOverride,
    );
    return snapshot.results;
  }

  Future<MaintenanceStatusSnapshot> loadForVehicle(
    Map<String, dynamic> inputVehicle, {
    int? currentMileageOverride,
    DateTime? currentDateOverride,
  }) async {
    Map<String, dynamic> vehicle = Map<String, dynamic>.from(inputVehicle);

    // Always prefer the latest persisted vehicle data when an ID exists.
    // This prevents Home, Vehicle Status and Maintenance List from
    // calculating against different/stale vehicle maps.
    final vehicleId = vehicle['id']?.toString() ?? '';

    if (vehicleId.isNotEmpty) {
      final latestVehicle = await VehicleRepository().getVehicle(vehicleId);

      if (latestVehicle != null) {
        vehicle = Map<String, dynamic>.from(latestVehicle);
      }
    }

    final ruleGroupId = vehicle['ruleGroupId']?.toString() ?? '';

    if (ruleGroupId.isEmpty) {
      throw Exception('Maintenance profile is not available for this vehicle.');
    }

    final currentMileage =
        currentMileageOverride ??
        (vehicle['currentMileage'] as num?)?.round() ??
        0;
    final evaluationDate = currentDateOverride ?? DateTime.now();

    final vehicleLifecycle =
        vehicle['vehicleLifecycle']?.toString().trim().toLowerCase() ??
        'existing';

    final vehicleStartDate = _readDate(vehicle['createdAt']);

    // Onboarding history is only an anchor for maintenance items the
    // user explicitly said they had recently serviced.
    final serviceHistoryKnown = vehicle['serviceHistoryKnown'] == true;

    final onboardingLastServiceMileage = _readInt(
      vehicle['lastServiceMileage'],
    );

    final onboardingLastServiceDate = _readDate(vehicle['lastServiceDate']);

    final onboardingServiceItems = <String>{
      if (vehicle['recentServiceItems'] is Iterable)
        ...(vehicle['recentServiceItems'] as Iterable)
            .map((item) => item.toString().trim().toLowerCase())
            .where((item) => item.isNotEmpty),
    };

    final rules = MaintenanceRules.forRuleGroup(ruleGroupId);

    // Load the latest real service record for each maintenance item.
    final latestByItem = <String, Map<String, dynamic>>{};
    final historyByItem = <String, List<Map<String, dynamic>>>{};

    if (vehicleId.isNotEmpty) {
      final snapshot = await FirebaseFirestore.instance
          .collection('serviceRecords')
          .where('vehicleId', isEqualTo: vehicleId)
          .get();

      for (final doc in snapshot.docs) {
        final data = <String, dynamic>{...doc.data(), 'id': doc.id};

        final item = (data['item'] ?? data['maintenanceItem'] ?? '')
            .toString()
            .trim();

        if (item.isEmpty) continue;

        final key = item.toLowerCase();
        historyByItem.putIfAbsent(key, () => []).add(data);
        final existing = latestByItem[key];

        if (existing == null || _isNewerRecord(data, existing)) {
          latestByItem[key] = data;
        }
      }
    }

    for (final records in historyByItem.values) {
      records.sort((a, b) {
        final dateA = _readDate(a['inspectionDate'] ?? a['serviceDate']);
        final dateB = _readDate(b['inspectionDate'] ?? b['serviceDate']);
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
    }

    final results = rules
        .map((rule) {
          final ruleKey = rule.maintenanceItem.trim().toLowerCase();

          final service = latestByItem[ruleKey];

          final hasOnboardingServiceAnchor =
              serviceHistoryKnown && onboardingServiceItems.contains(ruleKey);

          final serviceMileage =
              _readInt(
                service?['mileageAtInspection'] ??
                    service?['mileage'] ??
                    service?['mileageAtService'],
              ) ??
              (hasOnboardingServiceAnchor
                  ? onboardingLastServiceMileage
                  : null);

          final serviceDate =
              _readDate(
                service?['inspectionDate'] ?? service?['serviceDate'],
              ) ??
              (hasOnboardingServiceAnchor ? onboardingLastServiceDate : null);

          // Condition-based items only receive a condition result when
          // an actual boolean assessment was saved.
          final storedCondition = service?['conditionPassed'];

          final conditionPassed = rule.isConditionBased
              ? (storedCondition is bool ? storedCondition : null)
              : null;

          return MaintenanceCalculator.calculate(
            rule: rule,
            currentMileage: currentMileage,
            lastServiceMileage: serviceMileage,
            lastServiceDate: serviceDate,
            vehicleStartDate: vehicleStartDate,
            vehicleLifecycle: vehicleLifecycle,
            conditionPassed: conditionPassed,
            currentDate: evaluationDate,
          );
        })
        .where((result) => result.isApplicable)
        .toList();

    return MaintenanceStatusSnapshot(
      vehicle: Map<String, dynamic>.unmodifiable(vehicle),
      results: List<MaintenanceResult>.unmodifiable(results),
      latestServiceByItem: Map<String, Map<String, dynamic>>.unmodifiable(
        latestByItem.map(
          (key, value) =>
              MapEntry(key, Map<String, dynamic>.unmodifiable(value)),
        ),
      ),
      serviceRecordsByItem:
          Map<String, List<Map<String, dynamic>>>.unmodifiable(
            historyByItem.map(
              (key, records) => MapEntry(
                key,
                List<Map<String, dynamic>>.unmodifiable(
                  records.map(Map<String, dynamic>.unmodifiable),
                ),
              ),
            ),
          ),
    );
  }

  bool _isNewerRecord(
    Map<String, dynamic> candidate,
    Map<String, dynamic> existing,
  ) {
    final candidateDate = _readDate(
      candidate['inspectionDate'] ?? candidate['serviceDate'],
    );
    final existingDate = _readDate(
      existing['inspectionDate'] ?? existing['serviceDate'],
    );

    if (candidateDate != null && existingDate != null) {
      if (candidateDate.isAfter(existingDate)) return true;
      if (candidateDate.isBefore(existingDate)) return false;
    } else if (candidateDate != null) {
      return true;
    } else if (existingDate != null) {
      return false;
    }

    final candidateMileage = _readInt(
      candidate['mileageAtInspection'] ??
          candidate['mileage'] ??
          candidate['mileageAtService'],
    );
    final existingMileage = _readInt(
      existing['mileageAtInspection'] ??
          existing['mileage'] ??
          existing['mileageAtService'],
    );

    if (candidateMileage != null && existingMileage != null) {
      if (candidateMileage != existingMileage) {
        return candidateMileage > existingMileage;
      }
    } else if (candidateMileage != null) {
      return true;
    } else if (existingMileage != null) {
      return false;
    }

    final candidateCreatedAt = _readDate(candidate['createdAt']);
    final existingCreatedAt = _readDate(existing['createdAt']);
    return candidateCreatedAt != null &&
        (existingCreatedAt == null ||
            candidateCreatedAt.isAfter(existingCreatedAt));
  }

  int? _readInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is num) return value.round();

    return int.tryParse(value.toString());
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }
}
