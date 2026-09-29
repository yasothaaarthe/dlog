import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../repositories/vehicle_repository.dart';
import '../../theme/dlog_colors.dart';
import '../../widgets/dlog_background.dart';
import '../home/home_screen.dart';

class VehicleOnboardingScreen extends StatefulWidget {
  const VehicleOnboardingScreen({super.key, this.onCompleted});

  /// Optional callback for wiring the completed vehicle into Firebase later.
  /// Existing calls such as const VehicleOnboardingScreen() still work.
  final void Function(Map<String, dynamic> vehicleData)? onCompleted;

  @override
  State<VehicleOnboardingScreen> createState() =>
      _VehicleOnboardingScreenState();
}

class _VehicleOnboardingScreenState extends State<VehicleOnboardingScreen> {
  // ============================================================
  // ONBOARDING STATE
  // ============================================================

  int _currentStep = 0;

  String? _selectedManufacturer;
  String? _selectedModel;
  int? _selectedYear;
  String? _selectedVariant;

  static const int _maxMileage = 999999;
  static const int _mileageStep = 50;
  static const double _mileageTickWidth = 14;

  double _mileage = 22450;
  late final TextEditingController _mileageController;
  late final ScrollController _mileageScrollController;
  int _lastRulerIndex = -1;

  bool _hasServiceHistory = false;
  String? _vehicleLifecycle;

  DateTime? _lastServiceDate;
  double? _lastServiceMileage;
  final Set<String> _recentServiceItems = {};

  late FixedExtentScrollController _yearController;

  // ============================================================
  // VEHICLE CATALOG
  //
  // The maintenance blueprint defines the four supported models.
  // Historical variant/year combinations below are kept as
  // controlled UI choices. Exact manufacturer certification of
  // every historical variant belongs in the rule-data layer.
  // ============================================================

  final Map<String, String> _modelImages = {
    'Myvi': 'assets/images/myvi.png',
    'Axia': 'assets/images/axia.png',
    'X50': 'assets/images/x50.png',
    'Saga': 'assets/images/saga.png',
  };

  final Map<String, String> _modelManufacturers = {
    'Myvi': 'Perodua',
    'Axia': 'Perodua',
    'X50': 'Proton',
    'Saga': 'Proton',
  };

  // ============================================================
  // MODEL / YEAR DATA
  // ============================================================

  List<String> get _availableModels {
    if (_selectedManufacturer == 'Perodua') {
      return const ['Myvi', 'Axia'];
    }

    if (_selectedManufacturer == 'Proton') {
      return const ['X50', 'Saga'];
    }

    return const [];
  }

  List<int> get _availableYears {
    switch (_selectedModel) {
      case 'Myvi':
        return List<int>.generate(16, (i) => 2011 + i);

      case 'Axia':
        return List<int>.generate(13, (i) => 2014 + i);

      case 'X50':
        return List<int>.generate(7, (i) => 2020 + i);

      case 'Saga':
        // Current prototype rule coverage is centred around the
        // researched 2022-era Saga data.
        return List<int>.generate(5, (i) => 2022 + i);

      default:
        return const [];
    }
  }

  List<String> get _availableVariants {
    final model = _selectedModel;
    final year = _selectedYear;

    if (model == null || year == null) return const [];

    if (model == 'Myvi') {
      if (year <= 2014) {
        return const ['1.3 Standard', '1.3 Premium', '1.5 SE', '1.5 Extreme'];
      }

      if (year <= 2016) {
        return const ['1.3 Standard', '1.3 Premium X', '1.5 SE', '1.5 Advance'];
      }

      if (year <= 2021) {
        return const ['1.3 G', '1.5 X', '1.5 H', '1.5 AV'];
      }

      return const ['1.3 G', '1.5 X', '1.5 H', '1.5 AV'];
    }

    if (model == 'Axia') {
      if (year <= 2018) {
        return const ['1.0 E', '1.0 G', '1.0 SE', '1.0 Advance'];
      }

      if (year <= 2022) {
        return const ['1.0 E', '1.0 G', '1.0 GXtra', '1.0 SE', '1.0 AV'];
      }

      return const ['1.0 G', '1.0 X', '1.0 SE', '1.0 AV'];
    }

    if (model == 'X50') {
      if (year <= 2024) {
        return const [
          '1.5 Standard',
          '1.5 Executive',
          '1.5 Premium',
          '1.5 Flagship',
        ];
      }

      return const ['1.5TD Executive', '1.5TD Premium', '1.5TD Flagship'];
    }

    if (model == 'Saga') {
      if (year == 2022) {
        return const [
          '1.3 Standard MT',
          '1.3 Standard AT',
          '1.3 Premium AT',
          '1.3 Premium S AT',
        ];
      }

      return const ['1.3 Standard', '1.3 Executive', '1.3 Premium'];
    }

    return const [];
  }

  // ============================================================
  // DERIVED VEHICLE DATA
  // ============================================================

  String get _derivedGeneration {
    final model = _selectedModel;
    final year = _selectedYear;

    if (model == null || year == null) return '—';

    switch (model) {
      case 'Myvi':
        if (year <= 2014) return 'Myvi Gen 2';
        if (year <= 2016) return 'Myvi Gen 2 Facelift';
        if (year <= 2021) return 'Myvi Gen 3';
        return 'Myvi Gen 3 Facelift';

      case 'Axia':
        if (year <= 2018) return 'Axia Gen 1';
        if (year <= 2022) return 'Axia Facelift';
        return 'All-New Axia';

      case 'X50':
        if (year <= 2024) return 'X50 First Generation';
        return 'All-New X50';

      case 'Saga':
        if (year <= 2024) return 'Saga 2022-era';
        return 'Saga 2025-era';

      default:
        return '—';
    }
  }

  String get _derivedEngine {
    final model = _selectedModel;
    final variant = _selectedVariant ?? '';

    if (model == null) return '—';

    if (model == 'Myvi') {
      if (variant.startsWith('1.5')) return '1.5L';
      return '1.3L';
    }

    if (model == 'Axia') {
      return '1.0L';
    }

    if (model == 'X50') {
      return '1.5L Turbo';
    }

    if (model == 'Saga') {
      return '1.3L';
    }

    return '—';
  }

  String get _derivedTransmission {
    final model = _selectedModel;
    final variant = _selectedVariant ?? '';
    final year = _selectedYear;

    if (model == null || year == null) return '—';

    if (model == 'Axia' && year >= 2023) {
      return 'D-CVT';
    }

    if (model == 'X50' && year >= 2025) {
      return '7DCT';
    }

    if (model == 'X50') {
      return '7DCT';
    }

    if (model == 'Saga') {
      if (variant.contains('MT')) return 'Manual';
      return 'Automatic';
    }

    return 'Automatic';
  }

  String get _ruleGroupId {
    final model = _selectedModel;
    final year = _selectedYear;

    if (model == null || year == null) return '—';

    switch (model) {
      case 'Myvi':
        if (year <= 2014) return 'MYVI_G2_2011';
        if (year <= 2016) return 'MYVI_G2_FL_2015';
        if (year <= 2021) return 'MYVI_G3_2017';
        return 'MYVI_G3_FL_2022';

      case 'Axia':
        if (year <= 2018) return 'AXIA_G1';
        if (year <= 2022) return 'AXIA_2019';
        return 'AXIA_2023_1.0_DCVT';

      case 'X50':
        if (year == 2024) return 'X50_2024';
        if (year <= 2023) return 'X50_2020';
        return 'X50_2025_1.5TD_7DCT';

      case 'Saga':
        if (year <= 2024) return 'SAGA_2022';
        return 'SAGA_2025';

      default:
        return '—';
    }
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _mileageController = TextEditingController(
      text: _formatNumber(_mileage.round()),
    );

    _mileageScrollController = ScrollController();

    _yearController = FixedExtentScrollController(
      initialItem: _initialYearIndex(),
    );
  }

  int _initialYearIndex() {
    final years = _availableYears;
    if (years.isEmpty) return 0;

    const preferredYear = 2025;

    final index = years.indexOf(preferredYear);

    if (index >= 0) return index;

    return years.length - 1;
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _mileageScrollController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  // ============================================================
  // CONTINUE
  // ============================================================

  Future<void> _continue() async {
    if (_currentStep == 0) {
      if (_selectedManufacturer == null) {
        _showMessage('Please select your manufacturer.');
        return;
      }

      setState(() {
        _currentStep = 1;
        _selectedModel = null;
        _selectedYear = null;
        _selectedVariant = null;
      });

      return;
    }

    if (_currentStep == 1) {
      if (_selectedModel == null) {
        _showMessage('Please select your vehicle model.');
        return;
      }

      setState(() {
        _currentStep = 2;
        _selectedYear = _availableYears[_initialYearIndex()];
        _selectedVariant = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final index = _availableYears.indexOf(_selectedYear!);

        _yearController.jumpToItem(index < 0 ? 0 : index);
      });

      return;
    }

    if (_currentStep == 2) {
      if (_selectedYear == null) {
        _showMessage('Please select your model year.');
        return;
      }

      setState(() {
        _currentStep = 3;
        _selectedVariant = null;
      });

      return;
    }

    if (_currentStep == 3) {
      if (_selectedVariant == null) {
        _showMessage('Please select your vehicle variant.');
        return;
      }

      setState(() {
        _currentStep = 4;
      });
      return;
    }

    if (_currentStep == 4) {
      if (_vehicleLifecycle == null) {
        _showMessage(
          'Please tell DLog whether this vehicle is brand new or existing.',
        );
        return;
      }

      setState(() {
        _currentStep = 5;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncMileageRulerToMileage();
      });
      return;
    }

    if (_currentStep == 5) {
      if (_vehicleLifecycle == 'new') {
        await _finishOnboarding();
      } else {
        _showServiceHistoryStep();
      }
    }
  }

  // ============================================================
  // BACK
  // ============================================================

  void _goBack() {
    if (_showingServiceHistory) {
      setState(() {
        _showingServiceHistory = false;
      });
      return;
    }

    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _currentStep--;

      if (_currentStep == 1) {
        _selectedYear = null;
        _selectedVariant = null;
      }

      if (_currentStep == 2) {
        _selectedVariant = null;
      }
    });
  }

  // ============================================================
  // SERVICE HISTORY
  //
  // This is deliberately optional. It appears after the
  // lifecycle choice for existing vehicles.
  // ============================================================

  bool _showingServiceHistory = false;

  void _showServiceHistoryStep() {
    setState(() {
      _showingServiceHistory = true;
      _hasServiceHistory = false;
      _lastServiceDate = null;
      _lastServiceMileage = null;
      _recentServiceItems.clear();
    });
  }

  Future<void> _finishOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please log in before creating your vehicle.');
      return;
    }

    if (_selectedManufacturer == null ||
        _selectedModel == null ||
        _selectedYear == null ||
        _selectedVariant == null) {
      _showMessage('Please complete your vehicle details.');
      return;
    }

    if (_vehicleLifecycle == null) {
      _showMessage(
        'Please select whether this vehicle is brand new or existing.',
      );
      return;
    }

    final vehicleData = <String, dynamic>{
      'manufacturer': _selectedManufacturer,
      'model': _selectedModel,
      'year': _selectedYear,
      'variant': _selectedVariant,
      'currentMileage': _mileage.round(),
      'generation': _derivedGeneration,
      'engine': _derivedEngine,
      'transmission': _derivedTransmission,
      'ruleGroupId': _ruleGroupId,
      'vehicleLifecycle': _vehicleLifecycle,
      'serviceHistoryKnown': _hasServiceHistory,
      'lastServiceDate': _lastServiceDate?.toIso8601String(),
      'lastServiceMileage': _lastServiceMileage?.round(),
      'recentServiceItems': _recentServiceItems.toList(),
    };

    try {
      final repository = VehicleRepository();

      final vehicleId = await repository.addVehicle(
        userId: user.uid,
        manufacturer: _selectedManufacturer!,
        model: _selectedModel!,
        variant: _selectedVariant!,
        year: _selectedYear!,
        engine: _derivedEngine,
        transmission: _derivedTransmission,
        currentMileage: _mileage.round(),
        ruleGroupId: _ruleGroupId,
        vehicleLifecycle: _vehicleLifecycle!,
        serviceHistoryKnown: _hasServiceHistory,
        lastServiceDate: _lastServiceDate,
        lastServiceMileage: _lastServiceMileage?.round(),
        recentServiceItems: _recentServiceItems.toList(),
      );

      vehicleData['id'] = vehicleId;

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            userName: user.displayName ?? 'Yas',
            vehicleData: vehicleData,
          ),
        ),
      );
    } catch (e) {
      debugPrint('DLOG VEHICLE SAVE ERROR: $e');
      if (!mounted) return;

      _showMessage('Vehicle save failed: $e');
    }
  }

  Future<void> _showCompletionDialog(Map<String, dynamic> vehicleData) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111416),
          title: const Text(
            'Vehicle profile ready',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '${vehicleData['model']} • ${vehicleData['year']}\n'
            '${vehicleData['variant']}\n'
            '${_formatNumber(vehicleData['currentMileage'])} km\n\n'
            'DLog has identified the maintenance profile:\n'
            '${vehicleData['ruleGroupId']}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'DONE',
                style: TextStyle(
                  color: DLogColors.burgundy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: DLogColors.burgundy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // FORMATTERS
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

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ============================================================
  // MANUFACTURER CARD
  //
  // THIS SECTION IS THE EXISTING DESIGN.
  // It is intentionally retained rather than replaced.
  // ============================================================

  Widget _manufacturerCard({required String manufacturer}) {
    final bool isSelected = _selectedManufacturer == manufacturer;

    final bool isPerodua = manufacturer == 'Perodua';

    final String logoAsset = isPerodua
        ? 'assets/images/perodua_logo.png'
        : 'assets/images/proton_logo.png';

    final String carAsset = isPerodua
        ? 'assets/images/perodua_car.png'
        : 'assets/images/proton_car.png';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedManufacturer = manufacturer;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: 184,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),

          border: Border.all(
            color: isSelected
                ? DLogColors.burgundy
                : Colors.white.withValues(alpha: 0.20),
            width: isSelected ? 2.6 : 1.0,
          ),

          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: DLogColors.burgundy.withValues(alpha: 0.55),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: DLogColors.burgundy.withValues(alpha: 0.28),
                    blurRadius: 65,
                    spreadRadius: 6,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSelected
                          ? const [
                              Color(0xFF5A001A),
                              Color(0xFF28000D),
                              Color(0xFF100508),
                              Color(0xFF050505),
                            ]
                          : const [
                              Color(0xFF3B3B3B),
                              Color(0xFF242424),
                              Color(0xFF111111),
                              Color(0xFF050505),
                            ],
                      stops: const [0.0, 0.30, 0.65, 1.0],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: -50,
                top: -55,
                child: Container(
                  width: 270,
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(
                          alpha: isSelected ? 0.08 : 0.14,
                        ),
                        Colors.white.withValues(alpha: 0.025),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                right: -80,
                top: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        DLogColors.burgundy.withValues(
                          alpha: isSelected ? 0.42 : 0.06,
                        ),
                        DLogColors.burgundy.withValues(
                          alpha: isSelected ? 0.12 : 0.015,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              if (isSelected)
                Positioned(
                  left: -50,
                  right: -50,
                  bottom: -60,
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          DLogColors.burgundy.withValues(alpha: 0.38),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                right: -12,
                top: -10,
                bottom: -10,
                width: 235,
                child: IgnorePointer(
                  child: Image.asset(
                    carAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),

              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.72],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 8,
                top: 25,
                width: 190,
                height: 125,
                child: IgnorePointer(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    scale: isSelected ? 1.08 : 1.0,
                    child: Image.asset(
                      logoAsset,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),

              Positioned(
                right: 13,
                bottom: 13,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  width: isSelected ? 39 : 30,
                  height: isSelected ? 39 : 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? DLogColors.burgundy
                        : Colors.black.withValues(alpha: 0.48),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.20),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: DLogColors.burgundy.withValues(
                                alpha: 0.80,
                              ),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ]
                        : [],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            key: ValueKey('selected'),
                            color: Colors.white,
                            size: 24,
                          )
                        : const Icon(
                            Icons.arrow_forward_ios_rounded,
                            key: ValueKey('unselected'),
                            color: DLogColors.silver,
                            size: 13,
                          ),
                  ),
                ),
              ),

              if (isSelected)
                Positioned(
                  left: 18,
                  right: 18,
                  top: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          DLogColors.burgundy.withValues(alpha: 0.95),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                left: 20,
                right: 20,
                bottom: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [
                              Colors.transparent,
                              DLogColors.burgundy.withValues(alpha: 0.90),
                              Colors.transparent,
                            ]
                          : [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.14),
                              Colors.transparent,
                            ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROGRESS INDICATOR
  // ============================================================

  Widget _progressIndicator() {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 6,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                DLogColors.burgundy,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${_currentStep + 1}/6',
          style: const TextStyle(
            color: DLogColors.silver,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAGE HEADER
  // ============================================================

  Widget _pageHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: DLogColors.white,
            fontSize: 31,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(
            color: DLogColors.silver,
            fontSize: 16,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STEP 1 — MANUFACTURER
  // EXISTING SCREEN — KEPT
  // ============================================================

  Widget _manufacturerStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What do you drive?',
          style: TextStyle(
            color: DLogColors.white,
            fontSize: 31,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Select the manufacturer of your vehicle.',
          style: TextStyle(color: DLogColors.silver, fontSize: 16, height: 1.4),
        ),
        const SizedBox(height: 30),
        _manufacturerCard(manufacturer: 'Perodua'),
        const SizedBox(height: 16),
        _manufacturerCard(manufacturer: 'Proton'),
      ],
    );
  }

  // ============================================================
  // STEP 2 — MODEL SELECTION
  // ============================================================

  Widget _modelStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(
          title: 'Choose your model',
          subtitle: 'Select the model of your vehicle.',
        ),
        const SizedBox(height: 28),

        ..._availableModels.map(
          (model) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _modelCard(model),
          ),
        ),
      ],
    );
  }

  Widget _modelCard(String model) {
    final selected = _selectedModel == model;
    final manufacturer = _modelManufacturers[model]!;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModel = model;
          _selectedYear = null;
          _selectedVariant = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        height: 176,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? DLogColors.burgundy
                : Colors.white.withValues(alpha: 0.14),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: DLogColors.burgundy.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ]
              : [],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? const [
                    Color(0xFF430013),
                    Color(0xFF1B080D),
                    Color(0xFF08090A),
                  ]
                : const [
                    Color(0xFF202427),
                    Color(0xFF121517),
                    Color(0xFF08090A),
                  ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -18,
                bottom: -18,
                width: 230,
                child: IgnorePointer(
                  child: Image.asset(
                    _modelImages[model]!,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),

              Positioned(
                left: 22,
                top: 27,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.toUpperCase(),
                      style: const TextStyle(
                        color: DLogColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      manufacturer,
                      style: const TextStyle(
                        color: DLogColors.silver,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),

              Positioned(
                right: 14,
                bottom: 14,
                child: _selectionCircle(selected),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionCircle(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: selected ? 38 : 30,
      height: selected ? 38 : 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? DLogColors.burgundy
            : Colors.black.withValues(alpha: 0.52),
        border: Border.all(
          color: Colors.white.withValues(alpha: selected ? 0.24 : 0.16),
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: DLogColors.burgundy.withValues(alpha: 0.7),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Icon(
        selected ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
        color: selected ? Colors.white : DLogColors.silver,
        size: selected ? 22 : 12,
      ),
    );
  }

  // ============================================================
  // STEP 3 — YEAR SELECTION
  // ============================================================

  Widget _yearStep() {
    final years = _availableYears;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(
          title: 'What year is it?',
          subtitle: "Select your vehicle's model year.",
        ),
        const SizedBox(height: 22),

        Container(
          height: 360,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF090B0C).withValues(alpha: 0.82),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 137,
                child: Container(
                  height: 76,
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: DLogColors.burgundy.withValues(alpha: 0.75),
                        width: 1.5,
                      ),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        DLogColors.burgundy.withValues(alpha: 0.04),
                        DLogColors.burgundy.withValues(alpha: 0.16),
                        DLogColors.burgundy.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                ),
              ),

              ListWheelScrollView.useDelegate(
                controller: _yearController,
                itemExtent: 62,
                diameterRatio: 1.7,
                perspective: 0.003,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (index) {
                  if (index < 0 || index >= years.length) return;

                  setState(() {
                    _selectedYear = years[index];
                    _selectedVariant = null;
                  });
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: years.length,
                  builder: (context, index) {
                    if (index < 0 || index >= years.length) {
                      return null;
                    }

                    final selected = years[index] == _selectedYear;

                    return Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          color: selected
                              ? DLogColors.white
                              : Colors.white.withValues(alpha: 0.36),
                          fontSize: selected ? 29 : 20,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        child: Text('${years[index]}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        _derivedInfoStrip(
          icon: Icons.directions_car_filled_rounded,
          label: 'Selected vehicle',
          value: '${_selectedModel ?? '—'} • ${_selectedYear ?? '—'}',
        ),
      ],
    );
  }

  // ============================================================
  // STEP 4 — VARIANT
  // ============================================================

  Widget _variantStep() {
    final variants = _availableVariants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(
          title: 'Select your variant',
          subtitle:
              '${_selectedModel ?? 'Vehicle'} • ${_selectedYear ?? 'Year'}',
        ),
        const SizedBox(height: 26),

        ...variants.map(
          (variant) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _variantCard(variant),
          ),
        ),

        const SizedBox(height: 8),

        _derivedInfoStrip(
          icon: Icons.tune_rounded,
          label: 'DLog will determine',
          value: 'Engine • transmission • maintenance profile',
        ),
      ],
    );
  }

  Widget _variantCard(String variant) {
    final selected = _selectedVariant == variant;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVariant = variant;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 62,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: selected ? const Color(0xFF3C0713) : const Color(0xFF15191C),
          border: Border.all(
            color: selected
                ? DLogColors.burgundy
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: DLogColors.burgundy.withValues(alpha: 0.28),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                variant,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.82),
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_rounded : Icons.chevron_right_rounded,
              color: selected ? DLogColors.white : DLogColors.silver,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STEP 5 — ODOMETER
  // ============================================================

  Widget _odometerStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(
          title: "What's the current\nodometer reading?",
          subtitle: 'Enter the current mileage of your vehicle.',
        ),
        const SizedBox(height: 26),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0D0F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _mileageController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                cursorColor: DLogColors.burgundy,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white24),
                  suffixText: ' KM',
                  suffixStyle: TextStyle(
                    color: DLogColors.silver,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onChanged: _onMileageTextChanged,
                onSubmitted: (_) => _syncMileageFromText(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _mileageRuler(),

        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _mileageLabel('0', false),
            _mileageLabel(_formatNumber(_mileage.round()), true),
            _mileageLabel(_formatNumber(_maxMileage), false),
          ],
        ),

        const SizedBox(height: 30),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DLogColors.burgundy.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: DLogColors.burgundy.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: DLogColors.burgundy,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This helps DLog calculate your maintenance schedule.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mileageRuler() {
    final maxIndex = _maxMileage ~/ _mileageStep;
    final selectedIndex = (_mileage.round() / _mileageStep).round().clamp(
      0,
      maxIndex,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding =
            (constraints.maxWidth / 2) - (_mileageTickWidth / 2);

        return Container(
          height: 112,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF050607),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis != Axis.horizontal) {
                    return false;
                  }

                  final rawIndex =
                      (notification.metrics.pixels / _mileageTickWidth).round();
                  final index = rawIndex.clamp(0, maxIndex);

                  if (index != _lastRulerIndex) {
                    _lastRulerIndex = index;

                    final value = (index * _mileageStep).clamp(0, _maxMileage);

                    setState(() {
                      _mileage = value.toDouble();
                      _mileageController.text = _formatNumber(value);
                      _mileageController.selection = TextSelection.collapsed(
                        offset: _mileageController.text.length,
                      );
                    });

                    // A subtle dashboard-style click for each
                    // mileage increment while the ruler moves.
                    SystemSound.play(SystemSoundType.click);
                  }

                  if (notification is ScrollEndNotification) {
                    final target = index * _mileageTickWidth;

                    if ((notification.metrics.pixels - target).abs() > 0.5) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted || !_mileageScrollController.hasClients) {
                          return;
                        }

                        _mileageScrollController.animateTo(
                          target,
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                        );
                      });
                    }
                  }

                  return true;
                },
                child: ListView.builder(
                  controller: _mileageScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  itemCount: maxIndex + 1,
                  itemExtent: _mileageTickWidth,
                  itemBuilder: (context, index) {
                    final value = index * _mileageStep;
                    final isMajor = value % 1000 == 0;
                    final isMedium = value % 500 == 0;

                    return SizedBox(
                      width: _mileageTickWidth,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: isMajor
                              ? 2
                              : isMedium
                              ? 1.5
                              : 1,
                          height: isMajor
                              ? 42
                              : isMedium
                              ? 32
                              : 22,
                          margin: const EdgeInsets.only(bottom: 27),
                          color: isMajor
                              ? Colors.white.withValues(alpha: 0.70)
                              : Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Fixed centre marker — the ruler moves underneath it.
              Positioned(
                top: 13,
                bottom: 24,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: DLogColors.burgundy,
                        boxShadow: [
                          BoxShadow(
                            color: DLogColors.burgundy.withValues(alpha: 0.80),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: CustomPaint(
                      size: const Size(14, 8),
                      painter: _RulerMarkerPainter(),
                    ),
                  ),
                ),
              ),

              // Odometer-style labels: a 10,000 km window around
              // the current reading, with the live reading centred.
              Positioned(
                left: 14,
                right: 14,
                bottom: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatNumber((_mileage.round() ~/ 10000) * 10000),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      _formatNumber(_mileage.round()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _formatNumber(
                        (((_mileage.round() ~/ 10000) + 1) * 10000).clamp(
                          0,
                          _maxMileage,
                        ),
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _syncMileageRulerToMileage() {
    if (!_mileageScrollController.hasClients) return;

    final maxIndex = _maxMileage ~/ _mileageStep;
    final index = (_mileage.round() / _mileageStep).round().clamp(0, maxIndex);

    _lastRulerIndex = index;

    final target = index * _mileageTickWidth;

    _mileageScrollController.jumpTo(target);
  }

  Widget _mileageLabel(String text, bool selected) {
    return Text(
      text,
      style: TextStyle(
        color: selected
            ? DLogColors.white
            : Colors.white.withValues(alpha: 0.38),
        fontSize: selected ? 14 : 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }

  void _onMileageTextChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) return;

    final parsed = int.tryParse(digits);

    if (parsed == null) return;

    final safeValue = parsed.clamp(0, _maxMileage);

    setState(() {
      _mileage = safeValue.toDouble();
    });
  }

  void _syncMileageFromText() {
    final digits = _mileageController.text.replaceAll(RegExp(r'[^0-9]'), '');

    final parsed = int.tryParse(digits);

    if (parsed == null) {
      _mileageController.text = _formatNumber(_mileage.round());
      return;
    }

    final safeValue = parsed.clamp(0, _maxMileage);

    setState(() {
      _mileage = safeValue.toDouble();
      _mileageController.text = _formatNumber(safeValue);
      _mileageController.selection = TextSelection.collapsed(
        offset: _mileageController.text.length,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncMileageRulerToMileage();
    });
  }

  // ============================================================
  // STEP 6 — VEHICLE LIFECYCLE
  //
  // This distinguishes a brand-new vehicle from one that is
  // already in use. The value is stored separately from service
  // history because lifecycle and service-history knowledge are
  // different concepts.
  // ============================================================

  Widget _vehicleLifecycleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(
          title: 'Is this vehicle brand new?',
          subtitle:
              'Tell DLog whether this vehicle is new or already in use so the correct maintenance stages are applied.',
        ),
        const SizedBox(height: 28),

        _lifecycleChoice(
          selected: _vehicleLifecycle == 'new',
          title: 'Brand new',
          subtitle:
              'This vehicle is new and has not previously been in regular use.',
          icon: Icons.auto_awesome_rounded,
          onTap: () {
            setState(() {
              _vehicleLifecycle = 'new';
            });
          },
        ),

        const SizedBox(height: 14),

        _lifecycleChoice(
          selected: _vehicleLifecycle == 'existing',
          title: 'Existing vehicle',
          subtitle:
              'This vehicle is already in use and may have previous service history.',
          icon: Icons.directions_car_filled_rounded,
          onTap: () {
            setState(() {
              _vehicleLifecycle = 'existing';
            });
          },
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DLogColors.burgundy.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: DLogColors.burgundy.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: DLogColors.burgundy,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'DLog uses this choice to decide whether initial maintenance milestones should apply to your vehicle.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lifecycleChoice({
    required bool selected,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? const Color(0xFF390813) : const Color(0xFF15191C),
          border: Border.all(
            color: selected
                ? DLogColors.burgundy
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: DLogColors.burgundy.withValues(alpha: 0.28),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: selected
                    ? DLogColors.burgundy.withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.07),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : DLogColors.silver,
                size: 24,
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
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? DLogColors.burgundy : Colors.white24,
              size: 25,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OPTIONAL SERVICE HISTORY
  // ============================================================

  Widget _serviceHistoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(
          title: 'Any recent service?',
          subtitle:
              'Optional. Tell DLog what you know so your schedule starts from a better point.',
        ),

        const SizedBox(height: 26),

        _historyChoice(
          selected: _hasServiceHistory,
          title: 'Yes, I know my recent service',
          subtitle: 'Add the last known service details.',
          icon: Icons.history_rounded,
          onTap: () {
            setState(() {
              _hasServiceHistory = true;
            });
          },
        ),

        const SizedBox(height: 12),

        _historyChoice(
          selected: !_hasServiceHistory,
          title: "No, I don't remember",
          subtitle: 'DLog will mark the service history as incomplete.',
          icon: Icons.help_outline_rounded,
          onTap: () {
            setState(() {
              _hasServiceHistory = false;
              _lastServiceDate = null;
              _lastServiceMileage = null;
              _recentServiceItems.clear();
            });
          },
        ),

        if (_hasServiceHistory) ...[
          const SizedBox(height: 22),
          _serviceHistoryForm(),
        ],

        const SizedBox(height: 18),

        _vehicleSummaryCard(),
      ],
    );
  }

  Widget _historyChoice({
    required bool selected,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? const Color(0xFF390813) : const Color(0xFF15191C),
          border: Border.all(
            color: selected
                ? DLogColors.burgundy
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : DLogColors.silver,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? DLogColors.burgundy : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceHistoryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What was serviced?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                'Engine Oil & Oil Filter',
                'Brake System',
                'Tyres',
                'Tyre Rotation',
                'Battery',
                'Coolant',
                'Engine Air Filter',
                'Transmission Fluid',
              ].map((item) {
                final selected = _recentServiceItems.contains(item);

                return FilterChip(
                  selected: selected,
                  label: Text(item),
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _recentServiceItems.add(item);
                      } else {
                        _recentServiceItems.remove(item);
                      }
                    });
                  },
                  backgroundColor: const Color(0xFF171A1D),
                  selectedColor: DLogColors.burgundy,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.70),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selected
                        ? DLogColors.burgundy
                        : Colors.white.withValues(alpha: 0.10),
                  ),
                );
              }).toList(),
        ),

        const SizedBox(height: 18),

        _dateField(),

        const SizedBox(height: 12),

        _lastMileageField(),
      ],
    );
  }

  Widget _dateField() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          initialDate: _lastServiceDate ?? DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: DLogColors.burgundy,
                  surface: Color(0xFF111416),
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked == null) return;

        setState(() {
          _lastServiceDate = picked;
        });
      },
      child: _inputLikeCard(
        icon: Icons.calendar_month_rounded,
        label: 'Last service date',
        value: _lastServiceDate == null
            ? 'Select date'
            : _formatDate(_lastServiceDate!),
      ),
    );
  }

  Widget _lastMileageField() {
    return TextField(
      keyboardType: TextInputType.number,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.speed_rounded, color: DLogColors.silver),
        labelText: 'Last service mileage',
        labelStyle: const TextStyle(color: DLogColors.silver),
        suffixText: 'km',
        suffixStyle: const TextStyle(color: DLogColors.silver),
        filled: true,
        fillColor: const Color(0xFF15191C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DLogColors.burgundy, width: 1.4),
        ),
      ),
      onChanged: (value) {
        final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));

        _lastServiceMileage = parsed == null ? null : parsed.toDouble();
      },
    );
  }

  Widget _inputLikeCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF15191C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: DLogColors.silver, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: DLogColors.silver),
        ],
      ),
    );
  }

  // ============================================================
  // VEHICLE SUMMARY
  // ============================================================

  Widget _vehicleSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF2D060F), Color(0xFF10090C), Color(0xFF090A0B)],
        ),
        border: Border.all(color: DLogColors.burgundy.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: DLogColors.burgundy.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                color: DLogColors.burgundy,
                size: 20,
              ),
              const SizedBox(width: 9),
              Text(
                'VEHICLE PROFILE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_selectedModel ?? 'Vehicle'} • ${_selectedYear ?? ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedVariant ?? 'Variant',
            style: const TextStyle(color: DLogColors.silver, fontSize: 14),
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryPill(
                Icons.speed_rounded,
                '${_formatNumber(_mileage.round())} km',
              ),
              _summaryPill(Icons.settings_rounded, _derivedTransmission),
              _summaryPill(Icons.engineering_rounded, _derivedEngine),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: DLogColors.silver, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _derivedInfoStrip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: DLogColors.silver, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP CONTENT SWITCHER
  // ============================================================

  Widget _currentStepWidget() {
    if (_showingServiceHistory) {
      return _serviceHistoryStep();
    }

    switch (_currentStep) {
      case 0:
        return _manufacturerStep();
      case 1:
        return _modelStep();
      case 2:
        return _yearStep();
      case 3:
        return _variantStep();
      case 4:
        return _vehicleLifecycleStep();
      case 5:
        return _odometerStep();
      default:
        return _manufacturerStep();
    }
  }

  // ============================================================
  // BUTTON LABEL
  // ============================================================

  String get _buttonLabel {
    if (_showingServiceHistory) {
      return 'CREATE VEHICLE';
    }

    if (_currentStep == 5) {
      if (_vehicleLifecycle == 'new') {
        return 'CREATE VEHICLE';
      }

      return 'CONTINUE';
    }

    return 'CONTINUE';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DLogBackground(
        child: SafeArea(
          child: Column(
            children: [
              // --------------------------------------------------
              // TOP BAR
              // --------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _goBack,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: DLogColors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'DLOG',
                      style: TextStyle(
                        color: DLogColors.silverLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // --------------------------------------------------
              // MAIN CONTENT
              // --------------------------------------------------
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _progressIndicator(),

                      const SizedBox(height: 42),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.035, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(
                            _showingServiceHistory
                                ? 'service-history'
                                : _currentStep,
                          ),
                          child: _currentStepWidget(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --------------------------------------------------
              // CONTINUE BUTTON
              // --------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _showingServiceHistory
                        ? _finishOnboarding
                        : _continue,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_buttonLabel),
                        const SizedBox(width: 10),
                        Icon(
                          _showingServiceHistory
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RulerMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DLogColors.burgundy
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
