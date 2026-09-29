import 'package:flutter/material.dart';

import '../../models/maintenance_rule.dart';
import '../../services/maintenance_status_service.dart';
import '../../services/maintenance_calculator.dart';
import '../../services/vehicle_status_rollup.dart';
import '../../theme/dlog_colors.dart';
import '../../theme/maintenance_status_style.dart';
import '../../widgets/dlog_background.dart';

class VehicleStatusScreen extends StatefulWidget {
  const VehicleStatusScreen({super.key, required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  State<VehicleStatusScreen> createState() => _VehicleStatusScreenState();
}

class _VehicleStatusScreenState extends State<VehicleStatusScreen> {
  bool _loading = true;

  String? _error;

  List<MaintenanceResult> _results = [];

  Map<String, dynamic>? _latestVehicleData;

  final MaintenanceStatusService _maintenanceStatusService =
      const MaintenanceStatusService();

  Map<String, dynamic> get _vehicle => _latestVehicleData ?? widget.vehicle;

  String get _vehicleName {
    final manufacturer = _vehicle['manufacturer']?.toString() ?? '';

    final model = _vehicle['model']?.toString() ?? '';

    final name = '$manufacturer $model'.trim();

    return name.isEmpty ? 'YOUR VEHICLE' : name;
  }

  @override
  void initState() {
    super.initState();

    _loadStatus();
  }

  // ============================================================
  // LOAD SHARED MAINTENANCE STATUS
  // ============================================================
  //
  // IMPORTANT:
  //
  // Vehicle Status does NOT calculate maintenance independently.
  //
  // It asks MaintenanceStatusService for the exact same
  // MaintenanceResult list that will also be used by:
  //
  // - Home
  // - Maintenance Overview
  // - Maintenance cards
  // - future simulator
  // - future notifications
  //
  // This keeps every screen on the same source of truth.

  Future<void> _loadStatus() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await _maintenanceStatusService.loadForVehicle(_vehicle);

      if (!mounted) return;

      setState(() {
        _latestVehicleData = snapshot.vehicle;
        _results = snapshot.results;
        _loading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      debugPrint('DLOG VEHICLE STATUS ERROR: $e');

      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        _results = [];
        _loading = false;
        _error = 'Unable to calculate vehicle status right now.';
      });
    }
  }

  List<_VehicleStatusItem> get _items =>
      VehicleStatusRollup.fromResults(_results)
          .map(
            (item) => _VehicleStatusItem(
              title: item.title,
              status: item.status,
              icon: _iconFor(item.title),
            ),
          )
          .toList(growable: false);

  IconData _iconFor(String title) => switch (title) {
    'Initial Service' => Icons.build_rounded,
    'Engine Oil' => Icons.opacity_rounded,
    'Tires' => Icons.tire_repair_rounded,
    'Brake Pads' => Icons.album_rounded,
    'Battery' => Icons.battery_full_rounded,
    'Engine' => Icons.settings_rounded,
    'Transmission' => Icons.tune_rounded,
    'Fluids' => Icons.water_drop_rounded,
    'Cooling System' => Icons.ac_unit_rounded,
    _ => Icons.build_circle_outlined,
  };

  // ============================================================
  // STATUS COLORS
  // ============================================================

  Color _statusColor(MaintenanceStatus status) =>
      MaintenanceStatusStyle.colorFor(status);

  String _statusLabel(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.allGood:
        return 'GOOD';

      case MaintenanceStatus.dueSoon:
        return 'DUE SOON';

      case MaintenanceStatus.dueNow:
        return 'SERVICE DUE';

      case MaintenanceStatus.gracePeriod:
        return 'GRACE PERIOD';
    }
  }

  // ============================================================
  // STATUS LIGHTS
  // ============================================================

  Widget _statusLights(MaintenanceStatus status) {
    final color = _statusColor(status);

    // Green  = 3 green glowing
    // Yellow = 3 yellow glowing
    // Orange = 2 orange glowing + 1 off
    // Red    = 1 red glowing + 2 off

    final litCount = switch (status) {
      MaintenanceStatus.allGood => 3,
      MaintenanceStatus.dueSoon => 3,
      MaintenanceStatus.dueNow => 2,
      MaintenanceStatus.gracePeriod => 1,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final isLit = index < litCount;

        return Container(
          width: 15,
          height: 15,
          margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLit ? color : const Color(0xFF252B2E),
            border: Border.all(
              color: isLit
                  ? color.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.14),
            ),
            boxShadow: isLit
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.72),
                      blurRadius: 18,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================

  Widget _statusCard(_VehicleStatusItem item) {
    final color = _statusColor(item.status);

    return Container(
      height: 175,
      padding: const EdgeInsets.fromLTRB(21, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF101417),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xFF292F33),
                ),
                child: Icon(
                  item.icon,
                  color: const Color(0xFFD8DDE0),
                  size: 29,
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: _statusLights(item.status),
              ),
            ],
          ),

          const Spacer(),

          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE9E9E9),
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _statusLabel(item.status),
            style: TextStyle(
              color: color,
              fontFamily: 'Georgia',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.045),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Text(
                _vehicleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        const Text(
          'Vehicle Status',
          style: TextStyle(
            color: Color(0xFFF1F1F1),
            fontFamily: 'Georgia',
            fontSize: 36,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Current condition based on your service records',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontFamily: 'Georgia',
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR CARD
  // ============================================================

  Widget _errorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF101417),
        border: Border.all(color: DLogColors.burgundy.withValues(alpha: 0.45)),
      ),
      child: Text(
        _error ?? 'Vehicle status unavailable.',
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      backgroundColor: Colors.black,
      body: DLogBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: DLogColors.burgundy,
            backgroundColor: const Color(0xFF111315),
            onRefresh: _loadStatus,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
              children: [
                _header(),

                const SizedBox(height: 28),

                if (_loading)
                  const SizedBox(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF3155),
                      ),
                    ),
                  )
                else if (_error != null)
                  _errorCard()
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 17,
                          mainAxisSpacing: 17,
                          childAspectRatio: 0.97,
                        ),
                    itemBuilder: (context, index) {
                      return _statusCard(items[index]);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// VEHICLE STATUS ITEM
// ============================================================

class _VehicleStatusItem {
  const _VehicleStatusItem({
    required this.title,
    required this.status,
    required this.icon,
  });

  final String title;
  final MaintenanceStatus status;
  final IconData icon;
}
