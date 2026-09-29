import '../models/maintenance_rule.dart';

class MaintenanceResult {
  final MaintenanceRule rule;
  final MaintenanceStatus status;

  // Mileage information
  final int? nextDueMileage;
  final int? remainingMileage;
  final int graceUsedMileage;
  final int graceWindowMileage;

  // Time information
  final DateTime? nextDueDate;
  final int? remainingDays;
  final int graceUsedDays;
  final int graceWindowDays;

  // Calculation/data-state information
  //
  // A result can have a status of ALL GOOD while still having no usable
  // schedule basis. This prevents the calculator from inventing a due date
  // for an existing vehicle with unknown service history.
  final bool hasCalculationBasis;

  // True when a condition-based item needs an explicit inspection/service
  // condition before DLog can say that it is actually in good condition.
  final bool conditionAssessmentRequired;

  // False when the rule is intentionally skipped, for example an INITIAL
  // rule on an EXISTING vehicle.
  final bool isApplicable;

  const MaintenanceResult({
    required this.rule,
    required this.status,
    this.nextDueMileage,
    this.remainingMileage,
    required this.graceUsedMileage,
    required this.graceWindowMileage,
    this.nextDueDate,
    this.remainingDays,
    required this.graceUsedDays,
    required this.graceWindowDays,
    this.hasCalculationBasis = true,
    this.conditionAssessmentRequired = false,
    this.isApplicable = true,
  });

  bool get isAllGood =>
      status == MaintenanceStatus.allGood &&
      isApplicable &&
      hasCalculationBasis &&
      !conditionAssessmentRequired;

  bool get isDueSoon => status == MaintenanceStatus.dueSoon && isApplicable;

  bool get isDueNow => status == MaintenanceStatus.dueNow && isApplicable;

  bool get isGracePeriod =>
      status == MaintenanceStatus.gracePeriod && isApplicable;

  bool get requiresHistory =>
      isApplicable && !hasCalculationBasis && !conditionAssessmentRequired;

  /// Selects the grace limit with the least remaining proportion when both
  /// mileage and time have crossed their due points.
  bool get graceProgressUsesMileage {
    if (graceUsedMileage <= 0) return false;
    if (graceUsedDays <= 0) return true;

    final mileageProgress = graceWindowMileage <= 0
        ? 1.0
        : graceUsedMileage / graceWindowMileage;
    final timeProgress = graceWindowDays <= 0
        ? 1.0
        : graceUsedDays / graceWindowDays;
    return mileageProgress >= timeProgress;
  }

  int get graceProgressUsed {
    final window = graceProgressWindow;
    if (window <= 0) return 0;
    final used = graceActualUsed;
    if (used <= 0) return 0;
    if (used >= window) return window;
    return used;
  }

  int get graceProgressWindow =>
      graceProgressUsesMileage ? graceWindowMileage : graceWindowDays;

  int get graceActualUsed =>
      graceProgressUsesMileage ? graceUsedMileage : graceUsedDays;

  int get graceExceededBy {
    final exceeded = graceActualUsed - graceProgressWindow;
    return exceeded > 0 ? exceeded : 0;
  }
}

/// Central maintenance calculation engine for ALL DLog vehicles.
///
/// Vehicle-specific maintenance information comes from MaintenanceRule.
///
/// The calculator evaluates:
///   mileage OR time
/// Whichever reaches the maintenance threshold first determines the status.
///
/// Lifecycle is supplied by the vehicle:
///   NEW
///     - INITIAL rules are applicable.
///     - RECURRING rules can use the vehicle's first scheduled cycle.
///   EXISTING
///     - INITIAL rules are skipped.
///     - RECURRING rules require known service history.
///     - Unknown service history is never invented.
///
/// CONDITION_BASED rules are handled separately from mileage/time.
class MaintenanceCalculator {
  /// DLog application grace window in kilometres.
  ///
  /// This is an application progress cap, NOT a manufacturer maintenance
  /// interval. Passing the cap fills the grace bar; it does not change the
  /// item's final Grace Period status.
  static const int defaultGraceWindowKm = 500;

  /// DLog application grace progress cap in days.
  ///
  /// This is an application setting, NOT a manufacturer maintenance interval.
  static const int defaultGraceWindowDays = 14;

  /// Calculate the maintenance state for ONE rule.
  ///
  /// [vehicleLifecycle] should be:
  ///   - 'new'
  ///   - 'existing'
  ///
  /// It defaults to 'existing' so that an unknown vehicle does not
  /// accidentally receive INITIAL/new-vehicle treatment.
  ///
  /// [vehicleStartDate] is optional and is only used when a NEW vehicle
  /// needs a time-based first schedule.
  ///
  /// [conditionPassed] is used for CONDITION_BASED rules:
  ///   true  = inspection/service record says the condition is okay
  ///   false = attention/replacement is required
  ///   null  = no condition assessment is known yet
  static MaintenanceResult calculate({
    required MaintenanceRule rule,
    required int currentMileage,
    int? lastServiceMileage,
    DateTime? lastServiceDate,
    DateTime? vehicleStartDate,
    DateTime? currentDate,
    String vehicleLifecycle = 'existing',
    bool? conditionPassed,
    int graceWindowKm = defaultGraceWindowKm,
    int graceWindowDays = defaultGraceWindowDays,
  }) {
    final DateTime evaluationDate = currentDate ?? DateTime.now();
    final String lifecycle = vehicleLifecycle.trim().toLowerCase();
    final bool isNewVehicle = lifecycle == 'new';

    // ============================================================
    // INITIAL RULES
    // ============================================================
    //
    // Initial rules belong to the NEW vehicle lifecycle.
    // Existing vehicles must not be shown an invented initial service.
    if (rule.isInitial && !isNewVehicle) {
      return MaintenanceResult(
        rule: rule,
        status: MaintenanceStatus.allGood,
        graceUsedMileage: 0,
        graceWindowMileage: graceWindowKm,
        graceUsedDays: 0,
        graceWindowDays: graceWindowDays,
        hasCalculationBasis: false,
        isApplicable: false,
      );
    }

    // ============================================================
    // CONDITION-BASED RULES
    // ============================================================
    //
    // Condition checks use their own date cadence from the maintenance rule.
    // This is a DLog inspection reminder, not a component replacement
    // interval. Mileage is never used to invent a condition inspection.
    if (rule.isConditionBased) {
      final policy = rule.conditionInspectionPolicy;
      final lastInspection = lastServiceDate;

      // No actual, completed inspection means DLog cannot claim the item was
      // inspected or healthy. Keep the checklist available and ask for the
      // first real assessment without fabricating a prior date or mileage.
      if (conditionPassed == false) {
        return MaintenanceResult(
          rule: rule,
          status: MaintenanceStatus.dueNow,
          graceUsedMileage: 0,
          graceWindowMileage: graceWindowKm,
          graceUsedDays: 0,
          graceWindowDays: policy?.gracePeriodDays ?? graceWindowDays,
          hasCalculationBasis: true,
          conditionAssessmentRequired: false,
        );
      }

      if (conditionPassed == null || lastInspection == null || policy == null) {
        return MaintenanceResult(
          rule: rule,
          status: MaintenanceStatus.dueNow,
          graceUsedMileage: 0,
          graceWindowMileage: graceWindowKm,
          graceUsedDays: 0,
          graceWindowDays: policy?.gracePeriodDays ?? graceWindowDays,
          hasCalculationBasis: false,
          conditionAssessmentRequired: true,
        );
      }

      final dueDate = DateTime(
        lastInspection.year,
        lastInspection.month,
        lastInspection.day,
      ).add(Duration(days: policy.checkIntervalDays));
      final today = DateTime(
        evaluationDate.year,
        evaluationDate.month,
        evaluationDate.day,
      );
      final dayDifference = dueDate.difference(today).inDays;
      final remainingDays = dayDifference > 0 ? dayDifference : 0;
      final graceUsedDays = dayDifference < 0 ? -dayDifference : 0;

      // A failed inspection is due now until a later passing inspection is
      // recorded. Otherwise use the configured date thresholds and grace.
      final status = dayDifference < 0
          ? MaintenanceStatus.gracePeriod
          : dayDifference == 0
          ? MaintenanceStatus.dueNow
          : dayDifference <= policy.dueSoonThresholdDays
          ? MaintenanceStatus.dueSoon
          : MaintenanceStatus.allGood;

      return MaintenanceResult(
        rule: rule,
        status: status,
        graceUsedMileage: 0,
        graceWindowMileage: graceWindowKm,
        nextDueDate: dueDate,
        remainingDays: remainingDays,
        graceUsedDays: graceUsedDays,
        graceWindowDays: policy.gracePeriodDays,
        hasCalculationBasis: true,
        conditionAssessmentRequired: false,
      );
    }

    // ============================================================
    // INITIAL RULE CALCULATION
    // ============================================================
    //
    // Initial maintenance is a ONE-TIME milestone.
    //
    // Once that specific maintenance item has a service record,
    // the initial rule is complete. It must not turn into a recurring
    // cycle merely because the rule contains an interval value.
    if (rule.isInitial && isNewVehicle) {
      if (lastServiceMileage != null || lastServiceDate != null) {
        return MaintenanceResult(
          rule: rule,
          status: MaintenanceStatus.allGood,
          graceUsedMileage: 0,
          graceWindowMileage: graceWindowKm,
          graceUsedDays: 0,
          graceWindowDays: graceWindowDays,
          hasCalculationBasis: true,
        );
      }

      int? nextInitialMileage;

      if (rule.firstMileage != null) {
        nextInitialMileage = rule.firstMileage!;
      }

      DateTime? nextInitialDate;

      if (rule.timeIntervalMonths != null &&
          rule.timeIntervalMonths! > 0 &&
          vehicleStartDate != null) {
        nextInitialDate = _addMonths(
          vehicleStartDate,
          rule.timeIntervalMonths!,
        );
      }

      if (nextInitialMileage == null && nextInitialDate == null) {
        return MaintenanceResult(
          rule: rule,
          status: MaintenanceStatus.dueSoon,
          graceUsedMileage: 0,
          graceWindowMileage: graceWindowKm,
          graceUsedDays: 0,
          graceWindowDays: graceWindowDays,
          hasCalculationBasis: false,
        );
      }

      final int? initialRemainingMileage = nextInitialMileage == null
          ? null
          : (nextInitialMileage! > currentMileage
                ? nextInitialMileage! - currentMileage
                : 0);

      final int initialGraceUsedMileage =
          nextInitialMileage == null || currentMileage <= nextInitialMileage!
          ? 0
          : currentMileage - nextInitialMileage!;

      int? initialRemainingDays;
      int initialGraceUsedDays = 0;

      if (nextInitialDate != null) {
        final int dayDifference = nextInitialDate
            .difference(evaluationDate)
            .inDays;

        if (dayDifference > 0) {
          initialRemainingDays = dayDifference;
        } else if (dayDifference == 0) {
          initialRemainingDays = 0;
        } else {
          initialRemainingDays = 0;
          initialGraceUsedDays = -dayDifference;
        }
      }

      final bool initialMileageDueExactly =
          nextInitialMileage != null && currentMileage == nextInitialMileage;

      final bool initialTimeDueExactly =
          nextInitialDate != null &&
          _isSameOrAfterDueDate(evaluationDate, nextInitialDate) &&
          initialGraceUsedDays == 0;

      final bool initialMileageOverdue =
          nextInitialMileage != null && currentMileage > nextInitialMileage;

      final bool initialTimeOverdue =
          nextInitialDate != null && evaluationDate.isAfter(nextInitialDate);

      if (initialMileageDueExactly || initialTimeDueExactly) {
        return MaintenanceResult(
          rule: rule,
          status: MaintenanceStatus.dueNow,
          nextDueMileage: nextInitialMileage,
          remainingMileage: initialRemainingMileage,
          graceUsedMileage: initialGraceUsedMileage,
          graceWindowMileage: graceWindowKm,
          nextDueDate: nextInitialDate,
          remainingDays: initialRemainingDays,
          graceUsedDays: initialGraceUsedDays,
          graceWindowDays: graceWindowDays,
        );
      }

      // Grace Period is the final overdue stage. The grace allowance is
      // capped for progress display; exceeding it fills the bar rather than
      // moving the item back to the earlier Due Now stage.
      if (initialMileageOverdue || initialTimeOverdue) {
        return MaintenanceResult(
          rule: rule,
          status: MaintenanceStatus.gracePeriod,
          nextDueMileage: nextInitialMileage,
          remainingMileage: initialRemainingMileage,
          graceUsedMileage: initialGraceUsedMileage,
          graceWindowMileage: graceWindowKm,
          nextDueDate: nextInitialDate,
          remainingDays: initialRemainingDays,
          graceUsedDays: initialGraceUsedDays,
          graceWindowDays: graceWindowDays,
        );
      }

      final int? initialMileageThreshold = nextInitialMileage == null
          ? null
          : _dueSoonMileageThreshold(nextInitialMileage, isInitial: true);

      final bool initialMileageDueSoon =
          initialRemainingMileage != null &&
          initialRemainingMileage > 0 &&
          initialMileageThreshold != null &&
          initialRemainingMileage <= initialMileageThreshold;

      final bool initialTimeDueSoon =
          initialRemainingDays != null &&
          initialRemainingDays > 0 &&
          rule.timeIntervalMonths != null &&
          initialRemainingDays <=
              _dueSoonDaysThreshold(rule.timeIntervalMonths!);

      return MaintenanceResult(
        rule: rule,
        status: initialMileageDueSoon || initialTimeDueSoon
            ? MaintenanceStatus.dueSoon
            : MaintenanceStatus.allGood,
        nextDueMileage: nextInitialMileage,
        remainingMileage: initialRemainingMileage,
        graceUsedMileage: 0,
        graceWindowMileage: graceWindowKm,
        nextDueDate: nextInitialDate,
        remainingDays: initialRemainingDays,
        graceUsedDays: 0,
        graceWindowDays: graceWindowDays,
      );
    }

    // ============================================================
    // MILEAGE CALCULATION
    // ============================================================

    int? nextDueMileage;
    int? remainingMileage;
    int graceUsedMileage = 0;

    if (rule.mileageInterval != null && rule.mileageInterval! > 0) {
      final int interval = rule.mileageInterval!;

      if (lastServiceMileage != null) {
        // Known service history.
        //
        // Example:
        // Last service = 20,000 km
        // Interval = 10,000 km
        // Next due = 30,000 km
        nextDueMileage = lastServiceMileage + interval;
      } else if (isNewVehicle) {
        // NEW vehicle with no service history yet.
        //
        // If a first mileage milestone is explicitly documented,
        // use it as the beginning of the recurring schedule.
        // Otherwise the recurring interval starts the cycle.
        if (rule.firstMileage != null) {
          if (currentMileage < rule.firstMileage!) {
            nextDueMileage = rule.firstMileage!;
          } else {
            nextDueMileage = _nextMileageCycle(
              currentMileage: currentMileage,
              interval: interval,
              firstMileage: rule.firstMileage,
            );
          }
        } else {
          nextDueMileage = _nextMileageCycle(
            currentMileage: currentMileage,
            interval: interval,
            firstMileage: null,
          );
        }
      } else {
        // EXISTING vehicle with unknown service history.
        //
        // IMPORTANT:
        // Do NOT infer a next mileage cycle from current mileage.
        nextDueMileage = null;
      }

      if (nextDueMileage != null) {
        final int mileageDifference = nextDueMileage - currentMileage;

        if (mileageDifference > 0) {
          remainingMileage = mileageDifference;
        } else if (mileageDifference == 0) {
          remainingMileage = 0;
        } else {
          remainingMileage = 0;
          graceUsedMileage = -mileageDifference;
        }
      }
    }

    // ============================================================
    // TIME CALCULATION
    // ============================================================

    DateTime? nextDueDate;
    int? remainingDays;
    int graceUsedDays = 0;

    if (rule.timeIntervalMonths != null && rule.timeIntervalMonths! > 0) {
      DateTime? timeBasis;

      if (lastServiceDate != null) {
        // Known service history.
        timeBasis = lastServiceDate;
      } else if (isNewVehicle && vehicleStartDate != null) {
        // NEW vehicle can use its documented start/purchase date.
        timeBasis = vehicleStartDate;
      }

      // EXISTING + unknown service date intentionally has no time basis.
      if (timeBasis != null) {
        nextDueDate = _addMonths(timeBasis, rule.timeIntervalMonths!);

        final int dayDifference = nextDueDate.difference(evaluationDate).inDays;

        if (dayDifference > 0) {
          remainingDays = dayDifference;
        } else if (dayDifference == 0) {
          // Exactly on the maintenance date.
          remainingDays = 0;
        } else {
          // Maintenance date has passed.
          remainingDays = 0;
          graceUsedDays = -dayDifference;
        }
      }
    }

    // ============================================================
    // DETERMINE AVAILABLE CONDITIONS
    // ============================================================

    final bool hasMileageCondition = nextDueMileage != null;

    final bool hasTimeCondition = nextDueDate != null;

    // No usable calculation basis.
    //
    // We do NOT invent a due mileage/date.
    //
    // Use the yellow warning stage until service history is known. This
    // keeps the four visible stages honest without fabricating a schedule.
    if (!hasMileageCondition && !hasTimeCondition) {
      return MaintenanceResult(
        rule: rule,
        status: MaintenanceStatus.dueSoon,
        nextDueMileage: null,
        remainingMileage: null,
        graceUsedMileage: 0,
        graceWindowMileage: graceWindowKm,
        nextDueDate: null,
        remainingDays: null,
        graceUsedDays: 0,
        graceWindowDays: graceWindowDays,
        hasCalculationBasis: false,
      );
    }

    // ============================================================
    // EXACT DUE CHECK
    // ============================================================

    final bool mileageDueExactly =
        hasMileageCondition && currentMileage == nextDueMileage!;

    final bool timeDueExactly =
        hasTimeCondition &&
        _isSameOrAfterDueDate(evaluationDate, nextDueDate!) &&
        graceUsedDays == 0;

    // ============================================================
    // OVERDUE CHECK
    // ============================================================

    final bool mileageOverdue =
        hasMileageCondition && currentMileage > nextDueMileage!;

    final bool timeOverdue =
        hasTimeCondition && evaluationDate.isAfter(nextDueDate!);

    // ============================================================
    // ============================================================
    // DUE NOW
    // ============================================================
    //
    // The exact maintenance threshold is Due Now. Once it is passed, the
    // item enters the final Grace Period stage.

    if (mileageDueExactly || timeDueExactly) {
      return MaintenanceResult(
        rule: rule,
        status: MaintenanceStatus.dueNow,
        nextDueMileage: nextDueMileage,
        remainingMileage: remainingMileage,
        graceUsedMileage: graceUsedMileage,
        graceWindowMileage: graceWindowKm,
        nextDueDate: nextDueDate,
        remainingDays: remainingDays,
        graceUsedDays: graceUsedDays,
        graceWindowDays: graceWindowDays,
      );
    }

    // ============================================================
    // GRACE PERIOD
    // ============================================================

    if (mileageOverdue || timeOverdue) {
      return MaintenanceResult(
        rule: rule,
        status: MaintenanceStatus.gracePeriod,
        nextDueMileage: nextDueMileage,
        remainingMileage: remainingMileage,
        graceUsedMileage: graceUsedMileage,
        graceWindowMileage: graceWindowKm,
        nextDueDate: nextDueDate,
        remainingDays: remainingDays,
        graceUsedDays: graceUsedDays,
        graceWindowDays: graceWindowDays,
      );
    }

    // ============================================================
    // DUE SOON
    // ============================================================

    final bool mileageDueSoon =
        hasMileageCondition &&
        remainingMileage != null &&
        remainingMileage! > 0 &&
        remainingMileage! <=
            _dueSoonMileageThreshold(
              rule.mileageInterval!,
              isInitial: rule.isInitial,
            );

    final bool timeDueSoon =
        hasTimeCondition &&
        remainingDays != null &&
        remainingDays! > 0 &&
        remainingDays! <= _dueSoonDaysThreshold(rule.timeIntervalMonths!);

    if (mileageDueSoon || timeDueSoon) {
      return MaintenanceResult(
        rule: rule,
        status: MaintenanceStatus.dueSoon,
        nextDueMileage: nextDueMileage,
        remainingMileage: remainingMileage,
        graceUsedMileage: 0,
        graceWindowMileage: graceWindowKm,
        nextDueDate: nextDueDate,
        remainingDays: remainingDays,
        graceUsedDays: 0,
        graceWindowDays: graceWindowDays,
      );
    }

    // ============================================================
    // ALL GOOD
    // ============================================================

    return MaintenanceResult(
      rule: rule,
      status: MaintenanceStatus.allGood,
      nextDueMileage: nextDueMileage,
      remainingMileage: remainingMileage,
      graceUsedMileage: 0,
      graceWindowMileage: graceWindowKm,
      nextDueDate: nextDueDate,
      remainingDays: remainingDays,
      graceUsedDays: 0,
      graceWindowDays: graceWindowDays,
    );
  }

  // ==============================================================
  // CALCULATE ALL RULES
  // ==============================================================

  /// Calculate ALL maintenance rules for a vehicle.
  ///
  /// [conditionResults] is keyed by the exact maintenanceItem string.
  ///
  /// Example:
  /// {
  ///   'Brake System': true,
  ///   'Tyres': false,
  ///   'Battery': null,
  /// }
  ///
  /// INITIAL rules skipped for an EXISTING vehicle are removed from the
  /// returned list because they are not applicable to that vehicle lifecycle.
  static List<MaintenanceResult> calculateAll({
    required List<MaintenanceRule> rules,
    required int currentMileage,
    int? lastServiceMileage,
    DateTime? lastServiceDate,
    DateTime? vehicleStartDate,
    DateTime? currentDate,
    String vehicleLifecycle = 'existing',
    Map<String, bool?>? conditionResults,
    int graceWindowKm = defaultGraceWindowKm,
    int graceWindowDays = defaultGraceWindowDays,
  }) {
    return rules
        .map(
          (rule) => calculate(
            rule: rule,
            currentMileage: currentMileage,
            lastServiceMileage: lastServiceMileage,
            lastServiceDate: lastServiceDate,
            vehicleStartDate: vehicleStartDate,
            currentDate: currentDate,
            vehicleLifecycle: vehicleLifecycle,
            conditionPassed: conditionResults?[rule.maintenanceItem],
            graceWindowKm: graceWindowKm,
            graceWindowDays: graceWindowDays,
          ),
        )
        .where((result) => result.isApplicable)
        .toList();
  }

  // ==============================================================
  // NEXT MILEAGE CYCLE
  // ==============================================================

  /// Finds the next scheduled mileage above the vehicle's current mileage.
  ///
  /// Example:
  /// current = 22,000
  /// interval = 10,000
  /// returns 30,000.
  ///
  /// If the vehicle is EXACTLY on a scheduled boundary, the current
  /// mileage itself is returned so calculate() can mark it DUE NOW.
  static int _nextMileageCycle({
    required int currentMileage,
    required int interval,
    int? firstMileage,
  }) {
    if (interval <= 0) {
      return currentMileage;
    }

    final int first = firstMileage ?? interval;

    if (currentMileage < first) {
      return first;
    }

    final int difference = currentMileage - first;

    // EXACT scheduled boundary.
    if (difference % interval == 0) {
      return currentMileage;
    }

    final int cyclesPassed = (difference ~/ interval) + 1;

    return first + (cyclesPassed * interval);
  }

  // ==============================================================
  // DATE HELPERS
  // ==============================================================

  /// Adds calendar months correctly.
  ///
  /// Example:
  /// 31 January + 1 month
  /// becomes the last valid day of February.
  /// Public calendar-month addition used by time simulation and calculation.
  /// The day is clamped when the target month is shorter (e.g. Jan 31 → Feb 28).
  static DateTime addCalendarMonths(DateTime date, int months) =>
      _addMonths(date, months);

  static DateTime _addMonths(DateTime date, int months) {
    final int targetMonth = date.month + months;

    final DateTime firstOfTargetMonth = DateTime(date.year, targetMonth, 1);

    final int lastDay = DateTime(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month + 1,
      0,
    ).day;

    final int safeDay = date.day > lastDay ? lastDay : date.day;

    return DateTime(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month,
      safeDay,
      date.hour,
      date.minute,
      date.second,
    );
  }

  /// Determines whether [date] has reached or passed [dueDate].
  static bool _isSameOrAfterDueDate(DateTime date, DateTime dueDate) {
    return date.isAtSameMomentAs(dueDate) || date.isAfter(dueDate);
  }

  // ==============================================================
  // DUE SOON THRESHOLDS
  // ==============================================================

  /// DLog's UI threshold for mileage-based Due Soon.
  ///
  /// This is NOT a manufacturer interval.
  ///
  /// Recurring rules retain the existing DLog 20% threshold with a
  /// 1,000-5,000 km clamp.
  ///
  /// Initial rules use the documented first milestone more directly:
  /// 20% of the interval, with a smaller 100 km minimum. This prevents
  /// a brand-new vehicle at 0 km from immediately appearing DUE SOON
  /// for a 1,000 km initial inspection.
  static int _dueSoonMileageThreshold(int interval, {bool isInitial = false}) {
    final int threshold = (interval * 0.20).round();

    if (isInitial) {
      return threshold.clamp(100, 1000);
    }

    return threshold.clamp(1000, 5000);
  }

  /// DLog's UI threshold for time-based Due Soon.
  ///
  /// Approximately 20% of the interval, with a minimum of 7 days
  /// and maximum of 30 days.
  static int _dueSoonDaysThreshold(int intervalMonths) {
    final int approximateDays = (intervalMonths * 30 * 0.20).round();

    return approximateDays.clamp(7, 30);
  }

  // ==============================================================
  // FILTER HELPERS
  // ==============================================================

  /// Returns only Grace Period items.
  static List<MaintenanceResult> gracePeriodItems(
    List<MaintenanceResult> results,
  ) {
    return results.where((result) => result.isGracePeriod).toList();
  }

  /// Returns only Due Now items.
  static List<MaintenanceResult> dueNowItems(List<MaintenanceResult> results) {
    return results.where((result) => result.isDueNow).toList();
  }

  // ==============================================================
  // COUNT HELPERS
  // ==============================================================

  /// Count results belonging to a particular status.
  static int countStatus(
    List<MaintenanceResult> results,
    MaintenanceStatus status,
  ) {
    if (status == MaintenanceStatus.allGood) {
      return results.where((result) => result.isAllGood).length;
    }

    return results
        .where((result) => result.isApplicable && result.status == status)
        .length;
  }

  /// Count All Good maintenance items that have actually been
  /// calculated/confirmed.
  static int allGoodCount(List<MaintenanceResult> results) {
    return results.where((result) => result.isAllGood).length;
  }

  /// Count Due Soon maintenance items.
  static int dueSoonCount(List<MaintenanceResult> results) {
    return countStatus(results, MaintenanceStatus.dueSoon);
  }

  /// Count Due Now maintenance items.
  static int dueNowCount(List<MaintenanceResult> results) {
    return countStatus(results, MaintenanceStatus.dueNow);
  }

  /// Count Grace Period maintenance items.
  static int gracePeriodCount(List<MaintenanceResult> results) {
    return countStatus(results, MaintenanceStatus.gracePeriod);
  }
}
