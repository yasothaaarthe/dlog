import '../models/maintenance_rule.dart';
import 'maintenance_calculator.dart';

class VehicleStatusRollupItem {
  const VehicleStatusRollupItem({required this.title, required this.status});

  final String title;
  final MaintenanceStatus status;
}

/// Groups the same calculated maintenance results used by Home and the list.
/// A category is returned only when this vehicle has at least one matching
/// maintenance rule, so an unsupported item cannot appear falsely all good.
class VehicleStatusRollup {
  VehicleStatusRollup._();

  static const List<_StatusGroup> _groups = [
    _StatusGroup('Initial Service', {'initial inspection', 'initial service'}),
    _StatusGroup('Engine Oil', {'engine oil'}),
    _StatusGroup('Tires', {'tyres', 'tires', 'tyre rotation', 'tire rotation'}),
    _StatusGroup('Brake Pads', {'brake system', 'brake pads'}),
    _StatusGroup('Battery', {'battery'}),
    _StatusGroup('Engine', {
      'oil filter',
      'engine oil filter',
      'air filter',
      'engine air filter',
      'spark plugs',
      'engine',
    }),
    _StatusGroup('Transmission', {
      'atf',
      'transmission fluid',
      'automatic transmission fluid',
      'manual transmission oil',
      'cvt fluid',
      'cvt filter',
    }),
    _StatusGroup('Fluids', {'brake fluid', 'coolant', 'engine coolant'}),
    _StatusGroup('Cooling System', {'coolant', 'engine coolant'}),
  ];

  static Set<String> unmappedMaintenanceItems(List<MaintenanceResult> results) {
    final mappedNames = _groups
        .expand((group) => group.maintenanceItems)
        .toSet();

    return results
        .where((result) => result.isApplicable)
        .map((result) => result.rule.maintenanceItem.trim().toLowerCase())
        .where((name) => !mappedNames.contains(name))
        .toSet();
  }

  static List<VehicleStatusRollupItem> fromResults(
    List<MaintenanceResult> results,
  ) {
    final applicableResults = results.where((result) => result.isApplicable);

    return _groups
        .map((group) {
          final matching = applicableResults.where(
            (result) => group.maintenanceItems.contains(
              result.rule.maintenanceItem.trim().toLowerCase(),
            ),
          );
          final iterator = matching.iterator;
          if (!iterator.moveNext()) return null;

          var worst = iterator.current.status;
          while (iterator.moveNext()) {
            if (_severity(iterator.current.status) > _severity(worst)) {
              worst = iterator.current.status;
            }
          }

          return VehicleStatusRollupItem(title: group.title, status: worst);
        })
        .whereType<VehicleStatusRollupItem>()
        .toList(growable: false);
  }

  static int _severity(MaintenanceStatus status) => switch (status) {
    MaintenanceStatus.allGood => 0,
    MaintenanceStatus.dueSoon => 1,
    MaintenanceStatus.dueNow => 2,
    MaintenanceStatus.gracePeriod => 3,
  };
}

class _StatusGroup {
  const _StatusGroup(this.title, this.maintenanceItems);

  final String title;
  final Set<String> maintenanceItems;
}
