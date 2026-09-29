import 'package:flutter_test/flutter_test.dart';

import 'package:dlog_new/data/maintenance_rules.dart';
import 'package:dlog_new/models/maintenance_rule.dart';
import 'package:dlog_new/services/maintenance_calculator.dart';
import 'package:dlog_new/services/vehicle_status_rollup.dart';

void main() {
  test('every configured vehicle rule maps to a status group', () {
    final groupIds = MaintenanceRules.all
        .map((rule) => rule.ruleGroupId)
        .toSet();

    for (final groupId in groupIds) {
      final results = MaintenanceCalculator.calculateAll(
        rules: MaintenanceRules.forRuleGroup(groupId),
        currentMileage: 0,
        currentDate: DateTime(2026, 9, 27),
        vehicleLifecycle: 'new',
      );

      expect(
        VehicleStatusRollup.unmappedMaintenanceItems(results),
        isEmpty,
        reason: 'Unmapped status items for $groupId',
      );
    }
  });

  test('vehicle status rolls up every matching maintenance item', () {
    final rules = MaintenanceRules.forRuleGroup('AXIA_2019');
    MaintenanceRule rule(String name) =>
        rules.singleWhere((candidate) => candidate.maintenanceItem == name);

    MaintenanceResult result(String name, MaintenanceStatus status) =>
        MaintenanceResult(
          rule: rule(name),
          status: status,
          graceUsedMileage: 0,
          graceWindowMileage: MaintenanceCalculator.defaultGraceWindowKm,
          graceUsedDays: 0,
          graceWindowDays: MaintenanceCalculator.defaultGraceWindowDays,
        );

    final groups = VehicleStatusRollup.fromResults([
      result('Engine Oil Filter', MaintenanceStatus.dueNow),
      result('Engine Air Filter', MaintenanceStatus.allGood),
      result('Tyres', MaintenanceStatus.allGood),
      result('Tyre Rotation', MaintenanceStatus.gracePeriod),
    ]);
    final statusByTitle = {
      for (final group in groups) group.title: group.status,
    };

    expect(statusByTitle['Engine'], MaintenanceStatus.dueNow);
    expect(statusByTitle['Tires'], MaintenanceStatus.gracePeriod);
    expect(statusByTitle.containsKey('Transmission'), isFalse);
  });
}
