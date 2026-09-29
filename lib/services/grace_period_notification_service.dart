import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../services/maintenance_calculator.dart';

/// Schedules local, device-time-zone grace-period reminders.
///
/// Notifications are scheduled only for items that are currently in DLog's
/// grace-period stage. The app refreshes these schedules when Home is opened
/// or refreshed; this is a device-local prototype, not a server push service.
class GracePeriodNotificationService {
  GracePeriodNotificationService._();

  static final GracePeriodNotificationService instance =
      GracePeriodNotificationService._();

  static const _enabledKey = 'dlog.graceReminders.enabled';
  static const _scheduledIdsKey = 'dlog.graceReminders.scheduledIds';
  static const _vehicleDocumentIdsKeyPrefix =
      'dlog.vehicleDocuments.scheduledIds.';
  static const _notificationChannelId = 'dlog_grace_period_reminders_v1';
  static const _demoNotificationIdBase = 1900000000;
  static const _reminderTimes = <(int, int)>[(9, 0), (14, 0), (19, 0)];

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get _supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized || !_supportedPlatform) return;

    timezone_data.initializeTimeZones();
    final deviceTimezone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(deviceTimezone.identifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
        defaultPresentSound: true,
      ),
    );

    await _notifications.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!_supportedPlatform) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }

    return await _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<bool> remindersEnabled() async {
    if (!_supportedPlatform) return false;
    return (await SharedPreferences.getInstance()).getBool(_enabledKey) ??
        false;
  }

  Future<bool> enableReminders() async {
    final granted = await requestPermission();
    if (granted) {
      await (await SharedPreferences.getInstance()).setBool(_enabledKey, true);
    }
    return granted;
  }

  Future<void> disableReminders() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
    await _cancelPreviouslyScheduled(preferences);
  }

  /// Rebuilds the app's daily schedule from the current grace-period results.
  Future<void> syncGracePeriodReminders({
    required String vehicleId,
    required List<MaintenanceResult> results,
  }) async {
    if (!_supportedPlatform || !await remindersEnabled()) return;
    await initialize();

    final preferences = await SharedPreferences.getInstance();
    await _cancelPreviouslyScheduled(preferences);

    final scheduledIds = <int>[];
    if (vehicleId.isNotEmpty) {
      for (final result in results.where((item) => item.isGracePeriod)) {
        for (final (hour, minute) in _reminderTimes) {
          final id = _stableId(
            '$vehicleId|${result.rule.maintenanceItem}|$hour',
          );
          final scheduledTime = _nextLocalTime(hour, minute);
          await _notifications.zonedSchedule(
            id: id,
            title: '${result.rule.maintenanceItem} grace period',
            body: _reminderBody(result),
            scheduledDate: scheduledTime,
            notificationDetails: _notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: 'grace|$vehicleId|${result.rule.maintenanceItem}',
          );
          scheduledIds.add(id);
        }
      }
    }

    await preferences.setStringList(
      _scheduledIdsKey,
      scheduledIds.map((id) => id.toString()).toList(),
    );
  }

  /// Replaces expiry reminders for one vehicle without touching maintenance
  /// grace-period schedules or reminders belonging to other vehicles.
  /// Returns false when this device cannot schedule notifications or the user
  /// has not granted notification permission.
  Future<bool> syncVehicleDocumentReminders({
    required String vehicleId,
    required String vehicleLabel,
    DateTime? insuranceExpiry,
    DateTime? roadTaxExpiry,
  }) async {
    if (!_supportedPlatform) return false;
    await initialize();

    final preferences = await SharedPreferences.getInstance();
    final key = '$_vehicleDocumentIdsKeyPrefix$vehicleId';
    final previousIds = preferences.getStringList(key) ?? const [];
    for (final value in previousIds) {
      final id = int.tryParse(value);
      if (id != null) await _notifications.cancel(id: id);
    }
    await preferences.setStringList(key, const []);

    if (!await requestPermission()) return false;

    final scheduledIds = <int>[];
    final documents = <({String name, DateTime? expiry})>[
      (name: 'Insurance', expiry: insuranceExpiry),
      (name: 'Road tax', expiry: roadTaxExpiry),
    ];
    final now = timezone.TZDateTime.now(timezone.local);

    for (final document in documents) {
      final expiry = document.expiry;
      if (expiry == null) continue;

      final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
      for (final daysBefore in const [30, 7, 1, 0]) {
        final reminderDay = expiryDay.subtract(Duration(days: daysBefore));
        final scheduledAt = timezone.TZDateTime(
          timezone.local,
          reminderDay.year,
          reminderDay.month,
          reminderDay.day,
          9,
        );
        final id = _stableId(
          'vehicle-document|$vehicleId|${document.name}|$daysBefore',
        );
        final label = '$vehicleLabel ${document.name.toLowerCase()}';
        final title = '${document.name} ${_expiryTitle(daysBefore)}';
        final body = daysBefore == 0
            ? '$label ${expiryDay.isBefore(DateTime(now.year, now.month, now.day)) ? 'has expired' : 'expires today'}. Update its details in Garage.'
            : '$label expires in $daysBefore days. Update its details in Garage.';

        if (scheduledAt.isAfter(now)) {
          await _notifications.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledAt,
            notificationDetails: _documentExpiryNotificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'vehicle-document|$vehicleId|${document.name}',
          );
        } else if (daysBefore == 0 &&
            !expiryDay.isAfter(DateTime(now.year, now.month, now.day))) {
          await _notifications.show(
            id: id,
            title: '${document.name} expired',
            body: '$label has expired. Update its details in Garage.',
            notificationDetails: _documentExpiryNotificationDetails,
            payload: 'vehicle-document|$vehicleId|${document.name}',
          );
        } else {
          continue;
        }
        scheduledIds.add(id);
      }
    }

    await preferences.setStringList(
      key,
      scheduledIds.map((id) => id.toString()).toList(),
    );
    return true;
  }

  /// Shows an immediate native notification for the three-tap demo.
  Future<void> showDemoAlert({
    required int tapNumber,
    required String maintenanceItem,
  }) async {
    if (!_supportedPlatform) return;
    await initialize();
    await _notifications.show(
      id: _demoNotificationIdBase + tapNumber,
      title: 'DLog grace-period alert ($tapNumber/3)',
      body: '$maintenanceItem needs attention. Complete its service record.',
      notificationDetails: _demoNotificationDetails,
      payload: 'demo|$tapNumber|$maintenanceItem',
    );
  }

  Future<void> cancelAllGraceReminders() async {
    final preferences = await SharedPreferences.getInstance();
    await _cancelPreviouslyScheduled(preferences);
    await preferences.setBool(_enabledKey, false);
    for (var tap = 1; tap <= 3; tap++) {
      await _notifications.cancel(id: _demoNotificationIdBase + tap);
    }
  }

  Future<void> _cancelPreviouslyScheduled(SharedPreferences preferences) async {
    final oldIds = preferences.getStringList(_scheduledIdsKey) ?? const [];
    for (final value in oldIds) {
      final id = int.tryParse(value);
      if (id != null) await _notifications.cancel(id: id);
    }
    await preferences.setStringList(_scheduledIdsKey, const []);
  }

  timezone.TZDateTime _nextLocalTime(int hour, int minute) {
    final now = timezone.TZDateTime.now(timezone.local);
    var next = timezone.TZDateTime(
      timezone.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  String _reminderBody(MaintenanceResult result) {
    final used = result.graceActualUsed;
    final limit = result.graceProgressWindow;
    final remaining = (limit - result.graceProgressUsed).clamp(0, limit);
    final unit = result.graceProgressUsesMileage ? 'km' : 'days';
    if (result.graceExceededBy > 0) {
      return 'Overdue by $used $unit. The DLog grace allowance is $limit $unit and has been exceeded by ${result.graceExceededBy} $unit.';
    }
    return 'Overdue by $used $unit. $remaining $unit of DLog grace remain.';
  }

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      _notificationChannelId,
      'Grace period reminders',
      channelDescription: 'Daily reminders for maintenance in grace period.',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      sound: RawResourceAndroidNotificationSound('grace_period_beep'),
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      sound: 'grace_period_beep.wav',
    ),
  );

  NotificationDetails get _demoNotificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      'dlog_grace_demo_silent_v1',
      'Grace period demo alerts',
      channelDescription: 'In-app demonstration alert banner.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      silent: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: false,
    ),
  );

  NotificationDetails get _documentExpiryNotificationDetails =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dlog_vehicle_document_expiry_v1',
          'Vehicle document expiry',
          channelDescription:
              'Reminders before vehicle insurance and road tax expire.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      );

  String _expiryTitle(int daysBefore) => switch (daysBefore) {
    30 => 'expires in 30 days',
    7 => 'expires in 7 days',
    1 => 'expires tomorrow',
    _ => 'expires today',
  };
}
