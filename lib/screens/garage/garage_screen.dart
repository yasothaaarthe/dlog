import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../repositories/vehicle_repository.dart';
import '../../navigation/dlog_navigation.dart';
import '../../theme/dlog_colors.dart';
import '../../widgets/dlog_background.dart';
import '../onboarding/vehicle_onboarding_screen.dart';
import '../encyclopedia/encyclopedia_screen.dart';
import '../sos/sos_screen.dart';
import 'vehicle_documents_screen.dart';
import 'garage_tools_screen.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key, this.initialVehicleId});

  final String? initialVehicleId;

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  final VehicleRepository _vehicleRepository = VehicleRepository();

  late final PageController _pageController;

  List<Map<String, dynamic>> _vehicles = [];

  int _selectedIndex = 0;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(viewportFraction: 0.73);

    _loadVehicles();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD VEHICLES
  // ============================================================

  Future<void> _loadVehicles() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        if (!mounted) return;

        setState(() {
          _loading = false;
          _error = 'Please log in to access your garage.';
        });

        return;
      }

      final vehicles = await _vehicleRepository.getVehiclesForUser(uid);
      final defaultVehicleId = await _vehicleRepository.getDefaultVehicleId(
        uid,
      );
      final vehiclesWithDefault = vehicles
          .map(
            (vehicle) => {
              ...vehicle,
              'isDefault': vehicle['id']?.toString() == defaultVehicleId,
            },
          )
          .toList();

      if (!mounted) return;

      int selectedIndex = 0;

      final vehicleToSelect = widget.initialVehicleId ?? defaultVehicleId;
      if (vehicleToSelect != null) {
        final index = vehicles.indexWhere(
          (vehicle) => vehicle['id'] == vehicleToSelect,
        );

        if (index >= 0) {
          selectedIndex = index;
        }
      }

      setState(() {
        _vehicles = vehiclesWithDefault;
        _selectedIndex = selectedIndex;
        _loading = false;
        _error = null;
      });

      if (selectedIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(selectedIndex);
          }
        });
      }
    } catch (e) {
      debugPrint('DLOG GARAGE LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to load your garage right now.';
      });
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _modelImage(String model) {
    switch (model) {
      case 'Myvi':
        return 'assets/images/myvi.png';
      case 'Axia':
        return 'assets/images/axia.png';
      case 'X50':
        return 'assets/images/x50.png';
      case 'Saga':
        return 'assets/images/saga.png';
      default:
        return '';
    }
  }

  String _manufacturer(Map<String, dynamic> vehicle) {
    return (vehicle['manufacturer'] ?? 'Manufacturer').toString();
  }

  String _model(Map<String, dynamic> vehicle) {
    return (vehicle['model'] ?? 'Vehicle').toString();
  }

  String _variant(Map<String, dynamic> vehicle) {
    return (vehicle['variant'] ?? 'Variant').toString();
  }

  String _year(Map<String, dynamic> vehicle) {
    return (vehicle['year'] ?? '').toString();
  }

  num _mileage(Map<String, dynamic> vehicle) {
    return (vehicle['currentMileage'] as num?) ?? 0;
  }

  String _formatNumber(num value) {
    return value.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match.group(1)},',
    );
  }

  // ============================================================
  // ADD VEHICLE
  // ============================================================

  Future<void> _confirmAddVehicle() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'ADD ANOTHER VEHICLE?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Create another vehicle profile and add it to your DLog garage.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'CONTINUE',
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

    if (shouldContinue != true || !mounted) {
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const VehicleOnboardingScreen()),
        )
        .then((_) {
          _loadVehicles();
        });
  }

  // ============================================================
  // VEHICLE MANAGEMENT
  // ============================================================

  void _openVehicleDetails(Map<String, dynamic> vehicle) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _vehicleDetailsSheet(vehicle),
    );
  }

  Future<void> _setDefaultVehicle(Map<String, dynamic> vehicle) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final vehicleId = vehicle['id']?.toString();
    if (userId == null || vehicleId == null || vehicleId.isEmpty) return;

    try {
      await _vehicleRepository.setDefaultVehicle(
        userId: userId,
        vehicleId: vehicleId,
      );
      if (!mounted) return;
      await _loadVehicles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Default vehicle updated. Home will show this vehicle.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to set default vehicle: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openVehicleDocuments(
    Map<String, dynamic> vehicle,
    int index,
  ) async {
    setState(() => _selectedIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 620),
        reverseTransitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (routeContext, animation, secondaryAnimation) =>
            VehicleDocumentsScreen(vehicle: vehicle),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return AnimatedBuilder(
            animation: curved,
            child: child,
            builder: (context, child) {
              final progress = curved.value;
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY((1 - progress) * (math.pi / 2))
                ..scaleByDouble(
                  0.90 + (progress * 0.10),
                  0.90 + (progress * 0.10),
                  1,
                  1,
                );
              return Opacity(
                opacity: progress.clamp(0.0, 1.0).toDouble(),
                child: Transform(
                  alignment: Alignment.centerLeft,
                  transform: transform,
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );

    if (mounted) await _loadVehicles();
  }

  Widget _vehicleDetailsSheet(Map<String, dynamic> vehicle) {
    final model = _model(vehicle);
    final manufacturer = _manufacturer(vehicle);
    final variant = _variant(vehicle);
    final year = _year(vehicle);
    final mileage = _mileage(vehicle);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          decoration: BoxDecoration(
            color: const Color(0xFF101214).withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  manufacturer.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  model,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '$variant • $year',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.035),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.speed_rounded,
                        color: DLogColors.burgundy,
                        size: 25,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CURRENT MILEAGE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.40),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatNumber(mileage)} KM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: vehicle['isDefault'] == true
                        ? null
                        : () {
                            Navigator.pop(context);
                            _setDefaultVehicle(vehicle);
                          },
                    icon: Icon(
                      vehicle['isDefault'] == true
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      vehicle['isDefault'] == true
                          ? 'DEFAULT VEHICLE'
                          : 'SET AS DEFAULT',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: vehicle['isDefault'] == true
                          ? const Color(0xFF00D17A)
                          : DLogColors.burgundyBright,
                      side: BorderSide(
                        color: vehicle['isDefault'] == true
                            ? const Color(0xFF00D17A).withValues(alpha: 0.4)
                            : DLogColors.burgundyBright.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _managementButton(
                        icon: Icons.edit_rounded,
                        label: 'EDIT MILEAGE',
                        onTap: () {
                          Navigator.pop(context);
                          _editMileage(vehicle);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _managementButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'DELETE',
                        danger: true,
                        onTap: () {
                          Navigator.pop(context);
                          _confirmDeleteVehicle(vehicle);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'CLOSE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _managementButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: danger ? const Color(0xFFE85B66) : Colors.white,
          side: BorderSide(
            color: danger
                ? const Color(0xFFE85B66).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Future<void> _editMileage(Map<String, dynamic> vehicle) async {
    final controller = TextEditingController(
      text: _mileage(vehicle).round().toString(),
    );

    final newMileage = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'EDIT MILEAGE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 17),
            decoration: InputDecoration(
              suffixText: 'KM',
              suffixStyle: const TextStyle(
                color: Colors.white54,
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
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());

                if (value == null || value < 0) {
                  return;
                }

                Navigator.pop(context, value);
              },
              child: const Text(
                'SAVE',
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

    controller.dispose();

    if (newMileage == null) {
      return;
    }

    final vehicleId = vehicle['id']?.toString();

    if (vehicleId == null || vehicleId.isEmpty) {
      return;
    }

    try {
      await _vehicleRepository.updateMileage(
        vehicleId: vehicleId,
        currentMileage: newMileage,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mileage updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadVehicles();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update mileage: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDeleteVehicle(Map<String, dynamic> vehicle) async {
    final model = _model(vehicle);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'DELETE VEHICLE?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Remove $model from your DLog garage? This cannot be undone.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'DELETE',
                style: TextStyle(
                  color: Color(0xFFE85B66),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final vehicleId = vehicle['id']?.toString();

    if (vehicleId == null || vehicleId.isEmpty) {
      return;
    }

    try {
      await _vehicleRepository.deleteVehicle(vehicleId);

      if (!mounted) return;

      await _loadVehicles();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete vehicle: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // TOOL NAVIGATION
  // ============================================================

  void _openTool(GarageTool tool) {
    if (_vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a vehicle first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final vehicle = _vehicles[_selectedIndex];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GarageToolsScreen(tool: tool, vehicle: vehicle),
      ),
    );
  }

  // ============================================================
  // VEHICLE CARD
  // ============================================================

  Widget _vehicleCard(Map<String, dynamic> vehicle, int index) {
    final model = _model(vehicle);
    final manufacturer = _manufacturer(vehicle);
    final variant = _variant(vehicle);
    final year = _year(vehicle);
    final mileage = _mileage(vehicle);

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double page = index.toDouble();

        if (_pageController.hasClients &&
            _pageController.position.haveDimensions) {
          page = _pageController.page ?? index.toDouble();
        }

        final distance = (page - index).abs().clamp(0.0, 1.0);

        final scale = 1.0 - (distance * 0.12);

        final opacity = 1.0 - (distance * 0.30);

        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: GestureDetector(
        onTap: () => _openVehicleDocuments(vehicle, index),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF181A1C),
                const Color(0xFF090A0B),
                DLogColors.burgundy.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(
              color: _selectedIndex == index
                  ? DLogColors.burgundy.withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: 0.12),
              width: _selectedIndex == index ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _selectedIndex == index
                    ? DLogColors.burgundy.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: _selectedIndex == index ? 28 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -75,
                  top: -55,
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          DLogColors.burgundy.withValues(alpha: 0.34),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 8,
                  right: 8,
                  top: 18,
                  height: 190,
                  child: Image.asset(
                    _modelImage(model),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.directions_car_filled_rounded,
                        color: Colors.white.withValues(alpha: 0.25),
                        size: 95,
                      );
                    },
                  ),
                ),

                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              manufacturer.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.48),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          if (vehicle['isDefault'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00D17A,
                                ).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF00D17A,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: const Text(
                                'DEFAULT',
                                style: TextStyle(
                                  color: Color(0xFF00D17A),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        model,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '$variant • $year',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 11),

                      Row(
                        children: [
                          Text(
                            '${_formatNumber(mileage)} KM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),

                          const Spacer(),

                          GestureDetector(
                            onTap: () {
                              _openVehicleDetails(vehicle);
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.07),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.13),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 19,
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
        ),
      ),
    );
  }

  // ============================================================
  // ADD VEHICLE CARD
  // ============================================================

  Widget _addVehicleCard() {
    return GestureDetector(
      onTap: _confirmAddVehicle,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.white.withValues(alpha: 0.025),
          border: Border.all(
            color: DLogColors.burgundy.withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DLogColors.burgundy.withValues(alpha: 0.12),
                  border: Border.all(
                    color: DLogColors.burgundy.withValues(alpha: 0.55),
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: DLogColors.burgundy,
                  size: 32,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'ADD VEHICLE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'Add another vehicle\nto your DLog garage',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GARAGE LAB
  // ============================================================

  Widget _garageLab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 19, 17, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0D1012),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                  borderRadius: BorderRadius.circular(12),
                  color: DLogColors.burgundy.withValues(alpha: 0.12),
                  border: Border.all(
                    color: DLogColors.burgundy.withValues(alpha: 0.32),
                  ),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: DLogColors.burgundy,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DLOG GARAGE LAB',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tools for your vehicle',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 13),

          _garageToolRow(
            icon: Icons.speed_rounded,
            title: 'Mileage Tracker',
            subtitle: 'Simulate or record real trips',
            onTap: () => _openTool(GarageTool.mileage),
          ),

          _divider(),

          _garageToolRow(
            icon: Icons.calendar_month_rounded,
            title: 'Time Simulator',
            subtitle: 'Fast-forward maintenance timing',
            onTap: () => _openTool(GarageTool.time),
          ),

          _divider(),

          _garageToolRow(
            icon: Icons.payments_outlined,
            title: 'Repair Cost Estimator',
            subtitle: 'Build a service cost estimate',
            onTap: () => _openTool(GarageTool.cost),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.only(left: 57),
      child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
    );
  }

  Widget _garageToolRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: Colors.white.withValues(alpha: 0.045),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.78),
                size: 21,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.40),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAV
  // ============================================================

  Widget _bottomNavigation() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.095),
                Colors.white.withValues(alpha: 0.035),
                DLogColors.burgundy.withValues(alpha: 0.055),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(
                Icons.home_rounded,
                'Home',
                false,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              _navItem(
                Icons.directions_car_filled_rounded,
                'Garage',
                true,
                onTap: () {
                  _loadVehicles();
                },
              ),
              _navItem(
                Icons.menu_book_rounded,
                'Encyclopedia',
                false,
                onTap: () =>
                    DLogNavigation.push(context, const EncyclopediaScreen()),
              ),
              _navItem(
                Icons.sos_rounded,
                'SOS',
                false,
                onTap: () => DLogNavigation.push(context, const SosScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    bool selected, {
    required VoidCallback onTap,
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
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.48),
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DLogBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: DLogColors.burgundy),
                )
              : _error != null
              ? _errorState()
              : RefreshIndicator(
                  color: DLogColors.burgundy,
                  backgroundColor: const Color(0xFF111416),
                  onRefresh: _loadVehicles,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 115),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),

                        const SizedBox(height: 24),

                        if (_vehicles.isNotEmpty)
                          _vehicleCarousel()
                        else
                          _emptyGarage(),

                        const SizedBox(height: 30),

                        _garageLab(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _bottomNavigation(),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE GARAGE',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Your vehicle collection',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _vehicleCarousel() {
    final totalPages = _vehicles.length + 1;

    return Column(
      children: [
        SizedBox(
          height: 410,
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            itemBuilder: (context, index) {
              if (index == _vehicles.length) {
                return _addVehicleCard();
              }

              return _vehicleCard(_vehicles[index], index);
            },
          ),
        ),

        const SizedBox(height: 2),

        _carouselIndicator(totalPages),
      ],
    );
  }

  Widget _carouselIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == _selectedIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? DLogColors.burgundy
                : Colors.white.withValues(alpha: 0.20),
          ),
        );
      }),
    );
  }

  Widget _emptyGarage() {
    return SizedBox(
      height: 420,
      child: Center(
        child: GestureDetector(
          onTap: _confirmAddVehicle,
          child: Container(
            width: double.infinity,
            height: 360,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: Colors.white.withValues(alpha: 0.025),
              border: Border.all(
                color: DLogColors.burgundy.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DLogColors.burgundy.withValues(alpha: 0.10),
                    border: Border.all(
                      color: DLogColors.burgundy.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: DLogColors.burgundy,
                    size: 35,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'YOUR GARAGE IS EMPTY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first vehicle\nto start using DLog.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: Colors.white.withValues(alpha: 0.35),
              size: 46,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load garage',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _loadVehicles,
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
}
