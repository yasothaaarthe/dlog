import 'package:flutter/material.dart';

import '../models/maintenance_rule.dart';

/// Shared colors for the four maintenance stages across DLog screens.
class MaintenanceStatusStyle {
  MaintenanceStatusStyle._();

  static const Color allGood = Color(0xFF39C56A);
  static const Color dueSoon = Color(0xFFE4A51A);
  static const Color dueNow = Color(0xFFFF5A32);
  static const Color gracePeriod = Color(0xFFFF304A);

  static Color colorFor(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.allGood:
        return allGood;
      case MaintenanceStatus.dueSoon:
        return dueSoon;
      case MaintenanceStatus.dueNow:
        return dueNow;
      case MaintenanceStatus.gracePeriod:
        return gracePeriod;
    }
  }
}
