import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import '../../models/maintenance_rule.dart';

import '../../services/maintenance_calculator.dart';

import '../../services/maintenance_status_service.dart';
import '../../repositories/condition_inspection_repository.dart';

import '../../theme/maintenance_status_style.dart';

import 'record_service_screen.dart';
import '../../widgets/condition_checklist_editor.dart';

class MaintenanceListScreen extends StatefulWidget {
  const MaintenanceListScreen({super.key, required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  State<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen> {
  bool _loading = true;

  String? _error;

  List<MaintenanceResult> _results = [];

  final Set<MaintenanceStatus> _selectedStatuses = {};

  /// Latest real service information for each maintenance item.*

  ///*

  /// Stored as raw Firestore data so this screen does not depend on*

  /// a separate ServiceRecordRepository.*

  Map<String, Map<String, dynamic>> _latestServiceByItem = {};

  Map<String, List<Map<String, dynamic>>> _serviceRecordsByItem = {};

  /// The vehicle currently being displayed.*

  Map<String, dynamic> _vehicle = {};

  String get _vehicleId => _vehicle['id']?.toString() ?? '';

  String get _vehicleName {
    final manufacturer = _vehicle['manufacturer']?.toString() ?? '';

    final model = _vehicle['model']?.toString() ?? '';

    if (manufacturer.isEmpty) {
      return model.isEmpty ? 'YOUR VEHICLE' : model.toUpperCase();
    }

    return '$manufacturer $model'.toUpperCase();
  }

  String get _vehicleSubtitle {
    final variant = _vehicle['variant']?.toString() ?? '';

    final year = _vehicle['year']?.toString() ?? '';

    final parts = <String>[
      if (variant.isNotEmpty) variant,

      if (year.isNotEmpty) year,
    ];

    return parts.isEmpty
        ? 'MAINTENANCE PROFILE'
        : parts.join(' • ').toUpperCase();
  }

  int get _currentMileage => (_vehicle['currentMileage'] as num?)?.round() ?? 0;

  String get _ruleGroupId => _vehicle['ruleGroupId']?.toString() ?? '';

  @override
  void initState() {
    super.initState();

    _vehicle = Map<String, dynamic>.from(widget.vehicle);

    _loadMaintenance();
  }

  // ============================================================*

  // LOAD VEHICLE + MAINTENANCE*

  // ============================================================*

  Future<void> _loadMaintenance() async {
    if (!mounted) return;

    setState(() {
      _loading = true;

      _error = null;
    });

    try {
      final snapshot = await const MaintenanceStatusService().loadForVehicle(
        _vehicle,
      );
      final results = snapshot.results;
      final latestByItem = snapshot.latestServiceByItem;
      final serviceRecordsByItem = snapshot.serviceRecordsByItem;

      if (!mounted) return;

      setState(() {
        _vehicle = Map<String, dynamic>.from(snapshot.vehicle);

        _latestServiceByItem = latestByItem;

        _serviceRecordsByItem = serviceRecordsByItem;

        _results = results;

        _loading = false;

        _error = null;
      });
    } catch (e, stackTrace) {
      debugPrint('DLOG MAINTENANCE LIST ERROR: $e');

      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        _loading = false;

        _results = [];

        _error = 'Unable to calculate maintenance right now.';
      });
    }
  }

  Future<bool> _openRecordService({String? maintenanceItem}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecordServiceScreen(
          vehicle: _vehicle,
          preselectedMaintenanceItem: maintenanceItem,
        ),
      ),
    );

    if (saved != true || !mounted) return false;

    await _loadMaintenance();
    return true;
  }

  Future<bool> _editServiceRecord(Map<String, dynamic> service) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            RecordServiceScreen(vehicle: _vehicle, existingRecord: service),
      ),
    );
    return saved == true;
  }

  Future<bool> _deleteServiceRecord(Map<String, dynamic> service) async {
    final recordId = service['id']?.toString();
    if (recordId == null || recordId.isEmpty) {
      throw StateError('The service record ID is missing.');
    }
    await FirebaseFirestore.instance
        .collection('serviceRecords')
        .doc(recordId)
        .delete();
    return true;
  }

  Future<bool> _confirmConditionInspection({
    required MaintenanceRule rule,
    required Map<String, bool> completedChecklist,
    required bool conditionPassed,
  }) async {
    await ConditionInspectionRepository().saveCompletedInspection(
      vehicleId: _vehicleId,
      maintenanceItem: rule.maintenanceItem,
      inspectionDate: DateTime.now(),
      odometerAtInspection: _currentMileage,
      completedChecklist: completedChecklist,
      conditionPassed: conditionPassed,
    );
    return true;
  }

  // ============================================================*

  // SERVICE RECORD HELPERS*

  // ============================================================*

  Map<String, dynamic>? _findServiceForRule(
    MaintenanceRule rule,

    Map<String, Map<String, dynamic>> records,
  ) {
    final exact = records[rule.maintenanceItem];

    if (exact != null) {
      return exact;
    }

    // Small compatibility layer for any older naming variation.*

    final target = rule.maintenanceItem.trim().toLowerCase();

    for (final entry in records.entries) {
      if (entry.key.trim().toLowerCase() == target) {
        return entry.value;
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _findServiceHistoryForRule(
    MaintenanceRule rule,
    Map<String, List<Map<String, dynamic>>> records,
  ) {
    final target = rule.maintenanceItem.trim().toLowerCase();
    for (final entry in records.entries) {
      if (entry.key.trim().toLowerCase() == target) {
        return entry.value;
      }
    }
    return const [];
  }

  int? _readInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return int.tryParse(value.toString());
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  // ============================================================*

  // FILTERING*

  // ============================================================*

  List<MaintenanceResult> get _filteredResults {
    if (_selectedStatuses.isEmpty) {
      return _results;
    }

    return _results.where((result) {
      return _selectedStatuses.contains(result.status);
    }).toList();
  }

  int _countStatus(MaintenanceStatus status) {
    return MaintenanceCalculator.countStatus(_results, status);
  }

  void _toggleStatus(MaintenanceStatus status) {
    setState(() {
      if (_selectedStatuses.contains(status)) {
        _selectedStatuses.remove(status);
      } else {
        _selectedStatuses.add(status);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatuses.clear();
    });
  }

  // ============================================================*

  // STATUS*

  // ============================================================*

  String _statusLabel(
    MaintenanceStatus status, {
    bool requiresHistory = false,
  }) {
    if (requiresHistory && status == MaintenanceStatus.dueSoon) {
      return 'RECORD NEEDED';
    }

    switch (status) {
      case MaintenanceStatus.allGood:
        return 'ALL GOOD';

      case MaintenanceStatus.dueSoon:
        return 'DUE SOON';

      case MaintenanceStatus.dueNow:
        return 'DUE NOW';

      case MaintenanceStatus.gracePeriod:
        return 'GRACE PERIOD';
    }
  }

  Color _statusColor(MaintenanceStatus status) =>
      MaintenanceStatusStyle.colorFor(status);

  // ============================================================*

  // MAINTENANCE ACTION*

  // ============================================================*

  IconData _actionIcon(MaintenanceAction action) {
    switch (action) {
      case MaintenanceAction.replace:
        return Icons.build_circle_outlined;

      case MaintenanceAction.inspect:
        return Icons.search_rounded;

      case MaintenanceAction.clean:
        return Icons.auto_awesome_outlined;

      case MaintenanceAction.rotate:
        return Icons.rotate_right_rounded;

      case MaintenanceAction.check:
        return Icons.fact_check_outlined;

      case MaintenanceAction.adjust:
        return Icons.tune_rounded;
    }
  }

  String _actionLabel(MaintenanceAction action) {
    switch (action) {
      case MaintenanceAction.replace:
        return 'REPLACE';

      case MaintenanceAction.inspect:
        return 'INSPECT';

      case MaintenanceAction.clean:
        return 'CLEAN';

      case MaintenanceAction.rotate:
        return 'ROTATE';

      case MaintenanceAction.check:
        return 'CHECK';

      case MaintenanceAction.adjust:
        return 'ADJUST';
    }
  }

  // ============================================================*

  // FORMATTING*

  // ============================================================*

  String _formatKm(int? mileage) {
    if (mileage == null) {
      return 'N/A';
    }

    final formatted = mileage.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),

      (match) => '${match[1]},',
    );

    return '$formatted KM';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'NOT RECORDED';
    }

    const months = <String>[
      'JAN',

      'FEB',

      'MAR',

      'APR',

      'MAY',

      'JUN',

      'JUL',

      'AUG',

      'SEP',

      'OCT',

      'NOV',

      'DEC',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  String _dueDescription(MaintenanceResult result) {
    if (result.rule.isConditionBased) {
      return 'INSPECT BY CONDITION';
    }

    if (result.requiresHistory) {
      final intervals = <String>[];
      if (result.rule.mileageInterval != null) {
        intervals.add('EVERY ${_formatKm(result.rule.mileageInterval)}');
      }
      if (result.rule.timeIntervalMonths != null) {
        intervals.add('EVERY ${result.rule.timeIntervalMonths} MONTHS');
      }
      return intervals.isEmpty
          ? 'LAST SERVICE RECORD NEEDED'
          : '${intervals.join(' / ')} • LAST SERVICE NEEDED';
    }

    if (result.nextDueMileage != null) {
      final remaining = result.remainingMileage;

      if (result.isAllGood && remaining != null && remaining > 0) {
        return '${_formatKm(result.nextDueMileage)} • '
            '${_formatKm(remaining)} remaining';
      }

      if (result.isDueNow) {
        return '${_formatKm(result.nextDueMileage)} • '
            'Maintenance due now';
      }

      if (result.isGracePeriod) {
        return '${_formatKm(result.nextDueMileage)} • '
            'Grace period';
      }

      if (result.isDueSoon) {
        return '${_formatKm(result.nextDueMileage)} • '
            'Due soon';
      }

      return _formatKm(result.nextDueMileage);
    }

    if (result.nextDueDate != null) {
      if (result.remainingDays != null &&
          result.remainingDays! > 0 &&
          result.isAllGood) {
        return '${_formatDate(result.nextDueDate)} • '
            '${result.remainingDays} days remaining';
      }

      return _formatDate(result.nextDueDate);
    }

    return 'CONDITION-BASED MAINTENANCE';
  }

  String _lastServiceText(String item) {
    final service = _findServiceForRule(
      _results.firstWhere((result) => result.rule.maintenanceItem == item).rule,

      _latestServiceByItem,
    );

    if (service == null) {
      return 'NO SERVICE RECORD';
    }

    final mileage = _readInt(service['mileage'] ?? service['mileageAtService']);

    final date = _readDate(service['serviceDate']);

    return 'LAST SERVICE • '
        '${_formatKm(mileage)} • '
        '${_formatDate(date)}';
  }

  // ============================================================*

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070708),
      body: SafeArea(
        child: _loading
            ? _buildLoading()
            : _error != null
            ? _buildError()
            : _buildContent(),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Column(
      children: [
        _buildTopBar(),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFB83255),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE56A6A).withOpacity(0.10),
                      border: Border.all(
                        color: const Color(0xFFE56A6A).withOpacity(0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE56A6A).withOpacity(0.12),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE56A6A),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'MAINTENANCE UNAVAILABLE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF9EA2A8),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _loadMaintenance,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF9A1F3D),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9A1F3D).withOpacity(0.25),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const Text(
                        'RETRY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    final filtered = _filteredResults;

    return Column(
      children: [
        // Fixed navigation bar.
        _buildTopBar(),

        // Fixed vehicle identity / odometer block.
        _buildHeaderSection(),

        // Everything below the vehicle header is the scrollable maintenance area.
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFB83255),
            backgroundColor: const Color(0xFF151518),
            onRefresh: _loadMaintenance,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _buildSummarySection(),
                _buildFilterSection(),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
                    child: _buildNoResults(),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 34),
                    child: Column(
                      children: [
                        for (int index = 0; index < filtered.length; index++)
                          _buildMaintenanceCard(filtered[index], index),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFF070708),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Row(
        children: [
          _topIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
            accent: false,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'MAINTENANCE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
          _topIconButton(
            icon: Icons.add_rounded,
            onTap: _showAddMenu,
            accent: true,
          ),
          const SizedBox(width: 8),
          _topIconButton(
            icon: Icons.refresh_rounded,
            onTap: _loadMaintenance,
            accent: false,
          ),
        ],
      ),
    );
  }

  Widget _topIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool accent,
  }) {
    final base = accent ? const Color(0xFF9A1F3D) : const Color(0xFF151518);
    final border = accent ? const Color(0xFFCE5274) : const Color(0xFF303036);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: base,
            border: Border.all(color: border),
            boxShadow: accent
                ? [
                    BoxShadow(
                      color: const Color(0xFFB83255).withOpacity(0.28),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: accent ? Colors.white : const Color(0xFFC9CDD2),
            size: 21,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADD MENU
  // ============================================================

  void _showAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
          decoration: const BoxDecoration(
            color: Color(0xFF111113),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      color: const Color(0xFF3A3A40),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'ADD TO LOG',
                  style: TextStyle(
                    color: Color(0xFF777B82),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'What would you like to add?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                _addMenuOption(
                  icon: Icons.build_circle_outlined,
                  title: 'RECORD SERVICE',
                  subtitle: 'Log a completed maintenance service',
                  color: const Color(0xFFC9CDD2),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openRecordService();
                  },
                ),
                const SizedBox(height: 10),
                _addMenuOption(
                  icon: Icons.add_task_rounded,
                  title: 'ADD MAINTENANCE',
                  subtitle: 'Add a maintenance item to this vehicle',
                  color: const Color(0xFFCE5274),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Custom maintenance is not connected to the vehicle rule set yet.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _addMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF17171A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.28)),
                ),
                child: Icon(icon, color: color, size: 23),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF777B82),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // VEHICLE HEADER
  // ============================================================

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 7, 20, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF070708),
        border: Border(bottom: BorderSide(color: Color(0xFF17171A))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _vehicleName,
            style: const TextStyle(
              color: Color(0xFF858A91),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _vehicleSubtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'CURRENT ODOMETER',
                style: TextStyle(
                  color: Color(0xFF62666D),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF9A1F3D).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: const Color(0xFFB83255).withOpacity(0.28),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Color(0xFFCE5274), size: 6),
                    SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Color(0xFFCE5274),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _formatKm(_currentMileage),
            style: const TextStyle(
              color: Color(0xFFE7E9EC),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummarySection() {
    final good = _countStatus(MaintenanceStatus.allGood);
    final soon = _countStatus(MaintenanceStatus.dueSoon);
    final due = _countStatus(MaintenanceStatus.dueNow);
    final grace = _countStatus(MaintenanceStatus.gracePeriod);
    final attention = due + grace;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 17, 16, 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF19191C), Color(0xFF0D0D0F)],
          ),
          border: Border.all(color: const Color(0xFF2E2E34)),
          boxShadow: [
            BoxShadow(
              color: attention > 0
                  ? const Color(0xFFE56A6A).withOpacity(0.10)
                  : const Color(0xFFB83255).withOpacity(0.07),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'MAINTENANCE OVERVIEW',
                    style: TextStyle(
                      color: Color(0xFF73777E),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                if (attention > 0)
                  Text(
                    '$attention NEED ATTENTION',
                    style: const TextStyle(
                      color: Color(0xFFE56A6A),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  )
                else
                  const Text(
                    'VEHICLE ON TRACK',
                    style: TextStyle(
                      color: Color(0xFFC9CDD2),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _summaryItem('GOOD', good, const Color(0xFF55D98A)),
                ),
                _summaryDivider(),
                Expanded(
                  child: _summaryItem('SOON', soon, const Color(0xFFE1C47A)),
                ),
                _summaryDivider(),
                Expanded(
                  child: _summaryItem('DUE', due, const Color(0xFFE56A6A)),
                ),
                _summaryDivider(),
                Expanded(
                  child: _summaryItem(
                    'GRACE PERIOD',
                    grace,
                    const Color(0xFFCE5274),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, int count, Color color) {
    final emphasized = label == 'DUE' || label == 'GRACE PERIOD';

    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: emphasized ? 27 : 24,
            fontWeight: FontWeight.w900,
            height: 1,
            shadows: emphasized
                ? [Shadow(color: color.withOpacity(0.45), blurRadius: 13)]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF777B82),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _summaryDivider() {
    return Container(width: 1, height: 38, color: const Color(0xFF303036));
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 3, bottom: 9),
            child: Text(
              'FILTER BY STATUS',
              style: TextStyle(
                color: Color(0xFF62666D),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Container(
            height: 52,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF111113),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFF29292F)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _filterSegment(
                    label: 'ALL',
                    selected: _selectedStatuses.isEmpty,
                    color: const Color(0xFFC9CDD2),
                    onTap: _clearFilters,
                  ),
                ),
                Expanded(
                  child: _filterSegment(
                    label: 'GOOD',
                    count: _countStatus(MaintenanceStatus.allGood),
                    selected: _selectedStatuses.contains(
                      MaintenanceStatus.allGood,
                    ),
                    color: const Color(0xFF55D98A),
                    onTap: () => _toggleStatus(MaintenanceStatus.allGood),
                  ),
                ),
                Expanded(
                  child: _filterSegment(
                    label: 'SOON',
                    count: _countStatus(MaintenanceStatus.dueSoon),
                    selected: _selectedStatuses.contains(
                      MaintenanceStatus.dueSoon,
                    ),
                    color: const Color(0xFFE1C47A),
                    onTap: () => _toggleStatus(MaintenanceStatus.dueSoon),
                  ),
                ),
                Expanded(
                  child: _filterSegment(
                    label: 'DUE',
                    count: _countStatus(MaintenanceStatus.dueNow),
                    selected: _selectedStatuses.contains(
                      MaintenanceStatus.dueNow,
                    ),
                    color: const Color(0xFFE56A6A),
                    onTap: () => _toggleStatus(MaintenanceStatus.dueNow),
                  ),
                ),
                Expanded(
                  child: _filterSegment(
                    label: 'GRACE PERIOD',
                    count: _countStatus(MaintenanceStatus.gracePeriod),
                    selected: _selectedStatuses.contains(
                      MaintenanceStatus.gracePeriod,
                    ),
                    color: const Color(0xFFCE5274),
                    onTap: () => _toggleStatus(MaintenanceStatus.gracePeriod),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'MAINTENANCE',
                style: TextStyle(
                  color: Color(0xFF777B82),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const Spacer(),
              Text(
                '${_filteredResults.length} ITEMS',
                style: const TextStyle(
                  color: Color(0xFF555960),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterSegment({
    required String label,
    int? count,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? color.withOpacity(0.45) : Colors.transparent,
        ),
        boxShadow: selected
            ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 14)]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? color : const Color(0xFF8D9299),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: selected
                            ? color.withOpacity(0.78)
                            : const Color(0xFF555960),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAINTENANCE CARDS
  // ============================================================

  Widget _buildMaintenanceCard(MaintenanceResult result, int index) {
    final item = result.rule.maintenanceItem;
    final statusColor = _statusColor(result.status);
    final urgencyNumber = _urgencyNumber(result.status);

    return TweenAnimationBuilder<double>(
      key: ValueKey('${item}_${result.status}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 320 + (index.clamp(0, 7).toInt() * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 38,
                child: Column(
                  children: [
                    _timelineNode(urgencyNumber, statusColor, result),
                    if (index < _filteredResults.length - 1)
                      Expanded(
                        child: Container(
                          width: 1.4,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                statusColor.withOpacity(0.75),
                                const Color(0xFF34343A).withOpacity(0.18),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(child: _maintenanceCardBody(result, item, statusColor)),
            ],
          ),
        ),
      ),
    );
  }

  int _urgencyNumber(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.dueNow:
        return 1;
      case MaintenanceStatus.gracePeriod:
        return 2;
      case MaintenanceStatus.dueSoon:
        return 3;
      case MaintenanceStatus.allGood:
        return 4;
    }
  }

  Widget _timelineNode(int number, Color color, MaintenanceResult result) {
    final strong = result.isDueNow || result.isGracePeriod || result.isAllGood;

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(strong ? 0.24 : 0.13),
            color.withOpacity(0.04),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(strong ? 0.78 : 0.40),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(strong ? 0.34 : 0.10),
            blurRadius: strong ? 19 : 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        number.toString().padLeft(2, '0'),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _maintenanceCardBody(
    MaintenanceResult result,
    String item,
    Color statusColor,
  ) {
    final service = _findServiceForRule(result.rule, _latestServiceByItem);

    final hasMileageProgress = result.nextDueMileage != null;
    final hasDateProgress = result.nextDueDate != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _showMaintenanceDetail(result),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF17171A),
                result.isDueNow
                    ? const Color(0xFF1B1215)
                    : result.isGracePeriod
                    ? const Color(0xFF1A1014)
                    : const Color(0xFF101012),
              ],
            ),
            border: Border.all(
              color: result.isDueNow || result.isGracePeriod
                  ? statusColor.withOpacity(0.62)
                  : const Color(0xFF2D2D33),
            ),
            boxShadow: [
              BoxShadow(
                color: result.isDueNow || result.isGracePeriod
                    ? statusColor.withOpacity(0.10)
                    : Colors.black.withOpacity(0.18),
                blurRadius: result.isDueNow || result.isGracePeriod ? 24 : 12,
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: statusColor.withOpacity(0.28)),
                    ),
                    child: Icon(
                      _actionIcon(result.rule.action),
                      color: statusColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item,
                          style: const TextStyle(
                            color: Color(0xFFF4F5F6),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _actionLabel(result.rule.action),
                          style: const TextStyle(
                            color: Color(0xFF777B82),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(
                    _statusLabel(
                      result.status,
                      requiresHistory: result.requiresHistory,
                    ),
                    statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildStatusHeadline(result, statusColor),
              if (result.isGracePeriod &&
                  result.graceProgressUsesMileage &&
                  hasMileageProgress) ...[
                const SizedBox(height: 16),
                _buildMileageProgress(result, statusColor),
              ] else if (result.isGracePeriod && hasDateProgress) ...[
                const SizedBox(height: 16),
                _buildGraceDateProgress(result, statusColor),
              ] else if (hasMileageProgress) ...[
                const SizedBox(height: 16),
                _buildMileageProgress(result, statusColor),
              ] else if (hasDateProgress) ...[
                const SizedBox(height: 16),
                _buildDateProgress(result, statusColor),
              ],
              const SizedBox(height: 16),
              _buildServiceMeta(result, service),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeadline(MaintenanceResult result, Color statusColor) {
    String headline;
    final service = _findServiceForRule(result.rule, _latestServiceByItem);

    if (result.rule.isConditionBased && result.conditionAssessmentRequired) {
      headline = 'CONDITION INSPECTION REQUIRED';
    } else if (result.rule.isConditionBased &&
        service?['conditionPassed'] == false) {
      headline = 'INSPECTION FOUND AN ISSUE';
    } else if (result.rule.isConditionBased && result.remainingDays != null) {
      headline = result.isGracePeriod
          ? '${result.graceProgressUsed} / ${result.graceProgressWindow} DAYS GRACE USED'
          : result.isDueNow
          ? 'CONDITION INSPECTION DUE NOW'
          : '${result.remainingDays} DAYS UNTIL NEXT CHECK';
    } else if (result.requiresHistory) {
      headline = 'RECORD LAST SERVICE TO CALCULATE NEXT DUE';
    } else if (result.isAllGood && result.remainingMileage != null) {
      headline = '${_formatKm(result.remainingMileage)} LEFT';
    } else if (result.isDueNow) {
      headline = 'MAINTENANCE DUE NOW';
    } else if (result.isGracePeriod) {
      final unit = result.graceProgressUsesMileage ? 'KM' : 'DAYS';
      headline = result.graceExceededBy > 0
          ? 'GRACE LIMIT EXCEEDED BY ${result.graceProgressUsesMileage ? _formatKm(result.graceExceededBy) : '${result.graceExceededBy} DAYS'}'
          : '${result.graceProgressUsed} / ${result.graceProgressWindow} $unit GRACE USED';
    } else if (result.isDueSoon) {
      headline = result.remainingMileage != null
          ? '${_formatKm(result.remainingMileage)} UNTIL DUE'
          : 'DUE SOON';
    } else {
      headline = _dueDescription(result);
    }

    return Text(
      headline,
      style: TextStyle(
        color: statusColor,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
        shadows: [
          Shadow(
            color: statusColor.withOpacity(
              result.isDueNow || result.isGracePeriod ? 0.30 : 0.08,
            ),
            blurRadius: 12,
          ),
        ],
      ),
    );
  }

  Widget _buildMileageProgress(MaintenanceResult result, Color statusColor) {
    if (result.isGracePeriod && result.graceProgressUsesMileage) {
      return _buildGraceMileageProgress(result, statusColor);
    }

    final service = _findServiceForRule(result.rule, _latestServiceByItem);

    final serviceMileage = _readInt(
      service?['mileage'] ?? service?['mileageAtService'],
    );

    final dueMileage = result.nextDueMileage!;
    final startMileage = serviceMileage ?? 0;
    final total = dueMileage - startMileage;

    double progress;

    if (total <= 0) {
      progress = result.isAllGood ? 0.0 : 1.0;
    } else {
      progress = ((_currentMileage - startMileage) / total)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    final remainingLabel = result.remainingMileage != null
        ? _formatKm(result.remainingMileage)
        : _formatKm(dueMileage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'SERVICE PROGRESS',
              style: TextStyle(
                color: Color(0xFF62666D),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Text(
              remainingLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 9,
            decoration: const BoxDecoration(color: Color(0xFF29292E)),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusColor.withOpacity(0.72), statusColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.38),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Text(
              _formatKm(startMileage),
              style: const TextStyle(
                color: Color(0xFF555960),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              _formatKm(dueMileage),
              style: const TextStyle(
                color: Color(0xFF777B82),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGraceMileageProgress(
    MaintenanceResult result,
    Color statusColor,
  ) {
    final dueMileage = result.nextDueMileage!;
    final graceWindow = result.graceWindowMileage;
    final graceEndMileage = dueMileage + graceWindow;
    final used = result.graceProgressUsed;
    final progress = graceWindow <= 0
        ? 1.0
        : (used / graceWindow).clamp(0.0, 1.0).toDouble();
    final progressLabel = result.graceExceededBy > 0
        ? 'GRACE LIMIT EXCEEDED'
        : '${_formatKm(used)} / ${_formatKm(graceWindow)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'GRACE PERIOD PROGRESS',
              style: TextStyle(
                color: Color(0xFF62666D),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Text(
              progressLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 9,
            color: const Color(0xFF29292E),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 850),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor.withOpacity(0.72), statusColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.38),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Text(
              _formatKm(dueMileage),
              style: const TextStyle(
                color: Color(0xFF555960),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              _formatKm(graceEndMileage),
              style: const TextStyle(
                color: Color(0xFF777B82),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGraceDateProgress(MaintenanceResult result, Color statusColor) {
    final dueDate = result.nextDueDate!;
    final graceEndDate = dueDate.add(Duration(days: result.graceWindowDays));
    final used = result.graceProgressUsed;
    final window = result.graceProgressWindow;
    final progress = window <= 0
        ? 1.0
        : (used / window).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'GRACE PERIOD PROGRESS',
              style: TextStyle(
                color: Color(0xFF62666D),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Text(
              result.graceExceededBy > 0
                  ? 'GRACE LIMIT EXCEEDED'
                  : '$used / $window DAYS',
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 9,
            color: const Color(0xFF29292E),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: ColoredBox(color: statusColor),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Text(
              _formatDate(dueDate),
              style: const TextStyle(
                color: Color(0xFF555960),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              _formatDate(graceEndDate),
              style: const TextStyle(
                color: Color(0xFF777B82),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateProgress(MaintenanceResult result, Color statusColor) {
    final days = result.remainingDays;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.055),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: statusColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: statusColor, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              days != null && days > 0
                  ? '$days DAYS UNTIL ${_formatDate(result.nextDueDate)}'
                  : _formatDate(result.nextDueDate),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceMeta(
    MaintenanceResult result,
    Map<String, dynamic>? service,
  ) {
    final conditionBased = result.rule.isConditionBased;
    final conditionNeedsAttention =
        conditionBased && service?['conditionPassed'] == false;
    final nextService = conditionBased
        ? conditionNeedsAttention
              ? 'ATTENTION REQUIRED'
              : result.nextDueDate == null
              ? 'INSPECTION NOT RECORDED'
              : _formatDate(result.nextDueDate)
        : _nextServiceDescription(result);

    final serviceMileage = _readInt(
      service?['mileageAtInspection'] ??
          service?['mileage'] ??
          service?['mileageAtService'],
    );
    final serviceDate = _readDate(
      service?['inspectionDate'] ?? service?['serviceDate'],
    );
    final lastService = service == null
        ? conditionBased
              ? 'NOT RECORDED'
              : 'NO SERVICE RECORD'
        : '${_formatKm(serviceMileage)} • ${_formatDate(serviceDate)}';

    return Column(
      children: [
        _serviceInfoCard(
          icon: Icons.event_repeat_rounded,
          label: conditionBased ? 'NEXT CHECK' : 'NEXT SERVICE',
          value: nextService,
          accent: _statusColor(result.status),
        ),
        const SizedBox(height: 9),
        _serviceInfoCard(
          icon: Icons.history_rounded,
          label: conditionBased ? 'LAST INSPECTION' : 'LAST SERVICE',
          value: lastService,
          accent: const Color(0xFF858A91),
        ),
      ],
    );
  }

  String _nextServiceDescription(MaintenanceResult result) {
    if (result.rule.isConditionBased) return 'INSPECT BY CONDITION';
    if (result.nextDueMileage != null) {
      return _formatKm(result.nextDueMileage);
    }
    if (result.nextDueDate != null) return _formatDate(result.nextDueDate);
    if (result.requiresHistory) return 'LAST SERVICE RECORD NEEDED';
    if (result.rule.mileageInterval == null &&
        result.rule.timeIntervalMonths == null) {
      return 'NO FIXED INTERVAL';
    }
    return 'NOT APPLICABLE';
  }

  Widget _serviceInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: const Color(0xFF121214),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF29292F)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(color: accent.withOpacity(0.28), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF747980),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE3E5E8),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.38)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10)],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY FILTER
  // ============================================================

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.filter_alt_off_rounded,
              color: Color(0xFF55585E),
              size: 40,
            ),
            const SizedBox(height: 14),
            const Text(
              'NO MATCHING MAINTENANCE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Clear the current filter to view all maintenance items.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF777B82),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _clearFilters,
              child: const Text(
                'CLEAR FILTER',
                style: TextStyle(
                  color: Color(0xFFCE5274),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAIL PAGE
  // ============================================================

  Future<void> _showMaintenanceDetail(MaintenanceResult result) async {
    final service = _findServiceForRule(result.rule, _latestServiceByItem);
    final serviceHistory = _findServiceHistoryForRule(
      result.rule,
      _serviceRecordsByItem,
    );

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _MaintenanceDetailPage(
          result: result,
          service: service,
          serviceHistory: serviceHistory,
          vehicleName: _vehicleName,
          vehicleSubtitle: _vehicleSubtitle,
          currentMileage: _currentMileage,
          onRecordService: () =>
              _openRecordService(maintenanceItem: result.rule.maintenanceItem),
          onConfirmInspection: (checklist, passed) =>
              _confirmConditionInspection(
                rule: result.rule,
                completedChecklist: checklist,
                conditionPassed: passed,
              ),
          onEditService: _editServiceRecord,
          onDeleteService: _deleteServiceRecord,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _loadMaintenance();
    }
  }
}

class _MaintenanceDetailPage extends StatelessWidget {
  const _MaintenanceDetailPage({
    required this.result,
    required this.service,
    required this.serviceHistory,
    required this.vehicleName,
    required this.vehicleSubtitle,
    required this.currentMileage,
    required this.onRecordService,
    required this.onConfirmInspection,
    required this.onEditService,
    required this.onDeleteService,
  });

  final MaintenanceResult result;
  final Map<String, dynamic>? service;
  final List<Map<String, dynamic>> serviceHistory;
  final String vehicleName;
  final String vehicleSubtitle;
  final int currentMileage;
  final Future<bool> Function() onRecordService;
  final Future<bool> Function(Map<String, bool>, bool) onConfirmInspection;
  final Future<bool> Function(Map<String, dynamic>) onEditService;
  final Future<bool> Function(Map<String, dynamic>) onDeleteService;

  Color get _statusColor => MaintenanceStatusStyle.colorFor(result.status);

  String get _statusLabel {
    if (result.requiresHistory) return 'RECORD NEEDED';

    switch (result.status) {
      case MaintenanceStatus.allGood:
        return 'ALL GOOD';
      case MaintenanceStatus.dueSoon:
        return 'DUE SOON';
      case MaintenanceStatus.dueNow:
        return 'DUE NOW';
      case MaintenanceStatus.gracePeriod:
        return 'GRACE PERIOD';
    }
  }

  IconData get _actionIcon {
    switch (result.rule.action) {
      case MaintenanceAction.replace:
        return Icons.build_circle_outlined;
      case MaintenanceAction.inspect:
        return Icons.search_rounded;
      case MaintenanceAction.clean:
        return Icons.auto_awesome_outlined;
      case MaintenanceAction.rotate:
        return Icons.rotate_right_rounded;
      case MaintenanceAction.check:
        return Icons.fact_check_outlined;
      case MaintenanceAction.adjust:
        return Icons.tune_rounded;
    }
  }

  String get _actionLabel {
    switch (result.rule.action) {
      case MaintenanceAction.replace:
        return 'REPLACE';
      case MaintenanceAction.inspect:
        return 'INSPECT';
      case MaintenanceAction.clean:
        return 'CLEAN';
      case MaintenanceAction.rotate:
        return 'ROTATE';
      case MaintenanceAction.check:
        return 'CHECK';
      case MaintenanceAction.adjust:
        return 'ADJUST';
    }
  }

  String _formatKm(int? mileage) {
    if (mileage == null) return 'N/A';

    final formatted = mileage.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

    return '$formatted KM';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'NOT RECORDED';

    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070708),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildTopBar(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHero(),
                  const SizedBox(height: 26),
                  _buildSectionLabel('STATUS'),
                  const SizedBox(height: 9),
                  _buildStatusCard(),
                  if (result.rule.isConditionBased) ...[
                    const SizedBox(height: 26),
                    _buildSectionLabel('CONDITION CHECK'),
                    const SizedBox(height: 9),
                    _buildConditionChecklist(),
                  ] else if (result.requiresHistory) ...[
                    const SizedBox(height: 12),
                    _buildRecordEntryButton(context),
                  ],
                  const SizedBox(height: 26),
                  _buildSectionLabel(
                    result.rule.isConditionBased
                        ? 'INSPECTION STATUS'
                        : 'SERVICE PROGRESS',
                  ),
                  const SizedBox(height: 9),
                  _buildProgressCard(),
                  const SizedBox(height: 26),
                  _buildSectionLabel(
                    result.rule.isConditionBased ? 'NEXT CHECK' : 'SCHEDULE',
                  ),
                  const SizedBox(height: 9),
                  _buildScheduleCard(),
                  const SizedBox(height: 26),
                  _buildSectionLabel(
                    result.rule.isConditionBased
                        ? 'INSPECTION HISTORY'
                        : 'SERVICE HISTORY',
                  ),
                  const SizedBox(height: 9),
                  _buildHistoryCard(context),
                  if (result.rule.maintenanceItem.trim().toLowerCase() ==
                      'engine oil') ...[
                    const SizedBox(height: 26),
                    _buildSectionLabel('ENGINE OIL SPECIFICATION'),
                    const SizedBox(height: 9),
                    _buildEngineOilMetadataCard(),
                  ],
                  const SizedBox(height: 26),
                  _buildSectionLabel('MAINTENANCE SOURCE'),
                  const SizedBox(height: 9),
                  _buildSourceCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 42,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF151518),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFF303036)),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFFC9CDD2),
                  size: 21,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'MAINTENANCE DETAIL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          vehicleName,
          style: const TextStyle(
            color: Color(0xFF777B82),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          vehicleSubtitle,
          style: const TextStyle(
            color: Color(0xFF8D9299),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          result.rule.maintenanceItem,
          style: const TextStyle(
            color: Color(0xFFF4F5F6),
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          _actionLabel,
          style: TextStyle(
            color: _statusColor,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.7,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF62666D),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.6,
      ),
    );
  }

  Widget _buildRecordEntryButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () async {
          final saved = await onRecordService();
          if (saved && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        icon: const Icon(Icons.add_task_rounded, size: 18),
        label: Text(
          result.conditionAssessmentRequired
              ? 'RECORD INSPECTION'
              : 'ADD SERVICE RECORD',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _statusColor,
          backgroundColor: _statusColor.withOpacity(0.08),
          side: BorderSide(color: _statusColor.withOpacity(0.55)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }

  Widget _buildConditionChecklist() {
    final policy = result.rule.conditionInspectionPolicy;
    if (policy == null) {
      return _panel(
        child: const Text(
          'This condition check has no configured checklist yet.',
          style: TextStyle(color: Color(0xFF9EA2A8), fontSize: 12),
        ),
      );
    }

    return _ConditionInspectionChecklist(
      items: policy.checklistItems,
      accentColor: _statusColor,
      currentMileage: currentMileage,
      onConfirm: onConfirmInspection,
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: _statusColor.withOpacity(0.055),
        border: Border.all(color: _statusColor.withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.12),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor.withOpacity(0.10),
              border: Border.all(color: _statusColor.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: _statusColor.withOpacity(0.18),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Icon(_actionIcon, color: _statusColor, size: 25),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusHeadline,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _statusHeadline {
    if (result.rule.isConditionBased) {
      if (result.conditionAssessmentRequired) {
        return 'Complete the checklist to record the first inspection';
      }
      if (service?['conditionPassed'] == false) {
        return 'Inspection found an item needing attention';
      }
      if (result.isAllGood && result.remainingDays != null) {
        return 'Condition check completed; next check in ${result.remainingDays} days';
      }
      if (result.isDueSoon && result.remainingDays != null) {
        return 'Condition inspection due in ${result.remainingDays} days';
      }
      if (result.isDueNow) return 'Condition inspection is due';
      if (result.isGracePeriod) {
        return 'Inspection is ${result.graceUsedDays} days past due';
      }
    }

    if (result.requiresHistory) {
      return 'Record the last actual service to calculate the next milestone';
    }

    if (result.isAllGood && result.remainingMileage != null) {
      return '${_formatKm(result.remainingMileage)} remaining';
    }

    if (result.isDueNow) {
      return 'Maintenance is due now';
    }

    if (result.isGracePeriod) {
      if (result.graceExceededBy > 0) {
        final overage = result.graceProgressUsesMileage
            ? _formatKm(result.graceExceededBy)
            : '${result.graceExceededBy} days';
        return 'Grace limit exceeded by $overage';
      }
      final unit = result.graceProgressUsesMileage ? 'km' : 'days';
      return '${result.graceProgressUsed} of '
          '${result.graceProgressWindow} $unit grace used';
    }

    if (result.isDueSoon) {
      return result.remainingMileage != null
          ? '${_formatKm(result.remainingMileage)} until due'
          : 'Maintenance is due soon';
    }

    return 'Condition-based maintenance';
  }

  Widget _buildProgressCard() {
    if (result.isGracePeriod) {
      return _buildGraceProgressCard();
    }

    if (result.rule.isConditionBased) {
      if (result.nextDueDate != null) {
        return _buildConditionDateProgress();
      }
      return _buildScheduleBasisCard(
        icon: Icons.search_rounded,
        title: 'CONDITION INSPECTION',
        message: service?['conditionPassed'] == false
            ? 'The latest inspection found an issue. Record a passing inspection after it has been addressed.'
            : 'No completed inspection is recorded yet. Complete the checklist above to start this item’s DLog reminder cadence.',
      );
    }

    if (result.requiresHistory) {
      return _buildScheduleBasisCard(
        icon: Icons.history_rounded,
        title: _scheduleIntervalDescription,
        message:
            'No last service record is saved for this item. Add the most recent actual service and DLog will calculate the next milestone.',
      );
    }

    if (result.nextDueMileage != null) {
      final serviceMileage = _readInt(
        service?['mileage'] ?? service?['mileageAtService'],
      );

      final dueMileage = result.nextDueMileage!;
      final startMileage = serviceMileage ?? 0;
      final total = dueMileage - startMileage;

      final double progress = total <= 0
          ? (result.isAllGood ? 0.0 : 1.0)
          : ((currentMileage - startMileage) / total)
                .clamp(0.0, 1.0)
                .toDouble();

      return _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'MILEAGE LIFESPAN',
                  style: TextStyle(
                    color: Color(0xFF777B82),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).round()}% USED',
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Container(
                height: 13,
                color: const Color(0xFF29292E),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_statusColor.withOpacity(0.72), _statusColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _statusColor.withOpacity(0.40),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  _formatKm(startMileage),
                  style: const TextStyle(
                    color: Color(0xFF555960),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatKm(dueMileage),
                  style: const TextStyle(
                    color: Color(0xFF9EA2A8),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatKm(currentMileage),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Text(
                    'CURRENT',
                    style: TextStyle(
                      color: Color(0xFF62666D),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  result.remainingMileage != null
                      ? '${_formatKm(result.remainingMileage)} REMAINING'
                      : _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return _panel(
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: _statusColor, size: 23),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DATE-BASED MAINTENANCE',
                  style: TextStyle(
                    color: Color(0xFF777B82),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(result.nextDueDate),
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (result.remainingDays != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.remainingDays! > 0
                        ? '${result.remainingDays} days remaining'
                        : 'Maintenance due',
                    style: const TextStyle(
                      color: Color(0xFF9EA2A8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionDateProgress() {
    final policy = result.rule.conditionInspectionPolicy;
    final intervalDays = policy?.checkIntervalDays ?? 0;
    final remaining = result.remainingDays ?? 0;
    final progress = intervalDays <= 0
        ? 0.0
        : ((intervalDays - remaining) / intervalDays)
              .clamp(0.0, 1.0)
              .toDouble();
    final lastInspection = _readDate(
      service?['inspectionDate'] ?? service?['serviceDate'],
    );

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'INSPECTION CYCLE',
                style: TextStyle(
                  color: Color(0xFF777B82),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}% ELAPSED',
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 11,
              backgroundColor: const Color(0xFF29292E),
              valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'LAST ${_formatDate(lastInspection)}',
                style: const TextStyle(
                  color: Color(0xFF777B82),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'NEXT ${_formatDate(result.nextDueDate)}',
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (policy != null) ...[
            const SizedBox(height: 10),
            Text(
              'DLog inspection reminder: every ${policy.checkIntervalDays} days',
              style: const TextStyle(color: Color(0xFF777B82), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  String get _scheduleIntervalDescription {
    final intervals = <String>[];
    if (result.rule.mileageInterval != null) {
      intervals.add('EVERY ${_formatKm(result.rule.mileageInterval)}');
    }
    if (result.rule.timeIntervalMonths != null) {
      intervals.add('EVERY ${result.rule.timeIntervalMonths} MONTHS');
    }
    return intervals.isEmpty ? 'SCHEDULE' : intervals.join(' / ');
  }

  Widget _buildScheduleBasisCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return _panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF777B82),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFC9CDD2),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraceProgressCard() {
    final mileageBased = result.graceProgressUsesMileage;
    final window = result.graceProgressWindow;
    final used = result.graceProgressUsed;
    final progress = window <= 0
        ? 1.0
        : (used / window).clamp(0.0, 1.0).toDouble();
    final String startLabel;
    final String endLabel;
    final String unit = mileageBased ? 'KM' : 'DAYS';

    if (mileageBased) {
      final dueMileage = result.nextDueMileage!;
      startLabel = _formatKm(dueMileage);
      endLabel = _formatKm(dueMileage + result.graceWindowMileage);
    } else {
      final dueDate = result.nextDueDate!;
      startLabel = _formatDate(dueDate);
      endLabel = _formatDate(
        dueDate.add(Duration(days: result.graceWindowDays)),
      );
    }

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'GRACE PERIOD PROGRESS',
                style: TextStyle(
                  color: Color(0xFF777B82),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                result.graceExceededBy > 0
                    ? 'LIMIT EXCEEDED'
                    : '$used / $window $unit',
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 13,
              color: const Color(0xFF29292E),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_statusColor.withOpacity(0.72), _statusColor],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                startLabel,
                style: const TextStyle(
                  color: Color(0xFF555960),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                endLabel,
                style: const TextStyle(
                  color: Color(0xFF9EA2A8),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _nextMileageScheduleValue {
    if (result.rule.isConditionBased) return 'NOT MILEAGE BASED';
    if (result.nextDueMileage != null) {
      return _formatKm(result.nextDueMileage);
    }
    if (result.requiresHistory && result.rule.mileageInterval != null) {
      return 'LAST SERVICE RECORD NEEDED';
    }
    return 'NO MILEAGE INTERVAL';
  }

  String get _nextDateScheduleValue {
    if (result.rule.isConditionBased) {
      if (service?['conditionPassed'] == false) return 'ATTENTION REQUIRED';
      if (result.nextDueDate != null) return _formatDate(result.nextDueDate);
      return 'NOT RECORDED';
    }
    if (result.nextDueDate != null) return _formatDate(result.nextDueDate);
    if (result.requiresHistory && result.rule.timeIntervalMonths != null) {
      return 'LAST SERVICE DATE NEEDED';
    }
    return 'NO DATE INTERVAL';
  }

  Widget _buildScheduleCard() {
    if (result.rule.isConditionBased) {
      return _panel(
        child: Column(
          children: [
            _detailRow('NEXT CHECK', _nextDateScheduleValue, _statusColor),
            _detailRow('MILEAGE', 'NOT USED', const Color(0xFFC9CDD2)),
            _detailRow('ACTION', _actionLabel, const Color(0xFFC9CDD2)),
          ],
        ),
      );
    }

    return _panel(
      child: Column(
        children: [
          _detailRow('NEXT MILEAGE', _nextMileageScheduleValue, _statusColor),
          _detailRow(
            'NEXT DATE',
            _nextDateScheduleValue,
            const Color(0xFFC9CDD2),
          ),
          _detailRow('ACTION', _actionLabel, const Color(0xFFC9CDD2)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context) {
    final history = serviceHistory.isNotEmpty
        ? serviceHistory
        : service == null
        ? const <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[service!];

    if (history.isEmpty) {
      return _panel(
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              color: Color(0xFF8D9299),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              result.rule.isConditionBased
                  ? 'NO INSPECTION RECORDED'
                  : 'NO SERVICE RECORD',
              style: const TextStyle(
                color: Color(0xFF9EA2A8),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < history.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          _buildServiceHistoryEntry(context, history[index], index),
        ],
      ],
    );
  }

  Widget _buildServiceHistoryEntry(
    BuildContext context,
    Map<String, dynamic> record,
    int index,
  ) {
    final conditionBased = result.rule.isConditionBased;
    final mileage = _readInt(
      record['mileageAtInspection'] ??
          record['mileage'] ??
          record['mileageAtService'],
    );
    final date = _readDate(record['inspectionDate'] ?? record['serviceDate']);
    final notes = record['notes']?.toString().trim() ?? '';
    final oilSpecification = record['oilSpecification']?.toString().trim() ?? '';
    final rawChecklist = record['conditionChecklist'];
    final checklist = rawChecklist is Map
        ? rawChecklist.entries
              .where((entry) => entry.value == true)
              .map((entry) => entry.key.toString())
              .toList(growable: false)
        : const <String>[];

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: Color(0xFF8D9299),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                conditionBased
                    ? index == 0
                          ? 'LAST INSPECTION'
                          : 'PREVIOUS INSPECTION ${index + 1}'
                    : index == 0
                    ? 'LAST SERVICE'
                    : 'PREVIOUS SERVICE ${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF9EA2A8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            conditionBased
                ? 'INSPECTED AT ${_formatKm(mileage)}'
                : _formatKm(mileage),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _formatDate(date),
            style: const TextStyle(
              color: Color(0xFF777B82),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!conditionBased &&
              result.rule.maintenanceItem.trim().toLowerCase() ==
                  'engine oil' &&
              oilSpecification.isNotEmpty) ...[
            const SizedBox(height: 13),
            Text(
              'OIL ACTUALLY RECORDED',
              style: const TextStyle(
                color: Color(0xFF777B82),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              oilSpecification,
              style: const TextStyle(
                color: Color(0xFFC9CDD2),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (conditionBased) ...[
            const SizedBox(height: 10),
            Text(
              record['conditionPassed'] == true
                  ? 'RESULT: ALL CLEAR'
                  : 'RESULT: NEEDS ATTENTION',
              style: TextStyle(
                color: record['conditionPassed'] == true
                    ? const Color(0xFF00D27A)
                    : const Color(0xFFFF542C),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            if (checklist.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final item in checklist)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF00D27A),
                        size: 13,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: Color(0xFF9EA2A8),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              const SizedBox(height: 7),
              const Text(
                'Checklist details were not saved for this older record.',
                style: TextStyle(color: Color(0xFF777B82), fontSize: 10),
              ),
            ],
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              style: const TextStyle(
                color: Color(0xFF9EA2A8),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editService(context, record),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('EDIT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC9CDD2),
                    side: const BorderSide(color: Color(0xFF41434A)),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDeleteService(context, record),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('DELETE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _statusColor,
                    side: BorderSide(
                      color: _statusColor.withValues(alpha: 0.5),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editService(
    BuildContext context,
    Map<String, dynamic> record,
  ) async {
    final saved = await onEditService(record);
    if (saved && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmDeleteService(
    BuildContext context,
    Map<String, dynamic> record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF17191B),
        title: const Text(
          'Delete service record?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This removes this service entry. If an earlier service remains, the maintenance status will use that record.',
          style: TextStyle(color: Color(0xFFC9CDD2)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('DELETE', style: TextStyle(color: _statusColor)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final deleted = await onDeleteService(record);
      if (deleted && context.mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('DLOG DELETE SERVICE RECORD ERROR: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete this service record.'),
            backgroundColor: Color(0xFF17191B),
          ),
        );
      }
    }
  }

  Widget _buildEngineOilMetadataCard() {
    final options = result.rule.engineOilOptions;

    return _panel(
      child: options.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(
                  'OIL TYPE',
                  'Not specified',
                  const Color(0xFFC9CDD2),
                ),
                _detailRow(
                  'VISCOSITY',
                  'Not specified',
                  const Color(0xFFC9CDD2),
                ),
                _detailRow(
                  'API SPECIFICATION',
                  'Not specified',
                  const Color(0xFFC9CDD2),
                ),
                _detailRow(
                  'STATUS',
                  EngineOilMetadataStatus.notProvided.label,
                  const Color(0xFF9EA2A8),
                ),
                const SizedBox(height: 5),
                const Text(
                  'The supplied matrix has no oil-grade entry for this '
                  'vehicle rule group.',
                  style: TextStyle(
                    color: Color(0xFF777B82),
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                for (var index = 0; index < options.length; index++) ...[
                  if (index > 0) ...[
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFF29292F), height: 1),
                    const SizedBox(height: 14),
                  ],
                  _buildEngineOilOption(options[index]),
                ],
              ],
            ),
    );
  }

  Widget _buildEngineOilOption(EngineOilMetadata option) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.oilType ?? 'Oil option',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        _detailRow(
          'VISCOSITY',
          option.viscosity ?? 'Not specified',
          const Color(0xFFC9CDD2),
        ),
        _detailRow(
          'API / SPECIFICATION',
          option.apiSpecification ?? 'Not specified',
          const Color(0xFFC9CDD2),
        ),
        _detailRow('STATUS', option.status.label, const Color(0xFF9EA2A8)),
        if (option.statusNote != null)
          _detailRow(
            'MATRIX LABEL',
            option.statusNote!,
            const Color(0xFF9EA2A8),
          ),
        if (option.sourceType != null)
          _detailRow(
            'SOURCE TYPE',
            option.sourceType!.label,
            const Color(0xFFC9CDD2),
          ),
        if (option.confidence != null)
          _detailRow(
            'CONFIDENCE',
            option.confidence!.label,
            const Color(0xFFC9CDD2),
          ),
        if (option.sourceName != null)
          _detailRow('SOURCE', option.sourceName!, const Color(0xFFC9CDD2)),
        if (option.sourceId != null)
          _detailRow('SOURCE ID', option.sourceId!, const Color(0xFFC9CDD2)),
        if (option.sourceReference != null)
          _detailRow(
            'REFERENCE',
            option.sourceReference!,
            const Color(0xFFC9CDD2),
          ),
        if (option.applicabilityNote != null) ...[
          const SizedBox(height: 4),
          Text(
            option.applicabilityNote!,
            style: const TextStyle(
              color: Color(0xFF777B82),
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
        if (option.sourceUrl != null) ...[
          const SizedBox(height: 6),
          SelectableText(
            option.sourceUrl!,
            style: const TextStyle(
              color: Color(0xFF9EA2A8),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSourceCard() {
    final policy = result.rule.conditionInspectionPolicy;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.rule.source == 'dlog_prototype_matrix'
                ? 'DLog prototype data — not manufacturer-confirmed'
                : result.rule.source,
            style: const TextStyle(
              color: Color(0xFF9EA2A8),
              fontSize: 12,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (result.rule.sourceReference != null) ...[
            const SizedBox(height: 6),
            Text(
              result.rule.sourceReference!,
              style: const TextStyle(
                color: Color(0xFF777B82),
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ],
          if (policy != null) ...[
            const SizedBox(height: 8),
            Text(
              '${policy.sourceLabel}: check every ${policy.checkIntervalDays} days; '
              'due soon within ${policy.dueSoonThresholdDays} days; '
              'grace ${policy.gracePeriodDays} days. These are DLog prototype '
              'inspection reminders, not replacement intervals.',
              style: const TextStyle(
                color: Color(0xFF777B82),
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF111113),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFF29292F)),
      ),
      child: child,
    );
  }

  Widget _detailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF62666D),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionInspectionChecklist extends StatefulWidget {
  const _ConditionInspectionChecklist({
    required this.items,
    required this.accentColor,
    required this.currentMileage,
    required this.onConfirm,
  });

  final List<String> items;
  final Color accentColor;
  final int currentMileage;
  final Future<bool> Function(Map<String, bool>, bool) onConfirm;

  @override
  State<_ConditionInspectionChecklist> createState() =>
      _ConditionInspectionChecklistState();
}

class _ConditionInspectionChecklistState
    extends State<_ConditionInspectionChecklist> {
  final Map<String, bool> _completedItems = {};
  bool? _conditionPassed;
  bool _saving = false;

  bool get _checklistComplete =>
      widget.items.isNotEmpty &&
      widget.items.every((item) => _completedItems[item] == true);

  String get _formattedMileage => widget.currentMileage
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Future<void> _confirm() async {
    final passed = _conditionPassed;
    if (!_checklistComplete || passed == null || _saving) return;

    setState(() => _saving = true);
    try {
      await widget.onConfirm(Map<String, bool>.from(_completedItems), passed);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('DLOG CONDITION INSPECTION SAVE ERROR: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save this inspection. Please try again.'),
          backgroundColor: Color(0xFF17191B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111113),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFF29292F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.speed_rounded,
                color: Color(0xFF8D9299),
                size: 17,
              ),
              const SizedBox(width: 8),
              const Text(
                'ODOMETER AT INSPECTION',
                style: TextStyle(
                  color: Color(0xFF777B82),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
              const Spacer(),
              Text(
                '$_formattedMileage KM',
                style: const TextStyle(
                  color: Color(0xFFE5E7EA),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ConditionChecklistEditor(
            items: widget.items,
            completedItems: _completedItems,
            conditionPassed: _conditionPassed,
            enabled: !_saving,
            accentColor: widget.accentColor,
            onItemChanged: (items) => setState(() {
              _completedItems
                ..clear()
                ..addAll(items);
            }),
            onConditionChanged: (value) =>
                setState(() => _conditionPassed = value),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed:
                  _checklistComplete && _conditionPassed != null && !_saving
                  ? _confirm
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: widget.accentColor,
                foregroundColor: const Color(0xFF070708),
                disabledBackgroundColor: const Color(0xFF29292F),
                disabledForegroundColor: const Color(0xFF777B82),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined, size: 17),
              label: Text(_saving ? 'SAVING INSPECTION' : 'CONFIRM INSPECTION'),
            ),
          ),
          if (!_checklistComplete || _conditionPassed == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Complete every check and choose the inspection result to save.',
              style: TextStyle(color: Color(0xFF777B82), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
