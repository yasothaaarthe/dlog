/// DLog Reference Pricing
///
/// These prices are reference ranges for the Quote Check feature.
/// They are NOT manufacturer-mandated prices and should not be presented
/// as guaranteed workshop prices.
///
/// Sources include published service pricing and the supplied DLog
/// prototype average-pricing workbook. Prototype values fill only missing
/// model/item entries and are represented as a point baseline, not a verified
/// market range.

class MaintenancePriceRange {
  final int low;
  final int high;
  final String basis;
  final String source;

  const MaintenancePriceRange({
    required this.low,
    required this.high,
    required this.basis,
    required this.source,
  });

  int get midpoint => ((low + high) / 2).round();

  String get formattedRange => 'RM$low – RM$high';
}

class MaintenancePriceData {
  final String maintenanceItem;
  final Map<String, MaintenancePriceRange> vehiclePrices;

  const MaintenancePriceData({
    required this.maintenanceItem,
    required this.vehiclePrices,
  });

  MaintenancePriceRange? forModel(String model) {
    return vehiclePrices[model];
  }
}

class MaintenancePrices {
  MaintenancePrices._();

  static const _prototypeAverageBasis =
      'Prototype average mechanic price; shared across model variants';
  static const _prototypePricingSource =
      'DLog_Prototype_Maintenance_Average_Pricing.xlsx — Variant Pricing';

  // ------------------------------------------------------------
  // 1. ENGINE OIL & OIL FILTER
  // ------------------------------------------------------------

  static const engineOilAndFilter = MaintenancePriceData(
    maintenanceItem: 'Engine Oil & Oil Filter',
    vehiclePrices: {
      'Axia': MaintenancePriceRange(
        low: 157,
        high: 227,
        basis: 'Published current Perodua scheduled-service prices',
        source: 'Perodua scheduled service pricing / Paultan 2026',
      ),

      'Myvi': MaintenancePriceRange(
        low: 177,
        high: 241,
        basis: 'Published current Perodua scheduled-service prices',
        source: 'Perodua scheduled service pricing / Paultan 2026',
      ),

      'X50': MaintenancePriceRange(
        low: 216,
        high: 399,
        basis:
            'Published Proton service pricing and current service-centre pricing',
        source: 'Proton service package / Pantai Bharu published pricing',
      ),

      'Saga': MaintenancePriceRange(
        low: 194,
        high: 240,
        basis: 'Published current Proton scheduled-service prices',
        source: 'Proton service pricing / published 2025–2026 schedule',
      ),
    },
  );

  // ------------------------------------------------------------
  // 2. BRAKE SYSTEM
  // ------------------------------------------------------------
  //
  // Brake quotes vary by the work included. These prototype averages are
  // general demo baselines from the supplied workbook, not verified prices
  // for a particular brake repair.
  static const brakeSystem = MaintenancePriceData(
    maintenanceItem: 'Brake System',
    vehiclePrices: {
      'Saga': MaintenancePriceRange(
        low: 180,
        high: 180,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
      'Myvi': MaintenancePriceRange(
        low: 180,
        high: 180,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
      'Axia': MaintenancePriceRange(
        low: 160,
        high: 160,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
      'X50': MaintenancePriceRange(
        low: 280,
        high: 280,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
    },
  );

  // ------------------------------------------------------------
  // 3. TYRES
  // ------------------------------------------------------------
  //
  // These figures represent a FOUR-TYRE replacement reference,
  // not a mandatory replacement interval.
  //
  static const tyres = MaintenancePriceData(
    maintenanceItem: 'Tyres',
    vehiclePrices: {
      'Axia': MaintenancePriceRange(
        low: 560,
        high: 800,
        basis: 'Published current Malaysian tyre pricing for four tyres',
        source: 'Paultan / current Malaysian tyre pricing',
      ),

      'Myvi': MaintenancePriceRange(
        low: 740,
        high: 1240,
        basis: 'Published current Malaysian tyre pricing for four tyres',
        source: 'Paultan / current Malaysian tyre pricing',
      ),
      'Saga': MaintenancePriceRange(
        low: 800,
        high: 800,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
      'X50': MaintenancePriceRange(
        low: 1100,
        high: 1100,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
    },
  );

  // ------------------------------------------------------------
  // 4. TYRE ROTATION
  // ------------------------------------------------------------
  //
  // Prototype average service charges from the supplied workbook fill this
  // item where a published vehicle-specific range is unavailable.
  static const tyreRotation = MaintenancePriceData(
    maintenanceItem: 'Tyre Rotation',
    vehiclePrices: {
      'Saga': MaintenancePriceRange(
        low: 25,
        high: 25,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
      'Myvi': MaintenancePriceRange(
        low: 25,
        high: 25,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
      'Axia': MaintenancePriceRange(
        low: 25,
        high: 25,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
      'X50': MaintenancePriceRange(
        low: 30,
        high: 30,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
    },
  );

  // ------------------------------------------------------------
  // 5. BATTERY
  // ------------------------------------------------------------
  //
  // Battery type can differ by variant, especially where
  // start-stop/EFB/AGM systems are involved.
  //
  static const battery = MaintenancePriceData(
    maintenanceItem: 'Battery',
    vehiclePrices: {
      'Axia': MaintenancePriceRange(
        low: 160,
        high: 350,
        basis: 'Published Malaysian battery replacement ranges',
        source: 'Current Malaysian automotive battery pricing',
      ),

      'X50': MaintenancePriceRange(
        low: 292,
        high: 820,
        basis: 'Published current X50 battery pricing by battery type',
        source: 'Current Malaysian X50 battery pricing',
      ),
      'Saga': MaintenancePriceRange(
        low: 250,
        high: 250,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
      'Myvi': MaintenancePriceRange(
        low: 230,
        high: 230,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
    },
  );

  // ------------------------------------------------------------
  // 6. COOLANT
  // ------------------------------------------------------------

  static const coolant = MaintenancePriceData(
    maintenanceItem: 'Coolant',
    vehiclePrices: {
      'X50': MaintenancePriceRange(
        low: 135,
        high: 160,
        basis: 'Published Proton coolant/service pricing',
        source: 'Current Proton/X50 maintenance pricing',
      ),

      'Saga': MaintenancePriceRange(
        low: 108,
        high: 140,
        basis: 'Published Proton coolant/component pricing',
        source: 'Current Proton maintenance pricing',
      ),
      'Axia': MaintenancePriceRange(
        low: 75,
        high: 75,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
      'Myvi': MaintenancePriceRange(
        low: 80,
        high: 80,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
    },
  );

  // ------------------------------------------------------------
  // 7. ENGINE AIR FILTER
  // ------------------------------------------------------------

  static const engineAirFilter = MaintenancePriceData(
    maintenanceItem: 'Engine Air Filter',
    vehiclePrices: {
      'X50': MaintenancePriceRange(
        low: 28,
        high: 70,
        basis: 'Published X50 component/service pricing',
        source: 'Current Malaysian X50 parts/service pricing',
      ),

      'Saga': MaintenancePriceRange(
        low: 32,
        high: 56,
        basis: 'Published current Proton maintenance/component pricing',
        source: 'Current Proton maintenance pricing',
      ),
      'Axia': MaintenancePriceRange(
        low: 50,
        high: 50,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
      'Myvi': MaintenancePriceRange(
        low: 55,
        high: 55,
        basis: _prototypeAverageBasis,
        source: _prototypePricingSource,
      ),
    },
  );

  // ------------------------------------------------------------
  // 8. TRANSMISSION FLUID
  // ------------------------------------------------------------

  static const transmissionFluid = MaintenancePriceData(
    maintenanceItem: 'Transmission Fluid',
    vehiclePrices: {
      'Axia': MaintenancePriceRange(
        low: 227,
        high: 485,
        basis:
            'Published Axia scheduled-service pricing where CVT fluid is included',
        source: 'Current Perodua scheduled-service pricing / Paultan 2026',
      ),

      'Myvi': MaintenancePriceRange(
        low: 438,
        high: 728,
        basis:
            'Published Myvi scheduled-service pricing where transmission fluid is included',
        source: 'Current Perodua scheduled-service pricing / Paultan 2026',
      ),

      'X50': MaintenancePriceRange(
        low: 300,
        high: 400,
        basis: 'Published Proton X50 transmission-fluid/service pricing',
        source: 'Current Proton/X50 maintenance pricing',
      ),

      'Saga': MaintenancePriceRange(
        low: 204,
        high: 295,
        basis: 'Published current Saga transmission-fluid pricing',
        source: 'Current Proton Saga maintenance pricing',
      ),
    },
  );

  // ------------------------------------------------------------
  // ALL USER-FACING MAINTENANCE ITEMS
  // ------------------------------------------------------------

  static const List<MaintenancePriceData> all = [
    engineOilAndFilter,
    brakeSystem,
    tyres,
    tyreRotation,
    battery,
    coolant,
    engineAirFilter,
    transmissionFluid,
  ];

  static MaintenancePriceData? findItem(String maintenanceItem) {
    for (final item in all) {
      if (item.maintenanceItem == maintenanceItem) {
        return item;
      }
    }

    return null;
  }

  static MaintenancePriceRange? findPrice({
    required String maintenanceItem,
    required String model,
  }) {
    final item = findItem(maintenanceItem);

    if (item == null) {
      return null;
    }

    return item.forModel(model);
  }
}
