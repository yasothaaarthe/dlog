/// Defines what kind of maintenance action DLog recommends.
enum MaintenanceAction { replace, inspect, clean, rotate, check, adjust }

/// Defines the lifecycle stage of a maintenance rule.
///
/// INITIAL
/// - Applies to an initial/new-vehicle maintenance event.
/// - Example: a documented 1,000 km initial inspection.
///
/// RECURRING
/// - Applies repeatedly according to a mileage and/or time interval.
/// - Example: engine oil every X km / X months.
///
/// CONDITION_BASED
/// - Does not have a universal fixed replacement interval.
/// - Example: brake pads, tyres and battery.
///
/// The stage belongs to the RULE, not the calculator.
/// This allows each vehicle model/generation to define its own
/// maintenance behaviour.
enum MaintenanceStage { initial, recurring, conditionBased }

/// The four maintenance states displayed by DLog.
enum MaintenanceStatus { allGood, dueSoon, dueNow, gracePeriod }

/// Reminder cadence for a condition inspection.
///
/// These values describe DLog's configurable prototype check reminders. They
/// are not manufacturer replacement intervals and do not imply a component
/// should be replaced at that age or mileage.
class ConditionInspectionPolicy {
  const ConditionInspectionPolicy({
    required this.checklistItems,
    required this.checkIntervalDays,
    required this.dueSoonThresholdDays,
    required this.gracePeriodDays,
    this.sourceLabel = 'DLog prototype inspection reminder',
  }) : assert(checkIntervalDays > 0),
       assert(dueSoonThresholdDays > 0),
       assert(dueSoonThresholdDays < checkIntervalDays),
       assert(gracePeriodDays > 0);

  final List<String> checklistItems;
  final int checkIntervalDays;
  final int dueSoonThresholdDays;
  final int gracePeriodDays;
  final String sourceLabel;
}

/// Source categories for engine-oil product specifications, when documented.
enum EngineOilSourceType {
  manufacturer('Manufacturer'),
  ownerServiceManual('Owner-Service Manual'),
  secondaryReference('Secondary Reference'),
  prototype('Prototype');

  const EngineOilSourceType(this.label);

  final String label;
}

/// Evidence status of an engine-oil option from the supplied matrix.
enum EngineOilMetadataStatus {
  manufacturer('Manufacturer data'),
  reference('General product reference'),
  secondaryHistorical('Secondary / historical'),
  prototypeOnly('Prototype only — not a manufacturer recommendation'),
  notProvided('Not provided in the supplied matrix');

  const EngineOilMetadataStatus(this.label);

  final String label;
}

/// Confidence in the oil specification's evidence, when one is available.
enum EngineOilMetadataConfidence {
  high('High'),
  medium('Medium'),
  low('Low');

  const EngineOilMetadataConfidence(this.label);

  final String label;
}

/// One informational engine-oil option from the vehicle-specific matrix.
///
/// These fields describe oil specification evidence only. They are not read
/// by maintenance calculations and do not alter the rule's service intervals.
class EngineOilMetadata {
  const EngineOilMetadata({
    this.oilType,
    this.viscosity,
    this.apiSpecification,
    this.sourceId,
    this.sourceName,
    this.sourceUrl,
    this.sourceReference,
    this.sourceType,
    this.confidence,
    this.statusNote,
    this.applicabilityNote,
    this.status = EngineOilMetadataStatus.notProvided,
  });

  /// Retains the workbook's product/formulation label verbatim.
  final String? oilType;
  final String? viscosity;
  final String? apiSpecification;
  final String? sourceId;
  final String? sourceName;
  final String? sourceUrl;
  final String? sourceReference;
  final EngineOilSourceType? sourceType;
  final EngineOilMetadataConfidence? confidence;
  final String? statusNote;
  final String? applicabilityNote;
  final EngineOilMetadataStatus status;
}

/// A single vehicle-specific maintenance rule.
///
/// IMPORTANT:
/// This model stores the maintenance DATA.
///
/// It does NOT contain calculation logic.
///
/// The MaintenanceCalculator reads these values and determines
/// whether the maintenance item is:
/// - All Good
/// - Due Soon
/// - Due Now
/// - Grace Period
class MaintenanceRule {
  /// Identifies the vehicle generation/model rule set.
  ///
  /// Examples:
  /// - AXIA_2019
  /// - AXIA_2023_1.0_DCVT
  /// - MYVI_G3_2017
  /// - X50_2020
  /// - SAGA_2025
  final String ruleGroupId;

  /// Human-readable maintenance item.
  ///
  /// Examples:
  /// - Engine Oil
  /// - Oil Filter
  /// - Brake System
  /// - Tyre Rotation
  /// - Battery
  /// - Coolant
  /// - Engine Air Filter
  /// - Transmission Fluid
  final String maintenanceItem;

  /// What DLog recommends doing.
  final MaintenanceAction action;

  /// Lifecycle stage of this maintenance rule.
  ///
  /// Defaults to recurring so existing rules continue
  /// to behave correctly until we explicitly classify them.
  final MaintenanceStage stage;

  /// Mileage interval for recurring maintenance.
  ///
  /// Example:
  /// 10000 = every 10,000 km.
  ///
  /// This must come from the vehicle-specific rule.
  final int? mileageInterval;

  /// Time interval for recurring maintenance.
  ///
  /// Example:
  /// 6 = every 6 months.
  ///
  /// This must come from the vehicle-specific rule.
  final int? timeIntervalMonths;

  /// First mileage milestone for this rule.
  ///
  /// Example:
  /// 1000 = initial inspection at 1,000 km.
  ///
  /// This is NOT automatically assumed for every vehicle.
  final int? firstMileage;

  /// Describes the maintenance condition or applicability.
  ///
  /// Examples:
  /// - scheduled
  /// - inspect_condition
  /// - replace_if_worn
  /// - manufacturer_recommended
  final String condition;

  /// Source type.
  ///
  /// Examples:
  /// - manufacturer_manual
  /// - manufacturer_service_booklet
  /// - dlog_recommendation
  final String source;

  /// Human-readable source reference.
  final String? sourceReference;

  /// Source URL, when available.
  final String? sourceUrl;

  /// Checklist and date thresholds for condition-based inspection rules.
  /// Null for mileage/time based rules.
  final ConditionInspectionPolicy? conditionInspectionPolicy;

  /// Informational engine-oil options, when documented.
  /// These options are not used to calculate maintenance status or intervals.
  final List<EngineOilMetadata> engineOilOptions;

  const MaintenanceRule({
    required this.ruleGroupId,
    required this.maintenanceItem,
    required this.action,

    /// Existing rules remain recurring unless explicitly
    /// classified as initial or condition-based.
    this.stage = MaintenanceStage.recurring,

    this.mileageInterval,
    this.timeIntervalMonths,
    this.firstMileage,

    required this.condition,
    required this.source,
    this.sourceReference,
    this.sourceUrl,
    this.conditionInspectionPolicy,
    this.engineOilOptions = const [],
  });

  MaintenanceRule copyWith({
    ConditionInspectionPolicy? conditionInspectionPolicy,
    List<EngineOilMetadata>? engineOilOptions,
  }) {
    return MaintenanceRule(
      ruleGroupId: ruleGroupId,
      maintenanceItem: maintenanceItem,
      action: action,
      stage: stage,
      mileageInterval: mileageInterval,
      timeIntervalMonths: timeIntervalMonths,
      firstMileage: firstMileage,
      condition: condition,
      source: source,
      sourceReference: sourceReference,
      sourceUrl: sourceUrl,
      conditionInspectionPolicy:
          conditionInspectionPolicy ?? this.conditionInspectionPolicy,
      engineOilOptions: engineOilOptions ?? this.engineOilOptions,
    );
  }

  /// Returns true when this is an initial/new-vehicle rule.
  bool get isInitial => stage == MaintenanceStage.initial;

  /// Returns true when this is a recurring scheduled rule.
  bool get isRecurring => stage == MaintenanceStage.recurring;

  /// Returns true when this rule is condition based.
  bool get isConditionBased => stage == MaintenanceStage.conditionBased;

  /// Creates a readable description of the rule type.
  String get stageLabel {
    switch (stage) {
      case MaintenanceStage.initial:
        return 'Initial';

      case MaintenanceStage.recurring:
        return 'Recurring';

      case MaintenanceStage.conditionBased:
        return 'Condition Based';
    }
  }
}
