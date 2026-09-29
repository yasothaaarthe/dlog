import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/maintenance_prices.dart';
import '../../services/maintenance_calculator.dart';
import '../../services/maintenance_status_service.dart';

import '../../theme/dlog_colors.dart';

import '../../widgets/dlog_background.dart';

class GarageToolsScreen extends StatelessWidget {
  const GarageToolsScreen({
    super.key,

    required this.tool,

    required this.vehicle,
  });

  final GarageTool tool;

  final Map<String, dynamic> vehicle;

  @override
  Widget build(BuildContext context) {
    switch (tool) {
      case GarageTool.mileage:
        return MileageTrackerScreen(vehicle: vehicle);

      case GarageTool.time:
        return TimeSimulatorScreen(vehicle: vehicle);

      case GarageTool.cost:
        return RepairCostEstimatorScreen(vehicle: vehicle);
    }
  }
}

enum GarageTool { mileage, time, cost }

// ============================================================

// SHARED HEADER

// ============================================================

class GarageToolHeader extends StatelessWidget {
  const GarageToolHeader({
    super.key,

    required this.title,

    required this.subtitle,
  });

  final String title;

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),

          child: Container(
            width: 46,

            height: 46,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color: Colors.white.withValues(alpha: 0.055),

              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            ),

            child: const Icon(
              Icons.arrow_back_ios_new_rounded,

              color: Colors.white,

              size: 18,
            ),
          ),
        ),

        const SizedBox(width: 15),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style: const TextStyle(
                  color: Colors.white,

                  fontSize: 25,

                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,

                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),

                  fontSize: 12,

                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================

// VEHICLE MINI HEADER

// ============================================================

class ToolVehicleCard extends StatelessWidget {
  const ToolVehicleCard({super.key, required this.vehicle});

  final Map<String, dynamic> vehicle;

  String _number(num value) {
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

  @override
  Widget build(BuildContext context) {
    final manufacturer = (vehicle['manufacturer'] ?? 'Manufacturer').toString();

    final model = (vehicle['model'] ?? 'Vehicle').toString();

    final variant = (vehicle['variant'] ?? 'Variant').toString();

    final year = (vehicle['year'] ?? '').toString();

    final mileage = (vehicle['currentMileage'] as num?) ?? 0;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        color: Colors.white.withValues(alpha: 0.035),

        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),

      child: Row(
        children: [
          Container(
            width: 52,

            height: 52,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),

              color: DLogColors.burgundy.withValues(alpha: 0.10),

              border: Border.all(
                color: DLogColors.burgundy.withValues(alpha: 0.25),
              ),
            ),

            child: const Icon(
              Icons.directions_car_filled_rounded,

              color: Colors.white,

              size: 25,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  manufacturer.toUpperCase(),

                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),

                    fontSize: 10,

                    fontWeight: FontWeight.w800,

                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  model,

                  style: const TextStyle(
                    color: Colors.white,

                    fontSize: 17,

                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '$variant • $year',

                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),

                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Text(
            '${_number(mileage)} KM',

            style: const TextStyle(
              color: Colors.white,

              fontSize: 14,

              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================

// MILEAGE TRACKER

// ============================================================

class MileageTrackerScreen extends StatefulWidget {
  const MileageTrackerScreen({super.key, required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  State<MileageTrackerScreen> createState() => _MileageTrackerScreenState();
}

class _MileageTrackerScreenState extends State<MileageTrackerScreen> {
  late double _simulatedMileage;
  late final double _startingMileage;

  StreamSubscription<Position>? _tripPositionSubscription;
  Position? _lastTripPosition;
  List<Position> _tripPositions = [];
  double _tripDistanceMeters = 0;
  int _tripDemoDistanceKm = 0;
  bool _tripStarting = false;
  bool _tripActive = false;

  double get _projectedMileage =>
      _simulatedMileage + _tripDemoDistanceKm;

  final TextEditingController _customMileageController =
      TextEditingController();

  bool _maintenanceLoading = true;
  String? _maintenanceError;
  List<MaintenanceResult> _maintenanceResults = [];
  int _maintenanceLoadGeneration = 0;
  static const MaintenanceStatusService _maintenanceStatusService =
      MaintenanceStatusService();

  @override
  void initState() {
    super.initState();

    _startingMileage =
        (widget.vehicle['currentMileage'] as num?)?.toDouble() ?? 0;
    _simulatedMileage = _startingMileage;

    _loadMaintenanceResults();
  }

  @override
  void dispose() {
    unawaited(_tripPositionSubscription?.cancel());
    _customMileageController.dispose();
    super.dispose();
  }

  Future<void> _startTrip() async {
    if (_tripStarting || _tripActive) return;

    setState(() => _tripStarting = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          _showTripMessage('Turn on Location Services to start GPS tracking.');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        if (mounted) {
          _showTripMessage(
            permission == LocationPermission.deniedForever
                ? 'Allow DLog to access Location in your device Settings, then try again.'
                : 'Location permission is needed to track a trip.',
          );
        }
        return;
      }

      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;

      final hadPreviousTripMileage = _tripDemoDistanceKm > 0;
      setState(() {
        _tripActive = true;
        _tripDistanceMeters = 0;
        _tripDemoDistanceKm = 0;
        _lastTripPosition = initialPosition;
        _tripPositions = [initialPosition];
        if (hadPreviousTripMileage) _maintenanceLoading = true;
      });
      if (hadPreviousTripMileage) _loadMaintenanceResults();

      _tripPositionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        _handleTripPosition,
        onError: (Object error) {
          debugPrint('DLOG LIVE TRIP LOCATION ERROR: $error');
          if (!mounted) return;
          _showTripMessage(
            'GPS updates stopped. Check Location Services and try again.',
          );
          _stopTrip();
        },
      );
    } catch (error) {
      debugPrint('DLOG LIVE TRIP START ERROR: $error');
      if (mounted) {
        _showTripMessage('Could not get a GPS fix. Enable Location and try again.');
      }
    } finally {
      if (mounted) setState(() => _tripStarting = false);
    }
  }

  void _handleTripPosition(Position position) {
    if (!mounted || !_tripActive || position.accuracy > 100) return;

    final previous = _lastTripPosition;
    var nextDistance = _tripDistanceMeters;
    var moved = previous == null;
    if (previous != null) {
      final segmentMeters = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      // Ignore GPS drift and extreme jumps. Emulator route segments can be
      // much longer than a few metres, so allow ordinary route updates.
      if (segmentMeters >= 3 && segmentMeters <= 50000) {
        nextDistance += segmentMeters;
        moved = true;
      }
    }

    final nextDemoDistanceKm = nextDistance <= 0
        ? 0
        : (nextDistance / 100).ceil() * 1000;
    final crossedDemoStep = nextDemoDistanceKm != _tripDemoDistanceKm;

    setState(() {
      _lastTripPosition = position;
      if (moved) {
        _tripDistanceMeters = nextDistance;
        _tripDemoDistanceKm = nextDemoDistanceKm;
        _tripPositions = [..._tripPositions, position];
        if (_tripPositions.length > 500) {
          _tripPositions = _tripPositions.sublist(_tripPositions.length - 500);
        }
      }
      if (crossedDemoStep) _maintenanceLoading = true;
    });

    // Recalculate only when the scaled demo odometer advances, rather than
    // reading the service history from Firestore for every GPS point.
    if (crossedDemoStep) _loadMaintenanceResults();
  }

  Future<void> _stopTrip() async {
    final subscription = _tripPositionSubscription;
    _tripPositionSubscription = null;
    await subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _tripActive = false;
      _lastTripPosition = null;
    });
  }

  String get _tripDistanceLabel => _tripDistanceMeters >= 1000
      ? '${(_tripDistanceMeters / 1000).toStringAsFixed(2)} km'
      : '${_tripDistanceMeters.round()} m';

  void _showTripMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _number(num value) {
    return value.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );
  }

  Future<void> _loadMaintenanceResults() async {
    final requestGeneration = ++_maintenanceLoadGeneration;
    final projectedMileage = _projectedMileage.round();
    final ruleGroupId = widget.vehicle['ruleGroupId']?.toString();
    if (ruleGroupId == null || ruleGroupId.isEmpty) {
      if (!mounted || requestGeneration != _maintenanceLoadGeneration) return;
      setState(() {
        _maintenanceResults = [];
        _maintenanceLoading = false;
        _maintenanceError =
            'Maintenance profile is not available for this vehicle.';
      });
      return;
    }

    try {
      final snapshot = await _maintenanceStatusService.loadForVehicle(
        widget.vehicle,
        currentMileageOverride: projectedMileage,
      );
      if (!mounted || requestGeneration != _maintenanceLoadGeneration) return;
      setState(() {
        _maintenanceResults = snapshot.results;
        _maintenanceLoading = false;
        _maintenanceError = snapshot.results.isEmpty
            ? 'No maintenance rules are available for this vehicle profile.'
            : null;
      });
    } catch (error) {
      debugPrint('DLOG MILEAGE SIMULATOR ERROR: $error');
      if (!mounted || requestGeneration != _maintenanceLoadGeneration) return;
      setState(() {
        _maintenanceResults = [];
        _maintenanceLoading = false;
        _maintenanceError = 'Unable to calculate maintenance right now.';
      });
    }
  }

  void _setSimulatedMileage(double value) {
    final nextMileage = value < 0 ? 0.0 : value;

    setState(() {
      _simulatedMileage = nextMileage;
      _maintenanceLoading = true;
    });

    _loadMaintenanceResults();
  }

  void _addMileage(int amount) {
    _setSimulatedMileage(_simulatedMileage + amount);
  }

  void _customMileage() {
    _customMileageController.clear();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'CUSTOM DISTANCE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: _customMileageController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Enter kilometres',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              suffixText: 'KM',
              suffixStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: DLogColors.burgundy),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
              ),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(
                  _customMileageController.text.trim(),
                );

                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid distance.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                _addMileage(value.round());
              },
              child: const Text(
                'ADD',
                style: TextStyle(
                  color: DLogColors.burgundy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _setTestOdometer() {
    _customMileageController.clear();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111416),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'SET TEST ODOMETER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: TextField(
          controller: _customMileageController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Enter simulated odometer',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            suffixText: 'KM',
            suffixStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: DLogColors.burgundy),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(
                _customMileageController.text.trim(),
              );
              if (value == null || value < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid odometer reading.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _setSimulatedMileage(value);
            },
            child: const Text(
              'SET',
              style: TextStyle(
                color: DLogColors.burgundy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetSimulation() {
    final tripSubscription = _tripPositionSubscription;
    _tripPositionSubscription = null;
    unawaited(tripSubscription?.cancel());
    setState(() {
      _simulatedMileage = _startingMileage;
      _tripActive = false;
      _lastTripPosition = null;
      _tripPositions = [];
      _tripDistanceMeters = 0;
      _tripDemoDistanceKm = 0;
      _maintenanceLoading = true;
    });

    _loadMaintenanceResults();
  }

  @override
  Widget build(BuildContext context) {
    final realMileage = _startingMileage;
    final difference = _projectedMileage - realMileage;

    return Scaffold(
      backgroundColor: Colors.black,
      body: DLogBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GarageToolHeader(
                  title: 'Mileage Tracker',
                  subtitle: 'Test mileage and real trips',
                ),
                const SizedBox(height: 22),
                ToolVehicleCard(vehicle: widget.vehicle),
                const SizedBox(height: 22),
                _mileageDisplay(
                  realMileage: realMileage,
                  difference: difference,
                ),
                const SizedBox(height: 18),
                _maintenanceImpactCard(),
                const SizedBox(height: 22),
                _sectionTitle(
                  'MILEAGE SIMULATOR',
                  'Test how maintenance changes as mileage increases',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _jumpButton('+1,000', () => _addMileage(1000)),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _jumpButton('+5,000', () => _addMileage(5000)),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: _jumpButton('+10,000', () => _addMileage(10000)),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _jumpButton('+20,000', () => _addMileage(20000)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _customMileage,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('CUSTOM DISTANCE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _setTestOdometer,
                    icon: const Icon(Icons.speed_rounded, size: 18),
                    label: const Text('SET TEST ODOMETER'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DLogColors.burgundy,
                      side: BorderSide(
                        color: DLogColors.burgundy.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _resetSimulation,
                  child: Text(
                    'RESET SIMULATION',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _liveTripCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mileageDisplay({
    required double realMileage,
    required double difference,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF171A1C),
            DLogColors.burgundy.withValues(alpha: 0.11),
            const Color(0xFF080909),
          ],
        ),
        border: Border.all(color: DLogColors.burgundy.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            'SIMULATED ODOMETER',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _number(_projectedMileage),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 43,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'KM',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.black.withValues(alpha: 0.25),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REAL ODOMETER',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_number(realMileage)} KM',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            difference > 0
                ? '+${_number(difference)} KM simulated'
                : difference < 0
                ? '${_number(difference)} KM test projection'
                : 'No simulated distance added',
            style: TextStyle(
              color: difference != 0
                  ? DLogColors.burgundy
                  : Colors.white.withValues(alpha: 0.40),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _maintenanceImpactCard() {
    final allGood = MaintenanceCalculator.allGoodCount(_maintenanceResults);
    final dueSoon = MaintenanceCalculator.dueSoonCount(_maintenanceResults);
    final dueNow = MaintenanceCalculator.dueNowCount(_maintenanceResults);
    final grace = MaintenanceCalculator.gracePeriodCount(_maintenanceResults);

    MaintenanceResult? nextItem;

    for (final result in _maintenanceResults) {
      if (result.nextDueMileage == null) continue;

      if (nextItem == null ||
          result.nextDueMileage! < nextItem.nextDueMileage!) {
        nextItem = result;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DLogColors.burgundy.withValues(alpha: 0.13),
                  border: Border.all(
                    color: DLogColors.burgundy.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE MAINTENANCE IMPACT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Calculated from the DLog maintenance engine',
                      style: TextStyle(color: Colors.white54, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (_maintenanceLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.7,
                    color: Colors.white54,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_maintenanceError != null) ...[
            Text(
              _maintenanceError!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ] else if (_maintenanceResults.isEmpty) ...[
            Text(
              'No maintenance rules are available for this vehicle profile yet.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: _statusMiniCard('GOOD', allGood, Colors.white)),
                const SizedBox(width: 7),
                Expanded(
                  child: _statusMiniCard('SOON', dueSoon, Colors.amberAccent),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _statusMiniCard('DUE', dueNow, Colors.redAccent),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _statusMiniCard('GRACE', grace, DLogColors.burgundy),
                ),
              ],
            ),
            if (nextItem != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black.withValues(alpha: 0.24),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_repeat_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEXT MILEAGE EVENT',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.42),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            nextItem.rule.maintenanceItem,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_number(nextItem.nextDueMileage!)} KM',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Text(
            'Simulation only. GPS demo mileage updates this projection and maintenance status, not the saved vehicle odometer.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusMiniCard(String label, int count, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: Colors.black.withValues(alpha: 0.22),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: accent,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jumpButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 58,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: 0.025),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.11)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          '$label KM',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _liveTripCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.055),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.gps_fixed_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIVE TRIP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Foreground GPS tracking',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: const Text(
                  'GPS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 105,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              color: const Color(0xFF090B0C),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: CustomPaint(
              painter: _RoutePainter(positions: _tripPositions),
              child: Center(
                child: Text(
                  _tripActive && _tripPositions.length < 2
                      ? 'WAITING FOR GPS'
                      : _tripPositions.length >= 2
                      ? ''
                      : 'ROUTE PREVIEW',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
          if (_tripPositions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GPS ROUTE DISTANCE',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  _tripDistanceLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DEMO ODOMETER ADD',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '+${_number(_tripDemoDistanceKm)} KM',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Demo scale: each started 100 m of GPS route adds 1,000 simulated KM.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _tripStarting
                  ? null
                  : _tripActive
                  ? _stopTrip
                  : _startTrip,
              icon: Icon(
                _tripStarting
                    ? Icons.gps_not_fixed_rounded
                    : _tripActive
                    ? Icons.stop_circle_outlined
                    : Icons.navigation_rounded,
                size: 18,
              ),
              label: Text(
                _tripStarting
                    ? 'STARTING GPS…'
                    : _tripActive
                    ? 'END TRIP'
                    : 'START TRIP',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: DLogColors.burgundy.withValues(alpha: 0.55),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TimeSimulatorScreen extends StatefulWidget {
  const TimeSimulatorScreen({super.key, required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  State<TimeSimulatorScreen> createState() => _TimeSimulatorScreenState();
}

class _TimeSimulatorScreenState extends State<TimeSimulatorScreen> {
  static const MaintenanceStatusService _maintenanceStatusService =
      MaintenanceStatusService();

  late final DateTime _baseDate;
  int _months = 0;
  bool _maintenanceLoading = true;
  String? _maintenanceError;
  List<MaintenanceResult> _results = [];
  int _maintenanceLoadGeneration = 0;

  DateTime get _simulatedDate =>
      MaintenanceCalculator.addCalendarMonths(_baseDate, _months);

  @override
  void initState() {
    super.initState();
    _baseDate = DateTime.now();
    _loadMaintenanceResults();
  }

  Future<void> _loadMaintenanceResults() async {
    final requestGeneration = ++_maintenanceLoadGeneration;
    final simulatedDate = _simulatedDate;
    final ruleGroupId = widget.vehicle['ruleGroupId']?.toString();
    if (ruleGroupId == null || ruleGroupId.isEmpty) {
      if (!mounted || requestGeneration != _maintenanceLoadGeneration) return;
      setState(() {
        _results = [];
        _maintenanceLoading = false;
        _maintenanceError =
            'Maintenance profile is not available for this vehicle.';
      });
      return;
    }

    try {
      final snapshot = await _maintenanceStatusService.loadForVehicle(
        widget.vehicle,
        currentDateOverride: simulatedDate,
      );
      if (!mounted || requestGeneration != _maintenanceLoadGeneration) return;
      setState(() {
        _results = snapshot.results;
        _maintenanceLoading = false;
        _maintenanceError = snapshot.results.isEmpty
            ? 'No maintenance rules are available for this vehicle profile.'
            : null;
      });
    } catch (error) {
      debugPrint('DLOG TIME SIMULATOR ERROR: $error');
      if (!mounted || requestGeneration != _maintenanceLoadGeneration) return;
      setState(() {
        _results = [];
        _maintenanceLoading = false;
        _maintenanceError = 'Unable to calculate maintenance right now.';
      });
    }
  }

  void _addMonths(int amount) {
    setState(() {
      _months += amount;
      _maintenanceLoading = true;
    });
    _loadMaintenanceResults();
  }

  void _reset() {
    setState(() {
      _months = 0;
      _maintenanceLoading = true;
    });
    _loadMaintenanceResults();
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DLogBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GarageToolHeader(
                  title: 'Time Simulator',
                  subtitle: 'Fast-forward maintenance timing',
                ),
                const SizedBox(height: 22),
                ToolVehicleCard(vehicle: widget.vehicle),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF171A1C),
                        DLogColors.burgundy.withValues(alpha: 0.10),
                        const Color(0xFF080909),
                      ],
                    ),
                    border: Border.all(
                      color: DLogColors.burgundy.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SIMULATED DATE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.7,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatDate(_simulatedDate),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _months == 0
                            ? 'REAL DATE'
                            : '+$_months MONTHS FROM TODAY',
                        style: TextStyle(
                          color: _months == 0
                              ? Colors.white54
                              : DLogColors.burgundy,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'FAST FORWARD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _timeButton('+1 MONTH', () => _addMonths(1)),
                _timeButton('+3 MONTHS', () => _addMonths(3)),
                _timeButton('+6 MONTHS', () => _addMonths(6)),
                _timeButton('+12 MONTHS', () => _addMonths(12)),
                Center(
                  child: TextButton(
                    onPressed: _reset,
                    child: Text(
                      'RESET SIMULATION',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _timeImpactCard(),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.03),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Projection only. It uses the same DLog rules and recorded service history; your real vehicle data is not changed.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeImpactCard() {
    final allGood = MaintenanceCalculator.allGoodCount(_results);
    final dueSoon = MaintenanceCalculator.dueSoonCount(_results);
    final dueNow = MaintenanceCalculator.dueNowCount(_results);
    final grace = MaintenanceCalculator.gracePeriodCount(_results);

    MaintenanceResult? nextDateItem;
    for (final result in _results) {
      final dueDate = result.nextDueDate;
      if (dueDate == null) continue;
      if (nextDateItem == null || dueDate.isBefore(nextDateItem.nextDueDate!)) {
        nextDateItem = result;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MAINTENANCE ON THIS DATE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Calculated using recorded service dates and DLog intervals.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 14),
          if (_maintenanceLoading)
            const Center(child: CircularProgressIndicator())
          else if (_maintenanceError != null)
            Text(
              _maintenanceError!,
              style: const TextStyle(color: DLogColors.grey, fontSize: 11),
            )
          else ...[
            Row(
              children: [
                _timeStatusCount('GOOD', allGood, Colors.greenAccent),
                const SizedBox(width: 6),
                _timeStatusCount('SOON', dueSoon, Colors.amberAccent),
                const SizedBox(width: 6),
                _timeStatusCount('DUE', dueNow, Colors.redAccent),
                const SizedBox(width: 6),
                _timeStatusCount('GRACE', grace, const Color(0xFFFF5265)),
              ],
            ),
            const SizedBox(height: 12),
            if (nextDateItem == null)
              const Text(
                'No verified service date is available for a date-based next-service estimate.',
                style: TextStyle(
                  color: DLogColors.grey,
                  fontSize: 10,
                  height: 1.4,
                ),
              )
            else
              Text(
                'Next recorded date-based service: ${nextDateItem.rule.maintenanceItem} • ${_formatDate(nextDateItem.nextDueDate!)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _timeStatusCount(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.025),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.11)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class RepairCostEstimatorScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const RepairCostEstimatorScreen({super.key, required this.vehicle});

  @override
  State<RepairCostEstimatorScreen> createState() =>
      _RepairCostEstimatorScreenState();
}

class _RepairCostEstimatorScreenState extends State<RepairCostEstimatorScreen> {
  final TextEditingController _quoteController = TextEditingController();

  final TextEditingController _partsController = TextEditingController();

  final TextEditingController _labourController = TextEditingController();

  final TextEditingController _otherController = TextEditingController();

  String _selectedMaintenanceItem = 'Engine Oil & Oil Filter';

  String? _resultTitle;

  String? _resultDescription;

  bool? _quoteIsWithinRange;

  double _parts = 0;

  double _labour = 0;

  double _other = 0;

  String get _model {
    return widget.vehicle['model']?.toString() ?? 'Vehicle';
  }

  String get _variant {
    return widget.vehicle['variant']?.toString() ?? '';
  }

  String get _year {
    return widget.vehicle['year']?.toString() ?? '';
  }

  MaintenancePriceRange? get _referencePrice {
    return MaintenancePrices.findPrice(
      maintenanceItem: _selectedMaintenanceItem,

      model: _model,
    );
  }

  double get _manualEstimateTotal {
    return _parts + _labour + _other;
  }

  double? get _enteredQuote {
    final value = double.tryParse(
      _quoteController.text.trim().replaceAll(',', ''),
    );

    return value;
  }

  @override
  void dispose() {
    _quoteController.dispose();

    _partsController.dispose();

    _labourController.dispose();

    _otherController.dispose();

    super.dispose();
  }

  // ============================================================

  // QUOTE CHECK

  // ============================================================

  void _checkQuote() {
    FocusScope.of(context).unfocus();

    final quote = _enteredQuote;

    final reference = _referencePrice;

    if (quote == null || quote <= 0) {
      setState(() {
        _resultTitle = 'ENTER A VALID QUOTE';

        _resultDescription = 'Enter the workshop quotation amount first.';

        _quoteIsWithinRange = null;
      });

      return;
    }

    if (reference == null) {
      setState(() {
        _resultTitle = 'NO REFERENCE RANGE';

        _resultDescription =
            'DLog does not currently have a reliable reference '
            'price for this maintenance item and vehicle.';

        _quoteIsWithinRange = null;
      });

      return;
    }

    final upper = reference.high;

    final significantlyAbove = quote > upper * 1.25;

    setState(() {
      if (quote <= upper) {
        _resultTitle = 'WITHIN REFERENCE RANGE';

        _resultDescription =
            'The quotation is within or below the current '
            'DLog reference range of ${reference.formattedRange}.';

        _quoteIsWithinRange = true;
      } else if (!significantlyAbove) {
        _resultTitle = 'ABOVE REFERENCE RANGE';

        _resultDescription =
            'The quotation is above the current DLog reference '
            'range. Check the parts, labour and service scope.';

        _quoteIsWithinRange = false;
      } else {
        _resultTitle = 'SIGNIFICANTLY ABOVE RANGE';

        _resultDescription =
            'The quotation is substantially above the current '
            'DLog reference range. Ask the workshop for an itemised quote.';

        _quoteIsWithinRange = false;
      }
    });
  }

  void _clearQuoteCheck() {
    setState(() {
      _quoteController.clear();

      _resultTitle = null;

      _resultDescription = null;

      _quoteIsWithinRange = null;
    });
  }

  // ============================================================

  // MANUAL COST BREAKDOWN

  // ============================================================

  void _calculateManualEstimate() {
    setState(() {
      _parts = double.tryParse(_partsController.text.trim()) ?? 0;

      _labour = double.tryParse(_labourController.text.trim()) ?? 0;

      _other = double.tryParse(_otherController.text.trim()) ?? 0;
    });
  }

  // ============================================================

  // UI

  // ============================================================

  @override
  Widget build(BuildContext context) {
    final reference = _referencePrice;

    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              _qcHeader(),

              const SizedBox(height: 24),

              _qcVehicleCard(),

              const SizedBox(height: 24),

              _qcSectionLabel('QUOTE CHECK'),

              const SizedBox(height: 10),

              _qcMaintenanceDropdown(),

              const SizedBox(height: 16),

              if (reference != null)
                _qcReferenceCard(reference)
              else
                _qcNoReferenceCard(),

              const SizedBox(height: 18),

              _qcQuoteInput(),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _qcPrimaryButton(
                      label: 'CHECK QUOTE',

                      icon: Icons.fact_check_rounded,

                      onTap: _checkQuote,
                    ),
                  ),

                  const SizedBox(width: 10),

                  SizedBox(
                    width: 54,

                    height: 54,

                    child: _qcSecondaryButton(
                      icon: Icons.refresh_rounded,

                      onTap: _clearQuoteCheck,
                    ),
                  ),
                ],
              ),

              if (_resultTitle != null) ...[
                const SizedBox(height: 18),

                _qcResultCard(),
              ],

              const SizedBox(height: 30),

              _qcSectionLabel('MANUAL ESTIMATE'),

              const SizedBox(height: 8),

              Text(
                'Break a repair quote into parts, labour and other costs.',

                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),

                  fontSize: 14,

                  height: 1.4,
                ),
              ),

              const SizedBox(height: 16),

              _qcMoneyInput(
                controller: _partsController,

                label: 'PARTS',

                hint: '0.00',
              ),

              const SizedBox(height: 12),

              _qcMoneyInput(
                controller: _labourController,

                label: 'LABOUR',

                hint: '0.00',
              ),

              const SizedBox(height: 12),

              _qcMoneyInput(
                controller: _otherController,

                label: 'OTHER',

                hint: '0.00',
              ),

              const SizedBox(height: 16),

              _qcPrimaryButton(
                label: 'CALCULATE TOTAL',

                icon: Icons.calculate_rounded,

                onTap: _calculateManualEstimate,
              ),

              const SizedBox(height: 16),

              _qcTotalCard(),

              const SizedBox(height: 24),

              _qcDisclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================

  // HEADER

  // ============================================================

  Widget _qcHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),

          child: Container(
            width: 44,

            height: 44,

            decoration: BoxDecoration(
              color: const Color(0xFF111316),

              borderRadius: BorderRadius.circular(14),

              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),

            child: const Icon(
              Icons.arrow_back_rounded,

              color: Colors.white,

              size: 21,
            ),
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'QUOTE CHECK',

                style: const TextStyle(
                  color: Colors.white,

                  fontSize: 22,

                  fontWeight: FontWeight.w900,

                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                'Check a workshop quotation',

                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),

                  fontSize: 13,

                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================

  // VEHICLE CARD

  // ============================================================

  Widget _qcVehicleCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),

        gradient: LinearGradient(
          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [const Color(0xFF181B1F), const Color(0xFF090A0C)],
        ),

        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D2035).withValues(alpha: 0.10),

            blurRadius: 24,

            spreadRadius: -8,
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 52,

            height: 52,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color: const Color(0xFF8D2035).withValues(alpha: 0.14),

              border: Border.all(
                color: const Color(0xFF8D2035).withValues(alpha: 0.28),
              ),
            ),

            child: const Icon(
              Icons.directions_car_filled_rounded,

              color: Colors.white,

              size: 24,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  _model.toUpperCase(),

                  style: const TextStyle(
                    color: Colors.white,

                    fontSize: 18,

                    fontWeight: FontWeight.w900,

                    letterSpacing: 0.7,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  [
                    if (_variant.isNotEmpty) _variant,

                    if (_year.isNotEmpty) _year,
                  ].join(' • '),

                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),

                    fontSize: 13,

                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.verified_rounded,

            color: Color(0xFFB8B8B8),

            size: 20,
          ),
        ],
      ),
    );
  }

  // ============================================================

  // SECTION LABEL

  // ============================================================

  Widget _qcSectionLabel(String text) {
    return Text(
      text,

      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.48),

        fontSize: 12,

        fontWeight: FontWeight.w900,

        letterSpacing: 1.5,
      ),
    );
  }

  // ============================================================

  // MAINTENANCE DROPDOWN

  // ============================================================

  Widget _qcMaintenanceDropdown() {
    final items = MaintenancePrices.all
        .map((item) => item.maintenanceItem)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101215),

        borderRadius: BorderRadius.circular(17),

        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),

      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMaintenanceItem,

          isExpanded: true,

          dropdownColor: const Color(0xFF15171A),

          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,

            color: Colors.white70,
          ),

          style: const TextStyle(
            color: Colors.white,

            fontSize: 15,

            fontWeight: FontWeight.w700,
          ),

          items: items.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),

          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedMaintenanceItem = value;

              _resultTitle = null;

              _resultDescription = null;

              _quoteIsWithinRange = null;
            });
          },
        ),
      ),
    );
  }

  // ============================================================

  // REFERENCE PRICE CARD

  // ============================================================

  Widget _qcReferenceCard(MaintenancePriceRange reference) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        color: const Color(0xFF111316),

        border: Border.all(
          color: const Color(0xFF8D2035).withValues(alpha: 0.28),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,

                color: Color(0xFFB8B8B8),

                size: 19,
              ),

              const SizedBox(width: 9),

              Text(
                'DLOG REFERENCE RANGE',

                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),

                  fontSize: 11,

                  fontWeight: FontWeight.w900,

                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Text(
            reference.formattedRange,

            style: const TextStyle(
              color: Colors.white,

              fontSize: 28,

              fontWeight: FontWeight.w900,

              letterSpacing: 0.4,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            reference.basis,

            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),

              fontSize: 12,

              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qcNoReferenceCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        color: const Color(0xFF111316),

        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.info_outline_rounded,

            color: Colors.white54,

            size: 21,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'DLog does not currently have a reliable '
              'vehicle-specific reference range for this item. '
              'The quote can still be recorded, but DLog will '
              'not invent a comparison price.',

              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),

                fontSize: 13,

                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================

  // QUOTE INPUT

  // ============================================================

  Widget _qcQuoteInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          'WORKSHOP QUOTE',

          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),

            fontSize: 11,

            fontWeight: FontWeight.w900,

            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101215),

            borderRadius: BorderRadius.circular(17),

            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),

          child: TextField(
            controller: _quoteController,

            keyboardType: const TextInputType.numberWithOptions(decimal: true),

            style: const TextStyle(
              color: Colors.white,

              fontSize: 19,

              fontWeight: FontWeight.w800,
            ),

            decoration: InputDecoration(
              prefixText: 'RM ',

              prefixStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),

                fontSize: 17,

                fontWeight: FontWeight.w700,
              ),

              hintText: 'Enter workshop quote',

              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),

                fontSize: 15,

                fontWeight: FontWeight.w500,
              ),

              border: InputBorder.none,

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 17,

                vertical: 17,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================

  // RESULT

  // ============================================================

  Widget _qcResultCard() {
    final isGood = _quoteIsWithinRange == true;

    final hasComparison = _quoteIsWithinRange != null;

    final title = _resultTitle ?? '';

    final description = _resultDescription ?? '';

    final IconData icon;

    if (!hasComparison) {
      icon = Icons.info_outline_rounded;
    } else if (isGood) {
      icon = Icons.check_circle_outline_rounded;
    } else {
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(19),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),

        color: const Color(0xFF121416),

        border: Border.all(
          color: isGood
              ? const Color(0xFF6D8B75).withValues(alpha: 0.45)
              : const Color(0xFF8D2035).withValues(alpha: 0.40),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Icon(
                icon,

                color: isGood
                    ? const Color(0xFFA7C2AE)
                    : const Color(0xFFB7B7B7),

                size: 26,
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  title,

                  style: const TextStyle(
                    color: Colors.white,

                    fontSize: 15,

                    fontWeight: FontWeight.w900,

                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            description,

            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),

              fontSize: 13,

              height: 1.45,
            ),
          ),

          if (_enteredQuote != null && _referencePrice != null) ...[
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _qcMiniValue(
                    label: 'YOUR QUOTE',

                    value: 'RM${_enteredQuote!.toStringAsFixed(2)}',
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _qcMiniValue(
                    label: 'REFERENCE HIGH',

                    value: 'RM${_referencePrice!.high}',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _qcMiniValue({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),

        borderRadius: BorderRadius.circular(13),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            label,

            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),

              fontSize: 9,

              fontWeight: FontWeight.w800,

              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            value,

            style: const TextStyle(
              color: Colors.white,

              fontSize: 15,

              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================

  // MANUAL MONEY INPUT

  // ============================================================

  Widget _qcMoneyInput({
    required TextEditingController controller,

    required String label,

    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101215),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),

      child: TextField(
        controller: controller,

        keyboardType: const TextInputType.numberWithOptions(decimal: true),

        style: const TextStyle(
          color: Colors.white,

          fontSize: 15,

          fontWeight: FontWeight.w700,
        ),

        decoration: InputDecoration(
          labelText: label,

          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),

            fontSize: 11,

            fontWeight: FontWeight.w800,

            letterSpacing: 0.8,
          ),

          hintText: hint,

          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.18)),

          prefixText: 'RM ',

          prefixStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),

            fontSize: 14,

            fontWeight: FontWeight.w700,
          ),

          border: InputBorder.none,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,

            vertical: 15,
          ),
        ),
      ),
    );
  }

  // ============================================================

  // TOTAL

  // ============================================================

  Widget _qcTotalCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(19),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),

        gradient: const LinearGradient(
          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [Color(0xFF191B1F), Color(0xFF0D0E10)],
        ),

        border: Border.all(
          color: const Color(0xFF8D2035).withValues(alpha: 0.30),
        ),
      ),

      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'ESTIMATED TOTAL',

                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),

                    fontSize: 10,

                    fontWeight: FontWeight.w900,

                    letterSpacing: 1.1,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'RM${_manualEstimateTotal.toStringAsFixed(2)}',

                  style: const TextStyle(
                    color: Colors.white,

                    fontSize: 27,

                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.receipt_long_rounded,

            color: Colors.white38,

            size: 26,
          ),
        ],
      ),
    );
  }

  // ============================================================

  // BUTTONS

  // ============================================================

  Widget _qcPrimaryButton({
    required String label,

    required IconData icon,

    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 54,

      child: Material(
        color: const Color(0xFF8D2035),

        borderRadius: BorderRadius.circular(17),

        child: InkWell(
          onTap: onTap,

          borderRadius: BorderRadius.circular(17),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Icon(icon, color: Colors.white, size: 19),

              const SizedBox(width: 9),

              Text(
                label,

                style: const TextStyle(
                  color: Colors.white,

                  fontSize: 13,

                  fontWeight: FontWeight.w900,

                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qcSecondaryButton({
    required IconData icon,

    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF111316),

      borderRadius: BorderRadius.circular(16),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(16),

        child: Icon(icon, color: Colors.white70, size: 21),
      ),
    );
  }

  // ============================================================

  // DISCLAIMER

  // ============================================================

  Widget _qcDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),

        borderRadius: BorderRadius.circular(15),

        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.info_outline_rounded,

            color: Colors.white38,

            size: 18,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'DLog reference prices are intended to help '
              'users understand a quotation. They are not a '
              'guaranteed market price. Workshop, location, '
              'parts brand, labour and service scope can change '
              'the final amount.',

              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),

                fontSize: 11,

                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================

// SIMPLE ROUTE VISUAL

// ============================================================

class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.positions});

  final List<Position> positions;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final routePoints = <Offset>[];

    if (positions.length >= 2) {
      final minLatitude = positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
      final maxLatitude = positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
      final minLongitude = positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
      final maxLongitude = positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
      final latitudeSpan = (maxLatitude - minLatitude).abs();
      final longitudeSpan = (maxLongitude - minLongitude).abs();

      for (final position in positions) {
        final x = longitudeSpan == 0
            ? size.width / 2
            : 8 + ((position.longitude - minLongitude) / longitudeSpan) * (size.width - 16);
        final y = latitudeSpan == 0
            ? size.height / 2
            : size.height - 8 - ((position.latitude - minLatitude) / latitudeSpan) * (size.height - 16);
        routePoints.add(Offset(x, y));
      }
      path.moveTo(routePoints.first.dx, routePoints.first.dy);
      for (final point in routePoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
    } else if (positions.length == 1) {
      routePoints.add(Offset(size.width / 2, size.height / 2));
      path.moveTo(routePoints.single.dx, routePoints.single.dy);
    } else {
      routePoints.add(Offset(size.width * 0.12, size.height * 0.72));
      routePoints.add(Offset(size.width * 0.91, size.height * 0.25));
      path.moveTo(size.width * 0.12, size.height * 0.72);
      path.cubicTo(
        size.width * 0.25,
        size.height * 0.20,
        size.width * 0.43,
        size.height * 0.82,
        size.width * 0.58,
        size.height * 0.38,
      );
      path.cubicTo(
        size.width * 0.70,
        size.height * 0.05,
        size.width * 0.82,
        size.height * 0.80,
        size.width * 0.91,
        size.height * 0.25,
      );
    }

    final paint = Paint()
      ..color = DLogColors.burgundy.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(routePoints.first, 4, dotPaint);
    canvas.drawCircle(routePoints.last, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.positions != positions ||
      oldDelegate.positions.length != positions.length;
}
