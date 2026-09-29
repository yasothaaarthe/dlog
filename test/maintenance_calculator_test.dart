import 'package:flutter_test/flutter_test.dart';

import 'package:dlog_new/data/maintenance_rules.dart';
import 'package:dlog_new/models/maintenance_rule.dart';
import 'package:dlog_new/services/maintenance_calculator.dart';
import 'package:dlog_new/services/maintenance_status_service.dart';

void main() {
  test('New Axia 2019 schedule at 22,000 km', () {
    // Get the real Axia 2019 rules.
    final rules = MaintenanceRules.forRuleGroup('AXIA_2019');

    // Simulate the vehicle's current mileage.
    const currentMileage = 22000;

    // Run ALL rules through the central calculator.
    final results = MaintenanceCalculator.calculateAll(
      rules: rules,
      currentMileage: currentMileage,
      vehicleLifecycle: 'new',
    );

    // Make sure rules actually loaded.
    expect(results, isNotEmpty);

    // Find specific maintenance items.
    final engineOil = results.firstWhere(
      (result) => result.rule.maintenanceItem == 'Engine Oil',
    );

    final oilFilter = results.firstWhere(
      (result) => result.rule.maintenanceItem == 'Engine Oil Filter',
    );

    final brakeFluid = results.firstWhere(
      (result) => result.rule.maintenanceItem == 'Brake Fluid',
    );

    final atf = results.firstWhere(
      (result) => result.rule.maintenanceItem == 'Automatic Transmission Fluid',
    );

    // ------------------------------------------------------
    // ENGINE OIL
    // ------------------------------------------------------
    //
    // Interval = 10,000 km
    // Current = 22,000 km
    //
    // Next cycle should be 30,000 km.
    expect(engineOil.nextDueMileage, 30000);

    expect(engineOil.remainingMileage, 8000);

    expect(engineOil.status, MaintenanceStatus.allGood);

    // ------------------------------------------------------
    // OIL FILTER
    // ------------------------------------------------------

    expect(oilFilter.nextDueMileage, 30000);

    expect(oilFilter.remainingMileage, 8000);

    expect(oilFilter.status, MaintenanceStatus.allGood);

    // ------------------------------------------------------
    // BRAKE FLUID
    // ------------------------------------------------------
    //
    // Interval = 40,000 km
    // Current = 22,000 km
    //
    // Next due = 40,000 km.
    expect(brakeFluid.nextDueMileage, 40000);

    expect(brakeFluid.remainingMileage, 18000);

    expect(brakeFluid.status, MaintenanceStatus.allGood);

    // ------------------------------------------------------
    // AUTOMATIC TRANSMISSION FLUID
    // ------------------------------------------------------

    expect(atf.nextDueMileage, 40000);

    expect(atf.remainingMileage, 18000);

    expect(atf.status, MaintenanceStatus.allGood);

    // ------------------------------------------------------
    // PRINT RESULTS FOR US TO SEE
    // ------------------------------------------------------

    print('');
    print('======================================');
    print('DLOG MAINTENANCE CALCULATOR TEST');
    print('======================================');
    print('Vehicle: Perodua Axia 2019');
    print('Current mileage: $currentMileage km');
    print('');

    for (final result in results) {
      print(
        '${result.rule.maintenanceItem}'
        ' → '
        '${result.status.name}'
        ' → '
        '${result.nextDueMileage ?? 'N/A'} km',
      );
    }

    print('');
    print('======================================');
  });

  test(
    'existing Axia with unknown history does not invent a service cycle',
    () {
      final engineOilRule = MaintenanceRules.forRuleGroup(
        'AXIA_2019',
      ).singleWhere((rule) => rule.maintenanceItem == 'Engine Oil');

      final result = MaintenanceCalculator.calculate(
        rule: engineOilRule,
        currentMileage: 22000,
        currentDate: DateTime(2026, 9, 27),
      );

      expect(result.nextDueMileage, isNull);
      expect(result.nextDueDate, isNull);
      expect(result.status, MaintenanceStatus.dueSoon);
      expect(result.requiresHistory, isTrue);
      expect(
        MaintenanceCalculator.countStatus([result], MaintenanceStatus.dueSoon),
        1,
      );
    },
  );

  test('Tyre Rotation needs its own real service anchor', () {
    final rotationRule = MaintenanceRules.forRuleGroup(
      'AXIA_2019',
    ).singleWhere((rule) => rule.maintenanceItem == 'Tyre Rotation');

    final result = MaintenanceCalculator.calculate(
      rule: rotationRule,
      currentMileage: 20000,
      currentDate: DateTime(2026, 9, 28),
    );

    expect(rotationRule.mileageInterval, 10000);
    expect(result.nextDueMileage, isNull);
    expect(result.requiresHistory, isTrue);
  });

  test('Tyre Rotation at 20,000 km predicts the 30,000 km milestone', () {
    final rotationRule = MaintenanceRules.forRuleGroup(
      'AXIA_2019',
    ).singleWhere((rule) => rule.maintenanceItem == 'Tyre Rotation');

    final result = MaintenanceCalculator.calculate(
      rule: rotationRule,
      currentMileage: 20000,
      lastServiceMileage: 20000,
      currentDate: DateTime(2026, 9, 28),
    );

    expect(result.nextDueMileage, 30000);
    expect(result.remainingMileage, 10000);
    expect(result.status, MaintenanceStatus.allGood);
  });

  test('condition item without an inspection needs a real assessment', () {
    final tyreRule = MaintenanceRules.forRuleGroup(
      'AXIA_2019',
    ).singleWhere((rule) => rule.maintenanceItem == 'Tyres');

    final result = MaintenanceCalculator.calculate(
      rule: tyreRule,
      currentMileage: 20000,
      currentDate: DateTime(2026, 9, 28),
    );

    expect(tyreRule.isConditionBased, isTrue);
    expect(result.status, MaintenanceStatus.dueNow);
    expect(result.conditionAssessmentRequired, isTrue);
    expect(result.hasCalculationBasis, isFalse);
    expect(result.nextDueMileage, isNull);
    expect(result.nextDueDate, isNull);
  });

  test('condition inspection date drives all four statuses and next check', () {
    final tyreRule = MaintenanceRules.forRuleGroup(
      'AXIA_2019',
    ).singleWhere((rule) => rule.maintenanceItem == 'Tyres');
    final completedOn = DateTime(2026, 9, 1);

    MaintenanceResult calculateOn(DateTime date) =>
        MaintenanceCalculator.calculate(
          rule: tyreRule,
          currentMileage: 20000,
          lastServiceDate: completedOn,
          conditionPassed: true,
          currentDate: date,
        );

    final allGood = calculateOn(DateTime(2026, 9, 1));
    expect(allGood.status, MaintenanceStatus.allGood);
    expect(allGood.nextDueDate, DateTime(2026, 9, 15));
    expect(allGood.remainingDays, 14);
    expect(allGood.nextDueMileage, isNull);

    expect(
      calculateOn(DateTime(2026, 9, 12)).status,
      MaintenanceStatus.dueSoon,
    );
    expect(calculateOn(DateTime(2026, 9, 15)).status, MaintenanceStatus.dueNow);

    final grace = calculateOn(DateTime(2026, 9, 16));
    expect(grace.status, MaintenanceStatus.gracePeriod);
    expect(grace.graceUsedDays, 1);
    expect(grace.graceProgressWindow, 3);

    final beyondGrace = calculateOn(DateTime(2026, 9, 19));
    expect(beyondGrace.status, MaintenanceStatus.gracePeriod);
    expect(beyondGrace.graceProgressUsed, 3);
    expect(beyondGrace.graceExceededBy, 1);
  });

  test('condition inspection needing attention stays due now', () {
    final batteryRule = MaintenanceRules.forRuleGroup(
      'AXIA_2019',
    ).singleWhere((rule) => rule.maintenanceItem == 'Battery');

    final result = MaintenanceCalculator.calculate(
      rule: batteryRule,
      currentMileage: 20000,
      lastServiceDate: DateTime(2026, 9, 28),
      conditionPassed: false,
      currentDate: DateTime(2026, 9, 28),
    );

    expect(result.status, MaintenanceStatus.dueNow);
    expect(result.nextDueDate, isNull);
    expect(result.conditionAssessmentRequired, isFalse);
  });

  test('condition rules expose configured checklist and cadence', () {
    for (final groupId
        in MaintenanceRules.all.map((rule) => rule.ruleGroupId).toSet()) {
      final rules = MaintenanceRules.forRuleGroup(groupId);
      final engine = rules.singleWhere(
        (candidate) => candidate.maintenanceItem == 'Engine',
      );
      expect(engine.isConditionBased, isTrue, reason: '$groupId / Engine');
      expect(engine.conditionInspectionPolicy, isNotNull);

      for (final rule in rules.where(
        (candidate) => candidate.isConditionBased,
      )) {
        expect(
          rule.conditionInspectionPolicy,
          isNotNull,
          reason: '$groupId / ${rule.maintenanceItem}',
        );
        expect(rule.conditionInspectionPolicy!.checklistItems, isNotEmpty);
      }
    }
  });

  test('overdue Axia oil stays in grace and caps progress at 500 km', () {
    final oilRule = MaintenanceRules.forRuleGroup(
      'AXIA_2019',
    ).singleWhere((rule) => rule.maintenanceItem == 'Engine Oil');

    MaintenanceResult calculateAt(int mileage) =>
        MaintenanceCalculator.calculate(
          rule: oilRule,
          currentMileage: mileage,
          lastServiceMileage: 9000,
          lastServiceDate: DateTime(2026, 9, 27),
          currentDate: DateTime(2026, 9, 27),
        );

    final exactlyDue = calculateAt(19000);
    expect(exactlyDue.status, MaintenanceStatus.dueNow);

    final graceStarted = calculateAt(19001);
    expect(graceStarted.status, MaintenanceStatus.gracePeriod);
    expect(graceStarted.graceProgressUsed, 1);

    final graceLimit = calculateAt(19500);
    expect(graceLimit.status, MaintenanceStatus.gracePeriod);
    expect(graceLimit.graceUsedMileage, 500);
    expect(graceLimit.graceProgressUsed, 500);

    final beyondGraceLimit = calculateAt(20000);
    expect(beyondGraceLimit.nextDueMileage, 19000);
    expect(beyondGraceLimit.status, MaintenanceStatus.gracePeriod);
    expect(beyondGraceLimit.graceUsedMileage, 1000);
    expect(beyondGraceLimit.graceProgressWindow, 500);
    expect(beyondGraceLimit.graceProgressUsed, 500);
  });

  test('time-based overdue oil also stays in grace and caps at 14 days', () {
    final oilRule = MaintenanceRules.forRuleGroup(
      'AXIA_2019',
    ).singleWhere((rule) => rule.maintenanceItem == 'Engine Oil');

    MaintenanceResult calculateOn(DateTime date) =>
        MaintenanceCalculator.calculate(
          rule: oilRule,
          currentMileage: 18000,
          lastServiceMileage: 9000,
          lastServiceDate: DateTime(2026, 9, 27),
          currentDate: date,
        );

    final oneDayLate = calculateOn(DateTime(2027, 3, 28));
    expect(oneDayLate.status, MaintenanceStatus.gracePeriod);
    expect(oneDayLate.graceProgressUsesMileage, isFalse);
    expect(oneDayLate.graceProgressUsed, 1);

    final beyondTimeAllowance = calculateOn(DateTime(2027, 4, 12));
    expect(beyondTimeAllowance.status, MaintenanceStatus.gracePeriod);
    expect(beyondTimeAllowance.graceUsedDays, 16);
    expect(beyondTimeAllowance.graceProgressWindow, 14);
    expect(beyondTimeAllowance.graceProgressUsed, 14);
    expect(beyondTimeAllowance.graceExceededBy, 2);
  });

  test('calendar month simulation clamps short months correctly', () {
    expect(
      MaintenanceCalculator.addCalendarMonths(DateTime(2026, 1, 31), 1),
      DateTime(2026, 2, 28),
    );
    expect(
      MaintenanceCalculator.addCalendarMonths(DateTime(2024, 1, 31), 1),
      DateTime(2024, 2, 29),
    );
  });

  test('simulated mileage and date use the shared status service without '
      'changing the saved vehicle odometer', () async {
    final vehicle = <String, dynamic>{
      'ruleGroupId': 'AXIA_2019',
      'vehicleLifecycle': 'existing',
      'currentMileage': 20000,
      'serviceHistoryKnown': true,
      'lastServiceMileage': 20000,
      'lastServiceDate': DateTime(2026, 1, 31),
      'recentServiceItems': ['Engine Oil'],
    };

    final snapshot = await const MaintenanceStatusService().loadForVehicle(
      vehicle,
      currentMileageOverride: 30000,
      currentDateOverride: DateTime(2026, 7, 31),
    );
    final engineOil = snapshot.results.singleWhere(
      (result) => result.rule.maintenanceItem == 'Engine Oil',
    );

    expect(engineOil.nextDueMileage, 30000);
    expect(engineOil.nextDueDate, DateTime(2026, 7, 31));
    expect(engineOil.status, MaintenanceStatus.dueNow);
    expect(snapshot.vehicle['currentMileage'], 20000);
  });

  test(
    'simulator keeps unknown service history unknown after mileage jumps',
    () async {
      final snapshot = await const MaintenanceStatusService().loadForVehicle(
        const <String, dynamic>{
          'ruleGroupId': 'AXIA_2019',
          'vehicleLifecycle': 'existing',
          'currentMileage': 20000,
        },
        currentMileageOverride: 50000,
        currentDateOverride: DateTime(2026, 9, 27),
      );
      final engineOil = snapshot.results.singleWhere(
        (result) => result.rule.maintenanceItem == 'Engine Oil',
      );

      expect(engineOil.nextDueMileage, isNull);
      expect(engineOil.nextDueDate, isNull);
      expect(engineOil.requiresHistory, isTrue);
    },
  );
}
