import '../models/maintenance_rule.dart';

/// ============================================================
/// DLOG MAINTENANCE RULE DATABASE
/// ============================================================
///
/// IMPORTANT ARCHITECTURE RULE:
///
/// This file contains VEHICLE-SPECIFIC MAINTENANCE DATA.
///
/// MaintenanceCalculator does NOT know:
/// - Axia intervals
/// - Myvi intervals
/// - X50 intervals
/// - Saga intervals
///
/// Instead:
///
/// Vehicle
///   ↓
/// ruleGroupId
///   ↓
/// MaintenanceRules.forRuleGroup()
///   ↓
/// vehicle-specific MaintenanceRule list
///   ↓
/// MaintenanceCalculator
///
/// This keeps manufacturer/model/generation data separate from
/// calculation logic.
///
/// DATA POLICY:
/// Manufacturer-backed rules retain their source references.
/// Prototype-matrix inspection/replacement values are explicitly
/// labeled as DLog prototype data and are not manufacturer-certified.
///
/// Condition-based replacement remains distinct from a scheduled
/// inspection cadence, even when a prototype cadence is supplied.
///
/// ============================================================

class MaintenanceRules {
  MaintenanceRules._();

  // ============================================================
  // RULE GROUP IDS
  // ============================================================

  static const String myviG2_2011RuleGroup = 'MYVI_G2_2011';

  static const String myviG2Fl2015RuleGroup = 'MYVI_G2_FL_2015';

  static const String myviG3_2017RuleGroup = 'MYVI_G3_2017';

  static const String myviG3Fl2022RuleGroup = 'MYVI_G3_FL_2022';

  static const String axiaG1RuleGroup = 'AXIA_G1';

  static const String axia2019RuleGroup = 'AXIA_2019';

  static const String axia2023DcvTtRuleGroup = 'AXIA_2023_1.0_DCVT';

  static const String x50_2020RuleGroup = 'X50_2020';

  static const String x50_2024RuleGroup = 'X50_2024';

  static const String x50_2025RuleGroup = 'X50_2025_1.5TD_7DCT';

  static const String saga2022RuleGroup = 'SAGA_2022';

  static const String saga2025RuleGroup = 'SAGA_2025';

  // ============================================================
  // COMMON SOURCE LABELS
  // ============================================================

  static const String peroduaManual = 'manufacturer_manual';

  static const String protonServiceBooklet = 'manufacturer_service_booklet';

  static const String dlogRecommendation = 'dlog_recommendation';

  static const String dlogPrototypeMatrix = 'dlog_prototype_matrix';

  static const String _peroduaOilSourceName =
      'Perodua Genuine Oil – Engine Care & Protection';
  static const String _peroduaOilSourceUrl =
      'https://www.perodua.com.my/after-sales/pgo';
  static const String _protonX50OilManualName = 'Proton X50 Owner Manual';
  static const String _protonX50OilManualUrl =
      'https://cms-assets.proton.com/proton-cms-blob/media/hqrpllb5/2020_x50_owners_manual.pdf';

  static const List<EngineOilMetadata> _axia2023OilOptions = [
    EngineOilMetadata(
      oilType: 'Fully Synthetic',
      viscosity: '0W-20',
      apiSpecification: 'API SN',
      sourceId: 'SRC-01',
      sourceName: _peroduaOilSourceName,
      sourceUrl: _peroduaOilSourceUrl,
      sourceType: EngineOilSourceType.manufacturer,
      confidence: EngineOilMetadataConfidence.medium,
      status: EngineOilMetadataStatus.manufacturer,
      statusNote: 'MANUFACTURER / PRODUCT DATA',
      applicabilityNote:
          'Perodua product-range information; confirm the grade for this exact vehicle in its owner manual.',
    ),
    EngineOilMetadata(
      oilType: 'Semi-Synthetic',
      viscosity: '5W-30',
      apiSpecification: 'API SM',
      sourceId: 'SRC-01',
      sourceName: _peroduaOilSourceName,
      sourceUrl: _peroduaOilSourceUrl,
      sourceType: EngineOilSourceType.manufacturer,
      confidence: EngineOilMetadataConfidence.medium,
      status: EngineOilMetadataStatus.manufacturer,
      statusNote: 'MANUFACTURER / PRODUCT DATA',
      applicabilityNote:
          'Perodua product-range information; confirm the grade for this exact vehicle in its owner manual.',
    ),
    EngineOilMetadata(
      oilType: 'Mineral',
      viscosity: '10W-30',
      apiSpecification: 'API SL',
      sourceId: 'SRC-01',
      sourceName: _peroduaOilSourceName,
      sourceUrl: _peroduaOilSourceUrl,
      sourceType: EngineOilSourceType.manufacturer,
      confidence: EngineOilMetadataConfidence.medium,
      status: EngineOilMetadataStatus.manufacturer,
      statusNote: 'MANUFACTURER / PRODUCT DATA',
      applicabilityNote:
          'Perodua product-range information; confirm the grade for this exact vehicle in its owner manual.',
    ),
  ];

  static const List<EngineOilMetadata> _myviG2OilOptions = [
    EngineOilMetadata(
      oilType: 'Fully Synthetic',
      viscosity: '0W-20',
      apiSpecification: 'API SN or higher',
      sourceId: 'SRC-01',
      sourceName: _peroduaOilSourceName,
      sourceUrl: _peroduaOilSourceUrl,
      sourceType: EngineOilSourceType.manufacturer,
      confidence: EngineOilMetadataConfidence.low,
      status: EngineOilMetadataStatus.reference,
      statusNote: 'REFERENCE / GENERAL PERODUA OIL',
      applicabilityNote:
          'General Perodua product reference; this is not a variant-specific viscosity recommendation.',
    ),
    EngineOilMetadata(
      oilType: 'Semi-Synthetic',
      viscosity: '5W-30',
      apiSpecification: 'API SM',
      sourceId: 'SRC-01',
      sourceName: _peroduaOilSourceName,
      sourceUrl: _peroduaOilSourceUrl,
      sourceType: EngineOilSourceType.manufacturer,
      confidence: EngineOilMetadataConfidence.low,
      status: EngineOilMetadataStatus.reference,
      statusNote: 'REFERENCE / GENERAL PERODUA OIL',
      applicabilityNote:
          'General Perodua product reference; this is not a variant-specific viscosity recommendation.',
    ),
    EngineOilMetadata(
      oilType: 'Mineral',
      viscosity: '10W-30',
      apiSpecification: 'API SL',
      sourceId: 'SRC-01',
      sourceName: _peroduaOilSourceName,
      sourceUrl: _peroduaOilSourceUrl,
      sourceType: EngineOilSourceType.manufacturer,
      confidence: EngineOilMetadataConfidence.low,
      status: EngineOilMetadataStatus.reference,
      statusNote: 'REFERENCE / GENERAL PERODUA OIL',
      applicabilityNote:
          'General Perodua product reference; this is not a variant-specific viscosity recommendation.',
    ),
  ];

  static const List<EngineOilMetadata> _myviG2FlOilOptions = [
    EngineOilMetadata(
      oilType: 'Fully Synthetic',
      viscosity: '0W-20',
      apiSpecification: 'API SN or higher',
      sourceId: 'SRC-01',
      sourceName: _peroduaOilSourceName,
      sourceUrl: _peroduaOilSourceUrl,
      sourceType: EngineOilSourceType.manufacturer,
      confidence: EngineOilMetadataConfidence.low,
      status: EngineOilMetadataStatus.reference,
      statusNote: 'REFERENCE / GENERAL PERODUA OIL',
      applicabilityNote:
          'Exact 2015–2017 owner-manual specification was not fully extracted; this is a general product reference.',
    ),
    EngineOilMetadata(
      oilType: 'Semi-Synthetic',
      viscosity: '5W-30',
      apiSpecification: 'API SM',
      sourceId: 'SRC-01',
      sourceName: _peroduaOilSourceName,
      sourceUrl: _peroduaOilSourceUrl,
      sourceType: EngineOilSourceType.manufacturer,
      confidence: EngineOilMetadataConfidence.low,
      status: EngineOilMetadataStatus.reference,
      statusNote: 'REFERENCE / GENERAL PERODUA OIL',
      applicabilityNote:
          'Exact 2015–2017 owner-manual specification was not fully extracted; this is a general product reference.',
    ),
    EngineOilMetadata(
      oilType: 'Mineral',
      viscosity: '10W-30',
      apiSpecification: 'API SL',
      sourceId: 'SRC-01',
      sourceName: _peroduaOilSourceName,
      sourceUrl: _peroduaOilSourceUrl,
      sourceType: EngineOilSourceType.manufacturer,
      confidence: EngineOilMetadataConfidence.low,
      status: EngineOilMetadataStatus.reference,
      statusNote: 'REFERENCE / GENERAL PERODUA OIL',
      applicabilityNote:
          'Exact 2015–2017 owner-manual specification was not fully extracted; this is a general product reference.',
    ),
  ];

  static const List<EngineOilMetadata> _x50_2024OilOptions = [
    EngineOilMetadata(
      oilType: 'Fully Synthetic',
      viscosity: '0W-20',
      apiSpecification: 'API SN',
      sourceId: 'SRC-04',
      sourceName: _protonX50OilManualName,
      sourceUrl: _protonX50OilManualUrl,
      sourceReference:
          'Owner manual lists Super Fully Synthetic 0W-20 API SN for the X50 1.5T / 1.5TD family.',
      sourceType: EngineOilSourceType.ownerServiceManual,
      confidence: EngineOilMetadataConfidence.high,
      status: EngineOilMetadataStatus.manufacturer,
      statusNote: 'MANUFACTURER / OWNER MANUAL',
    ),
    EngineOilMetadata(
      oilType: 'PGO 5W-30',
      viscosity: '5W-30',
      apiSpecification: 'API SP ILSAC GF-6A',
      sourceId: 'SRC-04',
      sourceName: _protonX50OilManualName,
      sourceUrl: _protonX50OilManualUrl,
      sourceReference:
          'Owner manual lists PGO 5W-30 API SP ILSAC GF-6A for the X50 1.5T / 1.5TD family.',
      sourceType: EngineOilSourceType.ownerServiceManual,
      confidence: EngineOilMetadataConfidence.high,
      status: EngineOilMetadataStatus.manufacturer,
      statusNote: 'MANUFACTURER / OWNER MANUAL',
    ),
    EngineOilMetadata(
      oilType: 'Semi-Synthetic',
      sourceId: 'SRC-04',
      sourceName: _protonX50OilManualName,
      sourceUrl: _protonX50OilManualUrl,
      sourceReference:
          'SRC-04 is cited only to indicate that Proton does not specify this grade; prototype display only.',
      sourceType: EngineOilSourceType.prototype,
      confidence: EngineOilMetadataConfidence.low,
      status: EngineOilMetadataStatus.prototypeOnly,
      statusNote: 'PROTOTYPE ONLY — DO NOT TREAT AS PROTON RECOMMENDATION',
    ),
    EngineOilMetadata(
      oilType: 'Mineral',
      sourceId: 'SRC-04',
      sourceName: _protonX50OilManualName,
      sourceUrl: _protonX50OilManualUrl,
      sourceReference:
          'SRC-04 is cited only to indicate that Proton does not specify this grade; prototype display only.',
      sourceType: EngineOilSourceType.prototype,
      confidence: EngineOilMetadataConfidence.low,
      status: EngineOilMetadataStatus.prototypeOnly,
      statusNote: 'PROTOTYPE ONLY — DO NOT TREAT AS PROTON RECOMMENDATION',
    ),
  ];

  /// DLog prototype check cadences. These are reminder settings for this
  /// prototype, not manufacturer service or replacement intervals.
  static const Map<String, ConditionInspectionPolicy>
  _conditionInspectionPolicies = {
    'battery': ConditionInspectionPolicy(
      checklistItems: [
        'Check starting performance',
        'Check battery terminals',
        'Check warning signs',
      ],
      checkIntervalDays: 30,
      dueSoonThresholdDays: 7,
      gracePeriodDays: 7,
    ),
    'tyres': ConditionInspectionPolicy(
      checklistItems: [
        'Check tyre tread',
        'Check cracks/damage',
        'Check tyre pressure',
        'Check uneven wear',
      ],
      checkIntervalDays: 14,
      dueSoonThresholdDays: 3,
      gracePeriodDays: 3,
    ),
    'brake system': ConditionInspectionPolicy(
      checklistItems: [
        'Check brake feel',
        'Check unusual noise',
        'Check brake warning light',
        'Check visible wear',
      ],
      checkIntervalDays: 30,
      dueSoonThresholdDays: 7,
      gracePeriodDays: 7,
    ),
    'engine': ConditionInspectionPolicy(
      checklistItems: [
        'Check leaks',
        'Check unusual sounds',
        'Check warning indicators',
      ],
      checkIntervalDays: 30,
      dueSoonThresholdDays: 7,
      gracePeriodDays: 7,
    ),
    'coolant': ConditionInspectionPolicy(
      checklistItems: [
        'Check coolant level',
        'Check for visible leaks',
        'Check for discolouration or contamination',
      ],
      checkIntervalDays: 30,
      dueSoonThresholdDays: 7,
      gracePeriodDays: 7,
    ),
    'engine air filter': ConditionInspectionPolicy(
      checklistItems: [
        'Check filter condition',
        'Check for heavy dust or blockage',
        'Check filter housing and seal',
      ],
      checkIntervalDays: 45,
      dueSoonThresholdDays: 10,
      gracePeriodDays: 7,
    ),
    'transmission fluid': ConditionInspectionPolicy(
      checklistItems: [
        'Check for visible leaks',
        'Listen for unusual transmission noise',
        'Check for abnormal shifting or warning signs',
      ],
      checkIntervalDays: 30,
      dueSoonThresholdDays: 7,
      gracePeriodDays: 7,
    ),
  };

  // ============================================================
  // AXIA 2019
  // ============================================================
  //
  // Rule group:
  // AXIA_2019
  //
  // Applies to:
  // Axia 2019-2022 rule family.
  //
  // Source:
  // 2019 Axia owner manual / maintenance schedule.
  //
  // The 2019 manual identifies the vehicle as 1KR-VE and documents
  // the scheduled maintenance table separately from the 2023+
  // D-CVT Axia.
  //
  // ============================================================

  static const List<MaintenanceRule> axia2019 = [
    // ----------------------------------------------------------
    // INITIAL
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Initial Inspection',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.initial,
      firstMileage: 1000,
      condition: 'new_vehicle_inspection',
      source: peroduaManual,
      sourceReference:
          'Axia 2019 Owner Manual - scheduled/new vehicle inspection',
    ),

    // ----------------------------------------------------------
    // ENGINE OIL
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Engine Oil',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: 'Axia 2019 Owner Manual - scheduled maintenance',
    ),

    // ----------------------------------------------------------
    // OIL FILTER
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Engine Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: 'Axia 2019 Owner Manual - engine oil filter',
    ),

    // ----------------------------------------------------------
    // ENGINE AIR FILTER
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Engine Air Filter',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 20000,
      condition: 'inspect_clean_replace_if_required',
      source: peroduaManual,
      sourceReference: 'Axia 2019 Owner Manual - air cleaner element',
    ),

    // ----------------------------------------------------------
    // BRAKE SYSTEM
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_wear_damage_leakage',
      source: peroduaManual,
      sourceReference: 'Axia 2019 Owner Manual - brake system inspection',
    ),

    // ----------------------------------------------------------
    // BRAKE FLUID
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Brake Fluid',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 40000,
      timeIntervalMonths: 24,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: 'Axia 2019 Owner Manual - brake fluid maintenance',
    ),

    // ----------------------------------------------------------
    // TYRES
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_pressure_wear_damage',
      source: peroduaManual,
      sourceReference: 'Axia 2019 Owner Manual - tyres and inflation pressure',
    ),

    // ----------------------------------------------------------
    // TYRE ROTATION
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Tyre Rotation',
      action: MaintenanceAction.rotate,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: 'Axia 2019 Owner Manual - tyre rotation every 10,000 km',
    ),

    // ----------------------------------------------------------
    // BATTERY
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_condition',
      source: peroduaManual,
      sourceReference: 'Axia 2019 Owner Manual - battery condition',
    ),

    // ----------------------------------------------------------
    // COOLANT
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Coolant',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_level_condition',
      source: peroduaManual,
      sourceReference: 'Axia 2019 Owner Manual - cooling system',
    ),

    // ----------------------------------------------------------
    // TRANSMISSION FLUID
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2019RuleGroup,
      maintenanceItem: 'Automatic Transmission Fluid',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 40000,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: 'Axia 2019 Owner Manual - automatic transmission fluid',
    ),
  ];

  // ============================================================
  // AXIA 2023+ D-CVT
  // ============================================================
  //
  // Rule group:
  // AXIA_2023_1.0_DCVT
  //
  // This is the strongest Axia rule group in the current
  // DLog research set because the 2023+ owner manual provides
  // the exact maintenance schedule.
  //
  // ============================================================

  static const List<MaintenanceRule> axia2023 = [
    // ----------------------------------------------------------
    // INITIAL INSPECTION
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2023DcvTtRuleGroup,
      maintenanceItem: 'Initial Inspection',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.initial,
      firstMileage: 1000,
      condition: 'new_vehicle_inspection',
      source: peroduaManual,
      sourceReference:
          '2023+ Axia Owner Manual - new vehicle check at 1,000 km',
    ),

    // ----------------------------------------------------------
    // ENGINE OIL
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2023DcvTtRuleGroup,
      maintenanceItem: 'Engine Oil',
      engineOilOptions: _axia2023OilOptions,
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: '2023+ Axia Owner Manual - scheduled maintenance',
    ),

    // ----------------------------------------------------------
    // OIL FILTER
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2023DcvTtRuleGroup,
      maintenanceItem: 'Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: '2023+ Axia Owner Manual - engine oil/filter service',
    ),

    // ----------------------------------------------------------
    // ENGINE AIR FILTER
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2023DcvTtRuleGroup,
      maintenanceItem: 'Engine Air Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 40000,
      timeIntervalMonths: 24,
      condition: 'scheduled_replacement',
      source: peroduaManual,
      sourceReference:
          '2023+ Axia Owner Manual - air cleaner replacement schedule',
    ),

    // ----------------------------------------------------------
    // BRAKE SYSTEM
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2023DcvTtRuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'prototype_fixed_inspection',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE FIXED INSPECTION — Axia 2023+ matrix: Brake System; replacement remains condition-based.',
    ),

    // ----------------------------------------------------------
    // TYRES
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2023DcvTtRuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'prototype_fixed_inspection',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE FIXED INSPECTION — Axia 2023+ matrix: Tyres; replacement remains condition-based.',
    ),

    // ----------------------------------------------------------
    // TYRE ROTATION
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2023DcvTtRuleGroup,
      maintenanceItem: 'Tyre Rotation',
      action: MaintenanceAction.rotate,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference:
          '2023+ Axia Owner Manual - tyre rotation every 10,000 km',
    ),

    // ----------------------------------------------------------
    // BATTERY
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2023DcvTtRuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'prototype_fixed_inspection',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE FIXED INSPECTION — Axia 2023+ matrix: Battery; replacement remains condition-based.',
    ),

    // ----------------------------------------------------------
    // COOLANT
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2023DcvTtRuleGroup,
      maintenanceItem: 'Coolant',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 160000,
      timeIntervalMonths: 96,
      condition: 'first_replacement_then_repeat',
      source: peroduaManual,
      sourceReference: '2023+ Axia Owner Manual - first coolant replacement',
    ),

    // ----------------------------------------------------------
    // TRANSMISSION FLUID
    // ----------------------------------------------------------
    MaintenanceRule(
      ruleGroupId: axia2023DcvTtRuleGroup,
      maintenanceItem: 'Transmission Fluid',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 100000,
      timeIntervalMonths: 60,
      condition: 'normal_usage',
      source: peroduaManual,
      sourceReference: '2023+ Axia Owner Manual - D-CVT fluid',
    ),
  ];

  // ============================================================
  // MYVI — SECOND GENERATION / EARLY
  // ============================================================
  //
  // Current evidence supports the regular engine-oil service
  // cadence and initial inspection/service milestone.
  //
  // We intentionally do NOT invent detailed replacement
  // intervals for every component until the exact generation/
  // variant table is fully consolidated.
  //
  // ============================================================

  static const List<MaintenanceRule> myviG2_2011 = [
    MaintenanceRule(
      ruleGroupId: myviG2_2011RuleGroup,
      maintenanceItem: 'Initial Inspection',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.initial,
      firstMileage: 1000,
      condition: 'new_vehicle_inspection',
      source: peroduaManual,
      sourceReference:
          'Myvi second-generation service schedule - initial inspection',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2_2011RuleGroup,
      maintenanceItem: 'Engine Oil',
      engineOilOptions: _myviG2OilOptions,
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference:
          'Myvi service schedule - engine oil every 10,000 km / 6 months',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2_2011RuleGroup,
      maintenanceItem: 'Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: 'Myvi scheduled service - oil filter',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2_2011RuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'prototype_fixed_inspection',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE FIXED INSPECTION — Myvi Gen 2 matrix: Brake System; replacement remains condition-based.',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2_2011RuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'prototype_fixed_inspection',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE FIXED INSPECTION — Myvi Gen 2 matrix: Tyres; replacement remains condition-based.',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2_2011RuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'prototype_fixed_inspection',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE FIXED INSPECTION — Myvi Gen 2 matrix: Battery; replacement remains condition-based.',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2_2011RuleGroup,
      maintenanceItem: 'Coolant',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 40000,
      timeIntervalMonths: 24,
      condition: 'prototype_replacement_interval',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE — Myvi Gen 2 matrix: coolant replacement at 40,000 km / 24 months.',
    ),
  ];

  // ============================================================
  // MYVI 2015 FACELIFT
  // ============================================================

  static const List<MaintenanceRule> myviG2Fl2015 = [
    MaintenanceRule(
      ruleGroupId: myviG2Fl2015RuleGroup,
      maintenanceItem: 'Initial Inspection',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.initial,
      firstMileage: 1000,
      condition: 'new_vehicle_inspection',
      source: peroduaManual,
      sourceReference: 'Myvi service schedule - initial inspection',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2Fl2015RuleGroup,
      maintenanceItem: 'Engine Oil',
      engineOilOptions: _myviG2FlOilOptions,
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE — Myvi Gen 2 facelift matrix: Engine Oil, 10,000 km / 6 months.',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2Fl2015RuleGroup,
      maintenanceItem: 'Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE — Myvi Gen 2 facelift matrix: Oil Filter, 10,000 km / 6 months.',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2Fl2015RuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'prototype_fixed_inspection',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE FIXED INSPECTION — Myvi Gen 2 facelift matrix: Brake System; replacement remains condition-based.',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2Fl2015RuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'prototype_fixed_inspection',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE FIXED INSPECTION — Myvi Gen 2 facelift matrix: Tyres; replacement remains condition-based.',
    ),

    MaintenanceRule(
      ruleGroupId: myviG2Fl2015RuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'prototype_fixed_inspection',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE FIXED INSPECTION — Myvi Gen 2 facelift matrix: Battery; replacement remains condition-based.',
    ),
  ];

  // ============================================================
  // MYVI 2017+
  // ============================================================

  static const List<MaintenanceRule> myviG3_2017 = [
    MaintenanceRule(
      ruleGroupId: myviG3_2017RuleGroup,
      maintenanceItem: 'Initial Inspection',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.initial,
      firstMileage: 1000,
      condition: 'new_vehicle_inspection',
      source: peroduaManual,
      sourceReference: 'Myvi service schedule - 1,000 km initial inspection',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3_2017RuleGroup,
      maintenanceItem: 'Engine Oil',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference:
          'Myvi 2017 service booklet - engine oil every 10,000 km / 6 months',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3_2017RuleGroup,
      maintenanceItem: 'Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: 'Myvi 2017 scheduled maintenance',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3_2017RuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_wear_damage',
      source: peroduaManual,
      sourceReference: 'Myvi maintenance schedule - brake system',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3_2017RuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_pressure_wear_damage',
      source: peroduaManual,
      sourceReference: 'Myvi maintenance schedule - tyres',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3_2017RuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_condition',
      source: peroduaManual,
      sourceReference: 'Myvi maintenance schedule - battery',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3_2017RuleGroup,
      maintenanceItem: 'Coolant',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_condition',
      source: peroduaManual,
      sourceReference: 'Myvi maintenance schedule - coolant',
    ),
  ];

  // ============================================================
  // MYVI 2022+
  // ============================================================

  static const List<MaintenanceRule> myviG3Fl2022 = [
    MaintenanceRule(
      ruleGroupId: myviG3Fl2022RuleGroup,
      maintenanceItem: 'Initial Inspection',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.initial,
      firstMileage: 1000,
      condition: 'new_vehicle_inspection',
      source: peroduaManual,
      sourceReference: 'Myvi service schedule - initial inspection',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3Fl2022RuleGroup,
      maintenanceItem: 'Engine Oil',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: 'Perodua scheduled maintenance - engine oil',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3Fl2022RuleGroup,
      maintenanceItem: 'Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference: 'Perodua scheduled maintenance - oil filter',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3Fl2022RuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_wear_damage',
      source: peroduaManual,
      sourceReference: 'Perodua maintenance schedule - brake system',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3Fl2022RuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_pressure_wear_damage',
      source: peroduaManual,
      sourceReference: 'Perodua maintenance schedule - tyres',
    ),

    MaintenanceRule(
      ruleGroupId: myviG3Fl2022RuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_condition',
      source: peroduaManual,
      sourceReference: 'Perodua maintenance schedule - battery',
    ),
  ];

  // ============================================================
  // AXIA FIRST GENERATION
  // ============================================================
  //
  // The exact maintenance table for older Axia generations is
  // still pending final consolidation. Unverified demo rows added
  // below are clearly labeled as DLog prototype intervals.
  //
  // ============================================================

  static const List<MaintenanceRule> axiaG1 = [
    MaintenanceRule(
      ruleGroupId: axiaG1RuleGroup,
      maintenanceItem: 'Engine Oil',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: peroduaManual,
      sourceReference:
          'Legacy Axia maintenance cadence - verification retained by generation',
    ),

    MaintenanceRule(
      ruleGroupId: axiaG1RuleGroup,
      maintenanceItem: 'Engine Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'prototype_replacement_interval',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE ONLY — DLog demo interval for legacy Axia: replace with engine oil at 10,000 km / 6 months. Verify against the exact vehicle manual before real servicing.',
    ),

    MaintenanceRule(
      ruleGroupId: axiaG1RuleGroup,
      maintenanceItem: 'Engine Air Filter',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.recurring,
      mileageInterval: 20000,
      timeIntervalMonths: 12,
      condition: 'prototype_fixed_inspection',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE ONLY — DLog demo interval for legacy Axia: inspect every 20,000 km / 12 months; replace only if required. Verify against the exact vehicle manual before real servicing.',
    ),

    MaintenanceRule(
      ruleGroupId: axiaG1RuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_wear_damage',
      source: peroduaManual,
      sourceReference: 'Legacy Axia owner manual - brake inspection',
    ),

    MaintenanceRule(
      ruleGroupId: axiaG1RuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_pressure_wear_damage',
      source: peroduaManual,
      sourceReference: 'Legacy Axia owner manual - tyre inspection',
    ),

    MaintenanceRule(
      ruleGroupId: axiaG1RuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_condition',
      source: peroduaManual,
      sourceReference: 'Legacy Axia owner manual - battery',
    ),

    MaintenanceRule(
      ruleGroupId: axiaG1RuleGroup,
      maintenanceItem: 'Coolant',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 40000,
      timeIntervalMonths: 24,
      condition: 'prototype_replacement_interval',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE ONLY — DLog demo interval for legacy Axia: coolant service at 40,000 km / 24 months. Verify the coolant type and exact vehicle manual before real servicing.',
    ),

    MaintenanceRule(
      ruleGroupId: axiaG1RuleGroup,
      maintenanceItem: 'Transmission Fluid',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 40000,
      timeIntervalMonths: 24,
      condition: 'prototype_replacement_interval',
      source: dlogPrototypeMatrix,
      sourceReference:
          'PROTOTYPE ONLY — DLog demo interval for legacy Axia: transmission-fluid service at 40,000 km / 24 months. Confirm gearbox type and exact vehicle manual before real servicing.',
    ),
  ];

  // ============================================================
  // PROTON X50 2020-2024
  // ============================================================
  //
  // Verified service booklet evidence:
  // - Engine oil: every 10,000 km / 6 months
  // - Oil filter: every service
  // - Air filter: 10k R / 20k C alternating
  // - Spark plugs: every 40,000 km
  // - Brake fluid: 40,000 km / 24 months
  // - Coolant: inspect 40k/24m, replace 60k/36m
  // - DCT fluid: transmission-fluid type must be considered
  //
  // Because the old X50 booklet distinguishes DCT fluid type,
  // we do not blindly hard-code a single 80k/90k value here.
  //
  // ============================================================

  static const List<MaintenanceRule> x50_2020 = [
    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Initial Service',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.initial,
      firstMileage: 1000,
      condition: 'new_vehicle_service',
      source: protonServiceBooklet,
      sourceReference: '2020 X50 Warranty & Service Booklet - initial service',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Engine Oil',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: '2020 X50 Warranty & Service Booklet - engine oil',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference:
          '2020 X50 Warranty & Service Booklet - engine oil filter',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Engine Air Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 20000,
      condition: 'scheduled_replacement_cleaning_cycle',
      source: protonServiceBooklet,
      sourceReference: '2020 X50 Warranty & Service Booklet - air filter',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Spark Plugs',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 40000,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference:
          '2020 X50 Warranty & Service Booklet - spark plugs every 40,000 km',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_wear_damage',
      source: protonServiceBooklet,
      sourceReference: '2020 X50 Warranty & Service Booklet - brake inspection',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Brake Fluid',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 40000,
      timeIntervalMonths: 24,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: '2020 X50 Warranty & Service Booklet - brake fluid',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_pressure_wear_damage',
      source: protonServiceBooklet,
      sourceReference: 'X50 owner/service maintenance guidance',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Tyre Rotation',
      action: MaintenanceAction.rotate,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'X50 maintenance guidance - tyre rotation',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_condition',
      source: protonServiceBooklet,
      sourceReference: 'X50 maintenance schedule - battery',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2020RuleGroup,
      maintenanceItem: 'Coolant',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 60000,
      timeIntervalMonths: 36,
      condition: 'scheduled_replacement',
      source: protonServiceBooklet,
      sourceReference: '2020 X50 Warranty & Service Booklet - coolant',
    ),
  ];

  /// X50 2024 uses a year-specific matrix profile; keep its prototype
  /// inspection cadence separate from the 2020-2023 rule group.
  static List<MaintenanceRule> get x50_2024 => x50_2020.map((rule) {
    final isPrototypeInspection =
        rule.maintenanceItem == 'Brake System' ||
        rule.maintenanceItem == 'Tyres' ||
        rule.maintenanceItem == 'Battery';
    final isPrototypeAirFilter = rule.maintenanceItem == 'Engine Air Filter';

    return MaintenanceRule(
      ruleGroupId: x50_2024RuleGroup,
      maintenanceItem: rule.maintenanceItem,
      action: rule.action,
      stage: isPrototypeInspection ? MaintenanceStage.recurring : rule.stage,
      mileageInterval: isPrototypeInspection
          ? 10000
          : (isPrototypeAirFilter ? 40000 : rule.mileageInterval),
      timeIntervalMonths: isPrototypeInspection
          ? 6
          : (isPrototypeAirFilter
                ? 24
                : (rule.maintenanceItem == 'Spark Plugs'
                      ? 24
                      : rule.timeIntervalMonths)),
      firstMileage: rule.firstMileage,
      condition: isPrototypeInspection
          ? 'prototype_fixed_inspection'
          : (isPrototypeAirFilter
                ? 'prototype_inspect_clean_replace'
                : rule.condition),
      source: isPrototypeInspection || isPrototypeAirFilter
          ? dlogPrototypeMatrix
          : rule.source,
      sourceReference: isPrototypeInspection
          ? 'PROTOTYPE FIXED INSPECTION — X50 2024 matrix: ${rule.maintenanceItem}; replacement remains condition-based.'
          : (isPrototypeAirFilter
                ? 'PROTOTYPE — X50 2024 matrix: air filter 40,000 km / 24 months.'
                : rule.sourceReference),
      sourceUrl: rule.sourceUrl,
      engineOilOptions: rule.maintenanceItem == 'Engine Oil'
          ? _x50_2024OilOptions
          : rule.engineOilOptions,
    );
  }).toList();

  // ============================================================
  // PROTON X50 2025+
  // ============================================================

  static const List<MaintenanceRule> x50_2025 = [
    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Initial Service',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.initial,
      firstMileage: 1000,
      condition: 'new_vehicle_service',
      source: protonServiceBooklet,
      sourceReference:
          'All-New X50 Warranty & Service Booklet - initial service',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Engine Oil',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'All-New X50 Warranty & Service Booklet - engine oil',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'All-New X50 Warranty & Service Booklet - oil filter',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Spark Plugs',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 40000,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'All-New X50 Warranty & Service Booklet - spark plugs',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_wear_damage',
      source: protonServiceBooklet,
      sourceReference:
          'All-New X50 Warranty & Service Booklet - brake inspection',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Brake Fluid',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 40000,
      timeIntervalMonths: 24,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'All-New X50 Warranty & Service Booklet - brake fluid',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_pressure_wear_damage',
      source: protonServiceBooklet,
      sourceReference: 'All-New X50 maintenance guidance - tyres',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Tyre Rotation',
      action: MaintenanceAction.rotate,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'X50 maintenance guidance - tyre rotation',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_condition',
      source: protonServiceBooklet,
      sourceReference: 'All-New X50 maintenance schedule - battery',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Coolant',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 60000,
      timeIntervalMonths: 36,
      condition: 'scheduled_replacement',
      source: protonServiceBooklet,
      sourceReference: 'All-New X50 Warranty & Service Booklet - coolant',
    ),

    MaintenanceRule(
      ruleGroupId: x50_2025RuleGroup,
      maintenanceItem: 'Transmission Fluid',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 80000,
      timeIntervalMonths: 48,
      condition: '7dct_scheduled',
      source: protonServiceBooklet,
      sourceReference: 'All-New X50 Warranty & Service Booklet - 7DCT fluid',
    ),
  ];

  // ============================================================
  // PROTON SAGA 2022 ERA
  // ============================================================

  static const List<MaintenanceRule> saga2022 = [
    MaintenanceRule(
      ruleGroupId: saga2022RuleGroup,
      maintenanceItem: 'Engine Oil',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'Saga MC2 service booklet - 10,000 km / 6 months',
    ),

    MaintenanceRule(
      ruleGroupId: saga2022RuleGroup,
      maintenanceItem: 'Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'Saga MC2 scheduled service',
    ),

    MaintenanceRule(
      ruleGroupId: saga2022RuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_wear_damage',
      source: protonServiceBooklet,
      sourceReference: 'Saga MC2 service booklet - brake inspection',
    ),

    MaintenanceRule(
      ruleGroupId: saga2022RuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_pressure_wear_damage',
      source: protonServiceBooklet,
      sourceReference: 'Saga owner/service materials - tyre inspection',
    ),

    MaintenanceRule(
      ruleGroupId: saga2022RuleGroup,
      maintenanceItem: 'Tyre Rotation',
      action: MaintenanceAction.rotate,
      stage: MaintenanceStage.recurring,
      mileageInterval: 20000,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference:
          'Saga maintenance guidance - tyre rotation every 20,000 km',
    ),

    MaintenanceRule(
      ruleGroupId: saga2022RuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_condition',
      source: protonServiceBooklet,
      sourceReference: 'Saga service materials - battery inspection',
    ),

    MaintenanceRule(
      ruleGroupId: saga2022RuleGroup,
      maintenanceItem: 'Coolant',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'vehicle_specific',
      source: protonServiceBooklet,
      sourceReference:
          'Saga generation-specific coolant interval pending final extraction',
    ),

    MaintenanceRule(
      ruleGroupId: saga2022RuleGroup,
      maintenanceItem: 'Engine Air Filter',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'vehicle_specific',
      source: protonServiceBooklet,
      sourceReference:
          'Saga generation-specific air-filter interval pending final extraction',
    ),

    MaintenanceRule(
      ruleGroupId: saga2022RuleGroup,
      maintenanceItem: 'Transmission Fluid',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'transmission_specific',
      source: protonServiceBooklet,
      sourceReference:
          'Saga transmission-specific interval pending final extraction',
    ),
  ];

  // ============================================================
  // PROTON SAGA 2025+
  // ============================================================

  static const List<MaintenanceRule> saga2025 = [
    MaintenanceRule(
      ruleGroupId: saga2025RuleGroup,
      maintenanceItem: 'Engine Oil',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'All-New Saga Warranty & Service Booklet',
    ),

    MaintenanceRule(
      ruleGroupId: saga2025RuleGroup,
      maintenanceItem: 'Oil Filter',
      action: MaintenanceAction.replace,
      stage: MaintenanceStage.recurring,
      mileageInterval: 10000,
      timeIntervalMonths: 6,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'All-New Saga Warranty & Service Booklet',
    ),

    MaintenanceRule(
      ruleGroupId: saga2025RuleGroup,
      maintenanceItem: 'Brake System',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_wear_damage',
      source: protonServiceBooklet,
      sourceReference: 'All-New Saga Warranty & Service Booklet',
    ),

    MaintenanceRule(
      ruleGroupId: saga2025RuleGroup,
      maintenanceItem: 'Tyres',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_pressure_wear_damage',
      source: protonServiceBooklet,
      sourceReference: 'All-New Saga Warranty & Service Booklet',
    ),

    MaintenanceRule(
      ruleGroupId: saga2025RuleGroup,
      maintenanceItem: 'Tyre Rotation',
      action: MaintenanceAction.rotate,
      stage: MaintenanceStage.recurring,
      mileageInterval: 20000,
      condition: 'scheduled',
      source: protonServiceBooklet,
      sourceReference: 'Saga maintenance guidance - tyre rotation',
    ),

    MaintenanceRule(
      ruleGroupId: saga2025RuleGroup,
      maintenanceItem: 'Battery',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'inspect_condition',
      source: protonServiceBooklet,
      sourceReference: 'All-New Saga Warranty & Service Booklet',
    ),

    MaintenanceRule(
      ruleGroupId: saga2025RuleGroup,
      maintenanceItem: 'Coolant',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'vehicle_specific',
      source: protonServiceBooklet,
      sourceReference: 'All-New Saga generation-specific coolant interval',
    ),

    MaintenanceRule(
      ruleGroupId: saga2025RuleGroup,
      maintenanceItem: 'Engine Air Filter',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'vehicle_specific',
      source: protonServiceBooklet,
      sourceReference: 'All-New Saga generation-specific air-filter interval',
    ),

    MaintenanceRule(
      ruleGroupId: saga2025RuleGroup,
      maintenanceItem: 'Transmission Fluid',
      action: MaintenanceAction.inspect,
      stage: MaintenanceStage.conditionBased,
      condition: 'transmission_specific',
      source: protonServiceBooklet,
      sourceReference: 'All-New Saga transmission-specific interval',
    ),
  ];

  // ============================================================
  // ALL RULES
  // ============================================================

  static List<MaintenanceRule> get all => [
    ...forRuleGroup(myviG2_2011RuleGroup),
    ...forRuleGroup(myviG2Fl2015RuleGroup),
    ...forRuleGroup(myviG3_2017RuleGroup),
    ...forRuleGroup(myviG3Fl2022RuleGroup),
    ...forRuleGroup(axiaG1RuleGroup),
    ...forRuleGroup(axia2019RuleGroup),
    ...forRuleGroup(axia2023DcvTtRuleGroup),
    ...forRuleGroup(x50_2020RuleGroup),
    ...forRuleGroup(x50_2024RuleGroup),
    ...forRuleGroup(x50_2025RuleGroup),
    ...forRuleGroup(saga2022RuleGroup),
    ...forRuleGroup(saga2025RuleGroup),
  ];

  // ============================================================
  // RULE LOOKUP
  // ============================================================

  /// Returns only the rules belonging to the requested
  /// vehicle rule group.
  ///
  /// This is the critical bridge between:
  ///
  /// Vehicle.ruleGroupId
  ///        ↓
  /// MaintenanceRules.forRuleGroup()
  ///        ↓
  /// MaintenanceCalculator
  static List<MaintenanceRule> forRuleGroup(String ruleGroupId) {
    final rules = switch (ruleGroupId) {
      myviG2_2011RuleGroup => myviG2_2011,
      myviG2Fl2015RuleGroup => myviG2Fl2015,
      myviG3_2017RuleGroup => myviG3_2017,
      myviG3Fl2022RuleGroup => myviG3Fl2022,
      axiaG1RuleGroup => axiaG1,
      axia2019RuleGroup => axia2019,
      axia2023DcvTtRuleGroup => axia2023,
      x50_2020RuleGroup => x50_2020,
      x50_2024RuleGroup => x50_2024,
      x50_2025RuleGroup => x50_2025,
      saga2022RuleGroup => saga2022,
      saga2025RuleGroup => saga2025,
      _ => const <MaintenanceRule>[],
    };

    if (rules.isEmpty) return rules;

    final configuredRules = rules.map((rule) {
      if (!rule.isConditionBased) return rule;
      final policy =
          _conditionInspectionPolicies[rule.maintenanceItem
              .trim()
              .toLowerCase()];
      return policy == null
          ? rule
          : rule.copyWith(conditionInspectionPolicy: policy);
    }).toList();

    // The prototype asks users to inspect the engine as a distinct condition
    // item. It has no mileage/replacement interval; its reminder cadence is
    // the DLog prototype policy above.
    if (!configuredRules.any(
      (rule) => rule.maintenanceItem.trim().toLowerCase() == 'engine',
    )) {
      configuredRules.add(
        MaintenanceRule(
          ruleGroupId: ruleGroupId,
          maintenanceItem: 'Engine',
          action: MaintenanceAction.inspect,
          stage: MaintenanceStage.conditionBased,
          condition: 'inspect_leaks_sounds_warning_indicators',
          source: dlogRecommendation,
          sourceReference: 'DLog prototype engine condition checklist',
          conditionInspectionPolicy: _conditionInspectionPolicies['engine'],
        ),
      );
    }

    return List<MaintenanceRule>.unmodifiable(configuredRules);
  }

  // ============================================================
  // SAFE HELPERS
  // ============================================================

  static List<MaintenanceRule> initialRulesForRuleGroup(String ruleGroupId) {
    return forRuleGroup(
      ruleGroupId,
    ).where((rule) => rule.stage == MaintenanceStage.initial).toList();
  }

  static List<MaintenanceRule> recurringRulesForRuleGroup(String ruleGroupId) {
    return forRuleGroup(
      ruleGroupId,
    ).where((rule) => rule.stage == MaintenanceStage.recurring).toList();
  }

  static List<MaintenanceRule> conditionBasedRulesForRuleGroup(
    String ruleGroupId,
  ) {
    return forRuleGroup(
      ruleGroupId,
    ).where((rule) => rule.stage == MaintenanceStage.conditionBased).toList();
  }
}
