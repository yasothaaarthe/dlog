import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../services/maintenance_calculator.dart';
import '../../services/auth_service.dart';
import '../../services/grace_period_notification_service.dart';

import '../../services/maintenance_status_service.dart';
import '../../repositories/vehicle_repository.dart';

import '../../theme/dlog_colors.dart';
import '../../theme/dlog_theme_controller.dart';

import '../../theme/maintenance_status_style.dart';

import '../../widgets/dlog_background.dart';

import '../auth/welcome_screen.dart';

import '../garage/garage_screen.dart';
import '../encyclopedia/encyclopedia_screen.dart';
import '../sos/sos_screen.dart';

import '../../navigation/dlog_navigation.dart';

import '../maintenance/maintenance_list_screen.dart';

import '../vehicle_status/vehicle_status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.userName = 'Yas', this.vehicleData});

  // Username will later come from Firebase Auth / users collection.

  final String userName;

  // Vehicle data comes from the vehicle created during onboarding.

  final Map<String, dynamic>? vehicleData;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MaintenanceStatusService _maintenanceStatusService =
      MaintenanceStatusService();
  static final VehicleRepository _vehicleRepository = VehicleRepository();

  List<MaintenanceResult> _maintenanceResults = [];

  Map<String, dynamic>? _latestVehicleData;

  bool _maintenanceLoading = true;

  String? _maintenanceError;

  int _demoAlertCount = 0;

  bool _demoAlertRunning = false;

  bool _demoAlarmEnabled = true;

  int _demoAlertGeneration = 0;

  bool _homeRefreshing = false;

  bool _dailyRemindersEnabled = false;

  final GracePeriodNotificationService _notificationService =
      GracePeriodNotificationService.instance;

  final AudioPlayer _demoAudioPlayer = AudioPlayer();

  Map<String, dynamic> get _vehicle =>
      _latestVehicleData ?? widget.vehicleData ?? const <String, dynamic>{};

  @override
  void initState() {
    super.initState();

    _loadMaintenanceData();
  }

  @override
  void dispose() {
    _demoAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadMaintenanceData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final defaultVehicle = userId == null
          ? null
          : await _vehicleRepository.getDefaultVehicleForUser(userId);
      final snapshot = await _maintenanceStatusService.loadForVehicle(
        defaultVehicle ?? _vehicle,
      );

      if (!mounted) return;

      setState(() {
        _latestVehicleData = snapshot.vehicle;
        _maintenanceResults = snapshot.results;
        _maintenanceLoading = false;
        _maintenanceError = null;
      });

      await _syncGracePeriodReminders(snapshot.vehicle);
    } catch (e) {
      debugPrint('DLOG MAINTENANCE LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _maintenanceResults = [];
        _maintenanceLoading = false;
        _maintenanceError = 'Unable to calculate maintenance right now.';
      });
    }
  }

  Future<void> _syncGracePeriodReminders(Map<String, dynamic> vehicle) async {
    try {
      await _notificationService.syncGracePeriodReminders(
        vehicleId: vehicle['id']?.toString() ?? '',
        results: _maintenanceResults,
      );
      final enabled = await _notificationService.remindersEnabled();
      if (mounted) setState(() => _dailyRemindersEnabled = enabled);
    } catch (error) {
      debugPrint('DLOG GRACE REMINDER SYNC ERROR: $error');
    }
  }

  // VEHICLE IMAGE MAPPING

  // ============================================================

  String _vehicleImage(String model) {
    switch (model.trim().toLowerCase()) {
      case 'myvi':
        return 'assets/images/myvi.png';

      case 'axia':
        return 'assets/images/axia.png';

      case 'x50':
        return 'assets/images/x50.png';

      case 'saga':
        return 'assets/images/saga.png';

      default:
        return '';
    }
  }

  // ============================================================

  // HELPERS

  // ============================================================

  String _formatNumber(num value) {
    final text = value.round().toString();

    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final positionFromEnd = text.length - i;

      buffer.write(text[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }

  // ============================================================

  // BUILD

  // ============================================================

  @override
  Widget build(BuildContext context) {
    final model = (_vehicle['model'] ?? 'Vehicle').toString();

    final manufacturer = (_vehicle['manufacturer'] ?? 'Manufacturer')
        .toString();

    final variant = (_vehicle['variant'] ?? 'Variant').toString();

    final year = (_vehicle['year'] ?? '').toString();

    final mileage = (_vehicle['currentMileage'] ?? 0) as num;

    return Scaffold(
      backgroundColor: Colors.black,

      body: DLogBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),

            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                _topHeader(context),

                const SizedBox(height: 28),

                _vehicleHero(
                  model: model,

                  manufacturer: manufacturer,

                  variant: variant,

                  year: year,

                  mileage: mileage,
                ),

                const SizedBox(height: 24),

                if (_maintenanceLoading)
                  _maintenanceLoadingCard()
                else if (_maintenanceResults.isNotEmpty)
                  _maintenanceStatusCard()
                else
                  _maintenanceEmptyCard(),

                const SizedBox(height: 20),

                _viewAllMaintenanceButton(),

                if (!_maintenanceLoading) ...[
                  const SizedBox(height: 20),
                  _gracePeriodRemindersSection(),
                ],

                // Extra space so the last content isn't hidden

                // behind the fixed navigation bar.
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),

      // ==========================================================

      // FIXED BOTTOM NAVIGATION

      // ==========================================================
      bottomNavigationBar: SafeArea(
        top: false,

        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),

          child: _bottomNavigationPreview(),
        ),
      ),
    );
  }

  // ============================================================

  // HEADER

  // ============================================================

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good morning,';
    }

    if (hour >= 12 && hour < 17) {
      return 'Good afternoon,';
    }

    return 'Good evening,';
  }

  Widget _topHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                _getGreeting(),

                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),

                  fontSize: 16,

                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 2),

              Row(
                children: [
                  Text(
                    widget.userName,

                    style: const TextStyle(
                      color: DLogColors.white,

                      fontSize: 27,

                      fontWeight: FontWeight.w800,

                      height: 1.0,
                    ),
                  ),

                  const SizedBox(width: 7),

                  const Text('👋', style: TextStyle(fontSize: 22)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 4),
        _headerIcon(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: _showNotificationCenter,
        ),
        const SizedBox(width: 3),
        _headerIcon(
          icon: Icons.person_outline_rounded,
          tooltip: 'Profile',
          onTap: _showProfileSheet,
        ),
        const SizedBox(width: 3),
        _headerIcon(
          icon: Icons.logout_rounded,
          tooltip: 'Log out',
          onTap: () => _showLogoutDialog(context),
        ),
        const SizedBox(width: 3),
        _headerIcon(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh home data',
          onTap: _refreshHome,
          busy: _homeRefreshing,
        ),
      ],
    );
  }

  Widget _headerIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.7),
                  )
                : Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.88),
                    size: 18,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshHome() async {
    if (_homeRefreshing) return;
    setState(() => _homeRefreshing = true);
    await _loadMaintenanceData();
    if (!mounted) return;
    setState(() => _homeRefreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _maintenanceError == null
              ? 'Home data refreshed.'
              : 'Could not refresh home data.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showProfileSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF111416),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR PROFILE',
                  style: TextStyle(
                    color: DLogColors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName?.trim().isNotEmpty == true
                      ? user!.displayName!
                      : widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  user?.email ?? 'Signed in to DLog',
                  style: const TextStyle(color: DLogColors.grey, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    '${_vehicle['manufacturer'] ?? ''} ${_vehicle['model'] ?? 'Vehicle'}'
                    ' • ${_vehicle['variant'] ?? ''} ${_vehicle['year'] ?? ''}'
                    '\n${_formatNumber((_vehicle['currentMileage'] as num?) ?? 0)} KM',
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17191B),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: DLogColors.grey.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        DLogThemeController.instance.isLightMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: DLogColors.burgundyBright,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Light mode',
                              style: TextStyle(
                                color: DLogColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Use a brighter DLog appearance',
                              style: TextStyle(color: DLogColors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      StatefulBuilder(
                        builder: (context, setSheetState) => Switch.adaptive(
                          value: DLogThemeController.instance.isLightMode,
                          activeColor: DLogColors.burgundyBright,
                          onChanged: (enabled) async {
                            await DLogThemeController.instance.setLightMode(
                              enabled,
                            );
                            if (sheetContext.mounted) setSheetState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _showLogoutDialog(context);
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('LOG OUT'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5265),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showNotificationCenter() async {
    final enabled = await _notificationService.remindersEnabled();
    if (!mounted) return;
    setState(() => _dailyRemindersEnabled = enabled);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.68,
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF111416),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GRACE PERIOD NOTIFICATIONS',
                  style: TextStyle(
                    color: DLogColors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Only maintenance currently in its grace period appears here.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                if (_maintenanceLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_graceResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'No grace-period items right now.',
                      style: TextStyle(color: DLogColors.grey),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _graceResults.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _notificationReminderRow(_graceResults[index]),
                    ),
                  ),
                const SizedBox(height: 14),
                Text(
                  _dailyRemindersEnabled
                      ? 'Daily alerts: 9:00 AM, 2:00 PM and 7:00 PM'
                      : 'Daily alerts are off. Turn them on to get 3 reminders a day.',
                  style: const TextStyle(color: DLogColors.grey, fontSize: 11),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _toggleGraceReminders();
                    },
                    icon: Icon(
                      _dailyRemindersEnabled
                          ? Icons.notifications_off_rounded
                          : Icons.notifications_active_rounded,
                    ),
                    label: Text(
                      _dailyRemindersEnabled
                          ? 'TURN OFF DAILY REMINDERS'
                          : 'ENABLE DAILY REMINDERS',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notificationReminderRow(MaintenanceResult result) {
    final mileageBased = result.graceProgressUsesMileage;
    final used = result.graceProgressUsed;
    final limit = result.graceProgressWindow;
    final remaining = (limit - used).clamp(0, limit);
    final unit = mileageBased ? 'KM' : 'DAYS';
    final statusText = result.graceExceededBy > 0
        ? 'GRACE LIMIT EXCEEDED BY ${result.graceExceededBy} $unit'
        : '$remaining $unit GRACE REMAINING';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1013),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFFF304A).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6474)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${result.rule.maintenanceItem} • $statusText',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleGraceReminders() async {
    try {
      if (_dailyRemindersEnabled) {
        await _notificationService.disableReminders();
        if (!mounted) return;
        setState(() => _dailyRemindersEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily grace-period alerts turned off.'),
          ),
        );
        return;
      }

      final granted = await _notificationService.enableReminders();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission was not granted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() => _dailyRemindersEnabled = true);
      await _notificationService.syncGracePeriodReminders(
        vehicleId: _vehicle['id']?.toString() ?? '',
        results: _maintenanceResults,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Grace-period alerts are scheduled for 9 AM, 2 PM and 7 PM.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      debugPrint('DLOG NOTIFICATION SETUP ERROR: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not set up reminders. Check notification permissions.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ============================================================

  // LOGOUT

  // ============================================================

  Future<void> _showLogoutDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121416),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),

            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),

          title: const Text(
            'Log out?',

            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),

          content: Text(
            'You can sign back in anytime to access your vehicles and maintenance records.',

            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),

              height: 1.4,
            ),
          ),

          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },

              child: Text(
                'CANCEL',

                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),

                  fontWeight: FontWeight.w700,

                  letterSpacing: 0.5,
                ),
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },

              child: const Text(
                'LOG OUT',

                style: TextStyle(
                  color: Color(0xFFFF5265),

                  fontWeight: FontWeight.w800,

                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    await _notificationService.cancelAllGraceReminders();
    await AuthService().logout();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),

      (route) => false,
    );
  }

  // ============================================================

  // VEHICLE HERO

  // ============================================================

  Widget _vehicleHero({
    required String model,

    required String manufacturer,

    required String variant,

    required String year,

    required num mileage,
  }) {
    final imagePath = _vehicleImage(model);

    return Container(
      width: double.infinity,

      height: 305,

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),

        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),

          width: 1,
        ),

        gradient: const LinearGradient(
          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [Color(0xFF17191B), Color(0xFF090A0B), Color(0xFF050505)],
        ),

        boxShadow: [
          BoxShadow(
            color: DLogColors.burgundy.withValues(alpha: 0.16),

            blurRadius: 35,

            spreadRadius: 1,
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),

        child: Stack(
          children: [
            // Burgundy atmospheric glow.
            Positioned(
              right: -90,

              top: -80,

              child: Container(
                width: 300,

                height: 300,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  gradient: RadialGradient(
                    colors: [
                      DLogColors.burgundy.withValues(alpha: 0.34),

                      DLogColors.burgundy.withValues(alpha: 0.10),

                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Subtle lower road-like glow.
            Positioned(
              left: -80,

              right: -80,

              bottom: -95,

              child: Container(
                height: 190,

                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      DLogColors.burgundy.withValues(alpha: 0.22),

                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Vehicle image.
            if (imagePath.isNotEmpty)
              Positioned(
                right: -32,

                top: 30,

                width: 310,

                height: 185,

                child: IgnorePointer(
                  child: Image.asset(
                    imagePath,

                    fit: BoxFit.contain,

                    alignment: Alignment.centerRight,

                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),

            // Vehicle information.
            Positioned(
              left: 20,

              right: 20,

              bottom: 19,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    '$manufacturer $model',

                    style: const TextStyle(
                      color: Colors.white,

                      fontSize: 23,

                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '$variant • $year',

                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),

                      fontSize: 14,

                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    height: 1,

                    color: Colors.white.withValues(alpha: 0.12),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,

                    children: [
                      Text(
                        _formatNumber(mileage),

                        style: const TextStyle(
                          color: Colors.white,

                          fontSize: 27,

                          fontWeight: FontWeight.w800,

                          height: 1,
                        ),
                      ),

                      const SizedBox(width: 7),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),

                        child: Text(
                          'KM',

                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),

                            fontSize: 12,

                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      const Spacer(),

                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          await DLogNavigation.push(
                            context,
                            VehicleStatusScreen(vehicle: _vehicle),
                          );
                          if (mounted) await _loadMaintenanceData();
                        },
                        child: Container(
                          width: 43,

                          height: 43,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            color: DLogColors.burgundy.withValues(alpha: 0.82),

                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),

                            boxShadow: [
                              BoxShadow(
                                color: DLogColors.burgundy.withValues(
                                  alpha: 0.35,
                                ),

                                blurRadius: 15,
                              ),
                            ],
                          ),

                          child: const Icon(
                            Icons.arrow_forward_rounded,

                            color: Colors.white,

                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================

  // MAINTENANCE STATUS

  // ============================================================

  List<MaintenanceResult> get _graceResults =>
      MaintenanceCalculator.gracePeriodItems(_maintenanceResults);

  int get _allGoodCount =>
      MaintenanceCalculator.allGoodCount(_maintenanceResults);

  int get _dueSoonCount =>
      MaintenanceCalculator.dueSoonCount(_maintenanceResults);

  int get _dueNowCount =>
      MaintenanceCalculator.dueNowCount(_maintenanceResults);

  int get _gracePeriodCount =>
      MaintenanceCalculator.gracePeriodCount(_maintenanceResults);

  double get _onTrackRatio {
    if (_maintenanceResults.isEmpty) return 0;

    return ((_allGoodCount + _dueSoonCount) / _maintenanceResults.length).clamp(
      0.0,
      1.0,
    );
  }

  Widget _maintenanceLoadingCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        color: const Color(0xFF0D1012),

        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),

      child: const Row(
        children: [
          SizedBox(
            width: 18,

            height: 18,

            child: CircularProgressIndicator(strokeWidth: 2),
          ),

          SizedBox(width: 12),

          Text(
            'Calculating maintenance…',

            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _maintenanceEmptyCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        color: const Color(0xFF0D1012),

        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Maintenance Status',

            style: TextStyle(
              color: Colors.white,

              fontSize: 17,

              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _maintenanceError ??
                'No maintenance rules are available for this vehicle yet.',

            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),

              fontSize: 12,

              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _maintenanceStatusCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(18, 17, 18, 19),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        color: const Color(0xFF0D1012),

        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            'Maintenance Status',

            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              _statusRing(),

              const SizedBox(width: 24),

              Expanded(
                child: Column(
                  children: [
                    _statusLegend(
                      color: MaintenanceStatusStyle.allGood,
                      value: '$_allGoodCount',
                      label: 'All Good',
                    ),

                    const SizedBox(height: 9),

                    _statusLegend(
                      color: MaintenanceStatusStyle.dueSoon,
                      value: '$_dueSoonCount',
                      label: 'Due Soon',
                    ),

                    const SizedBox(height: 9),

                    _statusLegend(
                      color: MaintenanceStatusStyle.dueNow,
                      value: '$_dueNowCount',
                      label: 'Due Now',
                    ),

                    const SizedBox(height: 9),

                    _statusLegend(
                      color: MaintenanceStatusStyle.gracePeriod,
                      value: '$_gracePeriodCount',
                      label: 'Grace Period',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusRing() {
    final percentage = (_onTrackRatio * 100).round();

    return SizedBox(
      width: 132,

      height: 132,

      child: Stack(
        alignment: Alignment.center,

        children: [
          SizedBox(
            width: 126,

            height: 126,

            child: CircularProgressIndicator(
              value: _onTrackRatio,

              strokeWidth: 10,

              backgroundColor: Colors.white.withValues(alpha: 0.08),

              valueColor: const AlwaysStoppedAnimation<Color>(
                DLogColors.burgundy,
              ),
            ),
          ),

          Container(
            width: 101,

            height: 101,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color: const Color(0xFF0D1012),

              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 2),

                const Text(
                  'On Track',
                  style: TextStyle(
                    color: DLogColors.silver,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLegend({
    required Color color,

    required String value,

    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 17,

          height: 17,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            color: color.withValues(alpha: 0.18),

            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),

          child: Center(
            child: Text(
              value,

              style: TextStyle(
                color: color,

                fontSize: 9,

                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),

        const SizedBox(width: 9),

        Text(
          label,

          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),

            fontSize: 12,

            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================

  // GRACE PERIOD SECTION

  // ============================================================

  Widget _gracePeriodRemindersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _gracePeriodHeader(),
        const SizedBox(height: 12),
        if (_maintenanceError != null)
          _maintenanceEmptyCard()
        else if (_graceResults.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1012),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: const Text(
              'No maintenance items are currently in the grace period.',
              style: TextStyle(color: DLogColors.grey, fontSize: 12),
            ),
          )
        else
          ..._graceResults.expand(
            (result) => [_gracePeriodCard(result), const SizedBox(height: 12)],
          ),
      ],
    );
  }

  Widget _gracePeriodHeader() {
    return const Text(
      'Grace Period Reminders',

      style: TextStyle(
        color: Colors.white,

        fontSize: 21,

        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ============================================================

  // GRACE PERIOD CARD

  // ============================================================

  Widget _gracePeriodCard(MaintenanceResult result) {
    final mileageGrace = result.graceProgressUsesMileage;
    final unit = mileageGrace ? 'KM' : 'DAYS';

    final totalGrace = result.graceProgressWindow;

    final used = result.graceProgressUsed;

    final actualUsed = result.graceActualUsed;

    final remaining = (totalGrace - used).clamp(0, totalGrace);

    final usedRatio = totalGrace <= 0 ? 1.0 : used / totalGrace;

    final safeUsedRatio = usedRatio.clamp(0.0, 1.0).toDouble();

    final overLimitText = result.graceExceededBy > 0
        ? ' The ${_formatNumber(totalGrace)} $unit grace allowance is exceeded by ${_formatNumber(result.graceExceededBy)} $unit.'
        : '';

    final item = result.rule.maintenanceItem;

    final manufacturer = (_vehicle['manufacturer'] ?? '').toString().trim();

    final model = (_vehicle['model'] ?? '').toString().trim();

    final variant = (_vehicle['variant'] ?? '').toString().trim();

    final vehicleName = '$manufacturer $model'.trim();

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        gradient: const LinearGradient(
          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [Color(0xFF22070D), Color(0xFF10080B), Color(0xFF090A0B)],
        ),

        border: Border.all(
          color: const Color(0xFFFF304A).withValues(alpha: 0.52),
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF304A).withValues(alpha: 0.10),

            blurRadius: 24,

            spreadRadius: 1,
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 42,

                height: 42,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: const Color(0xFFFF304A).withValues(alpha: 0.14),

                  border: Border.all(
                    color: const Color(0xFFFF5265).withValues(alpha: 0.40),
                  ),
                ),

                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF6474),
                  size: 23,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'MAINTENANCE ALERT',

                            style: TextStyle(
                              color: Color(0xFFFF6474),

                              fontSize: 9,

                              fontWeight: FontWeight.w800,

                              letterSpacing: 0.8,
                            ),
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),

                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF304A,
                            ).withValues(alpha: 0.16),

                            borderRadius: BorderRadius.circular(12),

                            border: Border.all(
                              color: const Color(
                                0xFFFF304A,
                              ).withValues(alpha: 0.45),
                            ),
                          ),

                          child: const Text(
                            'GRACE PERIOD',

                            style: TextStyle(
                              color: Color(0xFFFF6474),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    if (vehicleName.isNotEmpty)
                      Text(
                        vehicleName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    if (variant.isNotEmpty) ...[
                      const SizedBox(height: 2),

                      Text(
                        variant,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Tooltip(
                message: _demoAlarmEnabled
                    ? 'Turn demo alarm off'
                    : 'Turn demo alarm on',
                child: GestureDetector(
                  onTap: _toggleDemoAlarm,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 46,

                    height: 46,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      color: const Color(0xFFFF304A).withValues(alpha: 0.10),

                      border: Border.all(
                        color: const Color(0xFFFF5265).withValues(alpha: 0.45),
                      ),
                    ),

                    child: Icon(
                      !_demoAlarmEnabled
                          ? Icons.notifications_off_rounded
                          : _demoAlertRunning
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      color: const Color(0xFFFF6474),
                      size: 23,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            mileageGrace
                ? 'Your service is overdue by ${_formatNumber(actualUsed)} KM.$overLimitText'
                : 'Your service is overdue by ${_formatNumber(actualUsed)} days.$overLimitText',

            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Text(
                mileageGrace
                    ? '${_formatNumber(used)} km of grace used'
                    : '${_formatNumber(used)} days of grace used',

                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              Text(
                '${_formatNumber(remaining)} $unit remaining',

                style: const TextStyle(
                  color: Color(0xFFFF6474),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _graceBar(safeUsedRatio),

          const SizedBox(height: 14),

          Container(
            height: 54,

            padding: const EdgeInsets.symmetric(horizontal: 13),

            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),

              borderRadius: BorderRadius.circular(13),

              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),

            child: Row(
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFFFF6474),
                  size: 21,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Text(
                    'DEMO ALERT • $_demoAlertCount/3 SHOWN',

                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 9),

          SizedBox(
            width: double.infinity,

            height: 50,

            child: ElevatedButton(
              onPressed: _demoAlertCount >= 3 || _demoAlertRunning
                  ? null
                  : () => _runDemoAlert(maintenanceItem: item),

              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D1B31),

                disabledBackgroundColor: const Color(0xFF55121D),

                foregroundColor: Colors.white,

                disabledForegroundColor: Colors.white.withValues(alpha: 0.45),

                elevation: 0,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                  side: const BorderSide(color: Color(0xFFFF5265)),
                ),
              ),

              child: Text(
                _demoAlertCount >= 3
                    ? '3 / 3 ALERTS SHOWN'
                    : _demoAlertRunning
                    ? _demoAlarmEnabled
                          ? 'PLAYING ALERT…'
                          : 'ALERT SHOWN • ALARM OFF'
                    : 'TEST ALERT  •  $_demoAlertCount/3',

                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),

          const SizedBox(height: 7),

          Center(
            child: Text(
              'Tap to demonstrate the alert • maximum 3 times',

              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 9,
              ),
            ),
          ),

          const SizedBox(height: 11),

          SizedBox(
            width: double.infinity,

            height: 50,

            child: OutlinedButton.icon(
              onPressed: () async {
                await DLogNavigation.push(
                  context,
                  MaintenanceListScreen(vehicle: _vehicle),
                );
                if (mounted) await _loadMaintenanceData();
              },

              icon: const Icon(Icons.build_circle_outlined, size: 19),

              label: const Text('VIEW MAINTENANCE'),

              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF6474),

                side: const BorderSide(color: Color(0xFFFF304A)),

                backgroundColor: const Color(
                  0xFFFF304A,
                ).withValues(alpha: 0.10),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),

                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDemoAlarm() async {
    if (!_demoAlarmEnabled) {
      setState(() => _demoAlarmEnabled = true);
      return;
    }

    final wasRunning = _demoAlertRunning;
    if (wasRunning) ++_demoAlertGeneration;
    setState(() => _demoAlarmEnabled = false);

    if (!wasRunning) return;

    try {
      await _demoAudioPlayer.stop();
    } catch (error) {
      debugPrint('DLOG DEMO ALARM STOP ERROR: $error');
    }
    if (!mounted) return;
    setState(() => _demoAlertRunning = false);
  }

  Future<void> _runDemoAlert({required String maintenanceItem}) async {
    if (_demoAlertCount >= 3 || _demoAlertRunning || !mounted) return;

    final runGeneration = ++_demoAlertGeneration;
    final tapNumber = _demoAlertCount + 1;
    setState(() {
      _demoAlertCount = tapNumber;
      _demoAlertRunning = true;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 15),
          backgroundColor: const Color(0xFF9D1B31),
          content: Text(
            'GRACE PERIOD ALERT $tapNumber/3 • $maintenanceItem needs service',
          ),
        ),
      );

    try {
      final permitted = await _notificationService.requestPermission();
      if (!mounted || runGeneration != _demoAlertGeneration) return;
      if (permitted) {
        await _notificationService.showDemoAlert(
          tapNumber: tapNumber,
          maintenanceItem: maintenanceItem,
        );
      }
      if (!mounted || runGeneration != _demoAlertGeneration) return;

      if (_demoAlarmEnabled) {
        await _demoAudioPlayer.setVolume(1.0);
        if (!mounted ||
            runGeneration != _demoAlertGeneration ||
            !_demoAlarmEnabled) {
          return;
        }
        await _demoAudioPlayer.play(AssetSource('audio/grace_period_beep.wav'));
      }
      await Future<void>.delayed(const Duration(seconds: 15));
      if (runGeneration != _demoAlertGeneration) return;
      if (_demoAlarmEnabled) await _demoAudioPlayer.stop();
    } catch (error) {
      debugPrint('DLOG DEMO ALERT ERROR: $error');
    } finally {
      if (mounted && runGeneration == _demoAlertGeneration) {
        setState(() => _demoAlertRunning = false);
      }
    }
  }

  Widget _graceBar(double usedRatio) {
    return SizedBox(
      height: 18,

      child: Stack(
        alignment: Alignment.centerLeft,

        children: [
          Container(
            height: 9,

            width: double.infinity,

            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),

              borderRadius: BorderRadius.circular(20),

              border: Border.all(
                color: const Color(0xFFFF304A).withValues(alpha: 0.22),
              ),
            ),
          ),

          FractionallySizedBox(
            widthFactor: usedRatio,

            child: Container(
              height: 9,

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),

                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF8E1829),

                    Color(0xFFFF304A),

                    Color(0xFFFF6A72),
                  ],
                ),

                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF304A).withValues(alpha: 0.38),

                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================\

  // VIEW MAINTENANCE\

  // ============================================================\

  Widget _viewAllMaintenanceButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTap: () async {
        await DLogNavigation.push(
          context,
          MaintenanceListScreen(vehicle: _vehicle),
        );
        if (mounted) await _loadMaintenanceData();
      },

      child: Container(
        width: double.infinity,

        height: 52,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),

          color: Colors.white.withValues(alpha: 0.045),

          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            const Text(
              'VIEW ALL MAINTENANCE',

              style: TextStyle(
                color: Colors.white,

                fontSize: 12,

                fontWeight: FontWeight.w800,

                letterSpacing: 0.6,
              ),
            ),

            const SizedBox(width: 9),

            Icon(
              Icons.arrow_forward_rounded,

              color: Colors.white.withValues(alpha: 0.8),

              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================

  // BOTTOM NAVIGATION

  // ============================================================

  Widget _bottomNavigationPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),

      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),

        child: Container(
          height: 68,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),

            gradient: LinearGradient(
              begin: Alignment.topLeft,

              end: Alignment.bottomRight,

              colors: [
                Colors.white.withValues(alpha: 0.095),

                Colors.white.withValues(alpha: 0.035),

                DLogColors.burgundy.withValues(alpha: 0.055),
              ],
            ),

            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),

              width: 1,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),

                blurRadius: 22,

                spreadRadius: 1,

                offset: const Offset(0, 8),
              ),
            ],
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,

            children: [
              _navItem(
                icon: Icons.home_rounded,

                label: 'Home',

                selected: true,

                onTap: () {},
              ),

              _navItem(
                icon: Icons.directions_car_filled_rounded,

                label: 'Garage',

                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GarageScreen()),
                  );
                  if (mounted) await _loadMaintenanceData();
                },
              ),

              _navItem(
                icon: Icons.menu_book_rounded,

                label: 'Encyclopedia',

                onTap: () =>
                    DLogNavigation.push(context, const EncyclopediaScreen()),
              ),

              _navItem(
                icon: Icons.sos_rounded,

                label: 'SOS',

                onTap: () => DLogNavigation.push(context, const SosScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,

    required String label,

    required VoidCallback onTap,

    bool selected = false,
  }) {
    return GestureDetector(
      onTap: onTap,

      behavior: HitTestBehavior.opaque,

      child: SizedBox(
        width: 70,

        height: 60,

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,

              color: selected
                  ? DLogColors.burgundy
                  : Colors.white.withValues(alpha: 0.62),

              size: 21,
            ),

            const SizedBox(height: 4),

            Text(
              label,

              textAlign: TextAlign.center,

              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.48),

                fontSize: 9,

                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
