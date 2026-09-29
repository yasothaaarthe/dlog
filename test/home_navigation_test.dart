import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dlog_new/screens/encyclopedia/encyclopedia_screen.dart';
import 'package:dlog_new/screens/home/home_screen.dart';
import 'package:dlog_new/screens/sos/sos_screen.dart';
import 'package:dlog_new/screens/maintenance/maintenance_list_screen.dart';
import 'package:dlog_new/screens/vehicle_status/vehicle_status_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const vehicle = <String, dynamic>{
    'manufacturer': 'Perodua',
    'model': 'Axia',
    'variant': '1.0 SE',
    'year': 2019,
    'currentMileage': 20000,
    'vehicleLifecycle': 'existing',
    'ruleGroupId': 'AXIA_2019',
  };

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(vehicleData: vehicle)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home Encyclopedia button opens Encyclopedia screen', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.text('Encyclopedia').last);
    await tester.pumpAndSettle();

    expect(find.byType(EncyclopediaScreen), findsOneWidget);
  });

  testWidgets('home SOS button opens SOS screen', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('SOS').last);
    await tester.pumpAndSettle();

    expect(find.byType(SosScreen), findsOneWidget);
    expect(find.text('EMERGENCY SOS'), findsOneWidget);
  });
  testWidgets('vehicle arrow opens Vehicle Status', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(VehicleStatusScreen), findsOneWidget);
  });

  testWidgets('View All Maintenance opens the maintenance list', (
    tester,
  ) async {
    await pumpHome(tester);

    final maintenanceButton = find.text('VIEW ALL MAINTENANCE');
    await tester.ensureVisible(maintenanceButton);
    await tester.tap(maintenanceButton);
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceListScreen), findsOneWidget);
  });
  testWidgets('home notification bell opens grace-period center', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('GRACE PERIOD NOTIFICATIONS'), findsOneWidget);
    expect(find.text('No grace-period items right now.'), findsOneWidget);
  });

  testWidgets('home refresh action reloads dashboard data', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byTooltip('Refresh home data'));
    await tester.pumpAndSettle();

    expect(find.text('Home data refreshed.'), findsOneWidget);
  });
}
