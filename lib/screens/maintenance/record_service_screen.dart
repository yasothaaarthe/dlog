import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import '../../data/maintenance_rules.dart';
import '../../models/maintenance_rule.dart';

import '../../theme/dlog_colors.dart';

import '../../widgets/dlog_background.dart';
import '../../widgets/condition_checklist_editor.dart';

class RecordServiceScreen extends StatefulWidget {
  const RecordServiceScreen({
    super.key,

    required this.vehicle,

    this.preselectedMaintenanceItem,

    this.existingRecord,
  });

  final Map<String, dynamic> vehicle;

  final String? preselectedMaintenanceItem;

  final Map<String, dynamic>? existingRecord;

  bool get isEditing => existingRecord != null;

  @override
  State<RecordServiceScreen> createState() => _RecordServiceScreenState();
}

class _RecordServiceScreenState extends State<RecordServiceScreen> {
  final TextEditingController _mileageController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();

  final TextEditingController _oilViscosityController = TextEditingController();

  final TextEditingController _oilApiController = TextEditingController();

  static const String _otherOilValue = 'Other / enter manually';
  static const String _notRecordedValue = '__not_recorded__';

  String? _selectedOilViscosity;
  String? _selectedOilApi;

  DateTime _serviceDate = DateTime.now();

  String? _selectedMaintenanceItem;

  String? _selectedOilType;

  bool _saving = false;
  bool? _conditionPassed;
  Map<String, bool> _conditionChecklist = {};

  List<String> _maintenanceItems = [];

  @override
  void initState() {
    super.initState();

    final ruleGroupId = widget.vehicle['ruleGroupId']?.toString();

    if (ruleGroupId != null && ruleGroupId.isNotEmpty) {
      final rules = MaintenanceRules.forRuleGroup(ruleGroupId);

      _maintenanceItems = rules.map((rule) => rule.maintenanceItem).toList();

      if (widget.preselectedMaintenanceItem != null &&
          _maintenanceItems.contains(widget.preselectedMaintenanceItem)) {
        _selectedMaintenanceItem = widget.preselectedMaintenanceItem;
      }
    }

    final existing = widget.existingRecord;
    if (existing != null) {
      final existingItem = (existing['maintenanceItem'] ?? existing['item'])
          ?.toString();
      if (existingItem != null && _maintenanceItems.contains(existingItem)) {
        _selectedMaintenanceItem = existingItem;
      }
      final existingMileage =
          existing['mileageAtService'] ?? existing['mileage'];
      if (existingMileage is num) {
        _mileageController.text = existingMileage.round().toString();
      } else if (existingMileage != null) {
        _mileageController.text = existingMileage.toString();
      }
      _notesController.text = existing['notes']?.toString() ?? '';
      _restoreOilSpecification(existing['oilSpecification']?.toString());
      final existingDate = existing['serviceDate'];
      if (existingDate is Timestamp) {
        _serviceDate = existingDate.toDate();
      } else if (existingDate is DateTime) {
        _serviceDate = existingDate;
      }
      _conditionPassed = existing['conditionPassed'] is bool
          ? existing['conditionPassed'] as bool
          : null;
      final savedChecklist = existing['conditionChecklist'];
      if (savedChecklist is Map) {
        _conditionChecklist = {
          for (final entry in savedChecklist.entries)
            entry.key.toString(): entry.value == true,
        };
      }
    }

    final currentMileage =
        (widget.vehicle['currentMileage'] as num?)?.round() ?? 0;

    if (existing == null) {
      _mileageController.text = currentMileage.toString();
    }
  }

  MaintenanceRule? get _selectedRule {
    final selectedItem = _selectedMaintenanceItem;
    final ruleGroupId = widget.vehicle['ruleGroupId']?.toString() ?? '';

    if (selectedItem == null || ruleGroupId.isEmpty) {
      return null;
    }

    for (final rule in MaintenanceRules.forRuleGroup(ruleGroupId)) {
      if (rule.maintenanceItem == selectedItem) {
        return rule;
      }
    }

    return null;
  }

  bool get _isConditionInspection => _selectedRule?.isConditionBased == true;

  bool get _isEngineOil =>
      _selectedRule?.maintenanceItem.trim().toLowerCase() == 'engine oil';

  List<String> get _oilTypeOptions {
    final documentedTypes =
        _selectedRule?.engineOilOptions
            .map((option) => option.oilType?.trim())
            .whereType<String>()
            .where((type) => type.isNotEmpty) ??
        const <String>[];
    return {
      ...documentedTypes,
      'Fully Synthetic',
      'Semi-Synthetic',
      'Mineral',
      'Other / not listed',
    }.toList();
  }

  List<String> get _oilViscosityOptions {
    final documented =
        _selectedRule?.engineOilOptions
            .map((option) => option.viscosity?.trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty) ??
        const <String>[];
    return {
      ...documented,
      '0W-20',
      '0W-30',
      '5W-20',
      '5W-30',
      '5W-40',
      '10W-30',
      '10W-40',
      '15W-40',
      '20W-50',
      _otherOilValue,
    }.toList();
  }

  List<String> get _oilApiOptions {
    final documented =
        _selectedRule?.engineOilOptions
            .map((option) => option.apiSpecification?.trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty) ??
        const <String>[];
    return {
      ...documented,
      'API SP',
      'API SN PLUS',
      'API SN',
      'API SM',
      'API SL',
      'API SJ',
      _otherOilValue,
    }.toList();
  }

  EngineOilMetadata? get _selectedOilReference {
    final oilType = _selectedOilType;
    if (oilType == null) return null;
    for (final option
        in _selectedRule?.engineOilOptions ?? const <EngineOilMetadata>[]) {
      if (option.oilType == oilType) return option;
    }
    return null;
  }

  @override
  void dispose() {
    _mileageController.dispose();

    _notesController.dispose();

    _oilViscosityController.dispose();

    _oilApiController.dispose();

    super.dispose();
  }

  void _restoreOilSpecification(String? specification) {
    if (specification == null || specification.trim().isEmpty) return;

    var foundStructuredValue = false;
    for (final part in specification.split(' • ')) {
      final separator = part.indexOf(':');
      if (separator < 0) continue;
      final label = part.substring(0, separator).trim().toLowerCase();
      final value = part.substring(separator + 1).trim();
      if (value.isEmpty) continue;

      switch (label) {
        case 'type':
          if (_oilTypeOptions.contains(value)) _selectedOilType = value;
          foundStructuredValue = true;
          break;
        case 'viscosity':
          if (_oilViscosityOptions.contains(value)) {
            _selectedOilViscosity = value;
          } else {
            _selectedOilViscosity = _otherOilValue;
            _oilViscosityController.text = value;
          }
          foundStructuredValue = true;
          break;
        case 'api':
          if (_oilApiOptions.contains(value)) {
            _selectedOilApi = value;
          } else {
            _selectedOilApi = _otherOilValue;
            _oilApiController.text = value;
          }
          foundStructuredValue = true;
          break;
      }
    }

    // Keep older free-text records editable without rewriting their value.
    if (!foundStructuredValue) {
      _selectedOilViscosity = _otherOilValue;
      _oilViscosityController.text = specification;
    }
  }

  String? _oilSpecificationForSave() {
    final parts = <String>[];
    if (_selectedOilType != null) parts.add('Type: $_selectedOilType');
    final viscosity = _selectedOilViscosity == _otherOilValue
        ? _oilViscosityController.text.trim()
        : (_selectedOilViscosity ?? '');
    if (viscosity.isNotEmpty) parts.add('Viscosity: $viscosity');
    final api = _selectedOilApi == _otherOilValue
        ? _oilApiController.text.trim()
        : (_selectedOilApi ?? '');
    if (api.isNotEmpty) parts.add('API: $api');
    return parts.isEmpty ? null : parts.join(' • ');
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,

      initialDate: _serviceDate,

      firstDate: DateTime(2000),

      lastDate: DateTime.now(),

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

    if (selected == null) return;

    setState(() {
      _serviceDate = selected;
    });
  }

  Future<void> _saveServiceRecord() async {
    if (_selectedMaintenanceItem == null) {
      _showMessage('Please select a maintenance item.');

      return;
    }

    final mileage = int.tryParse(
      _mileageController.text.replaceAll(',', '').trim(),
    );

    if (mileage == null || mileage < 0) {
      _showMessage('Please enter a valid mileage.');

      return;
    }

    final rule = _selectedRule;

    if (rule == null) {
      _showMessage('Unable to determine the selected maintenance rule.');
      return;
    }

    if (rule.isConditionBased) {
      final policy = rule.conditionInspectionPolicy;
      if (policy == null) {
        _showMessage('This condition inspection checklist is not configured.');
        return;
      }
      if (policy.checklistItems.any(
        (item) => _conditionChecklist[item] != true,
      )) {
        _showMessage('Complete every inspection checklist item.');
        return;
      }
      if (_conditionPassed == null) {
        _showMessage('Select the inspection result.');
        return;
      }
    }

    final vehicleId = widget.vehicle['id']?.toString();

    if (vehicleId == null || vehicleId.isEmpty) {
      _showMessage('Vehicle information is missing.');

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final serviceRecords = firestore.collection('serviceRecords');
      final existingRecordId = widget.existingRecord?['id']?.toString();
      if (widget.isEditing &&
          (existingRecordId == null || existingRecordId.isEmpty)) {
        throw StateError('The service record ID is missing.');
      }
      final serviceRecord = widget.isEditing
          ? serviceRecords.doc(existingRecordId)
          : serviceRecords.doc();
      final vehicleReference = firestore.collection('vehicles').doc(vehicleId);

      await firestore.runTransaction((transaction) async {
        final vehicleSnapshot = await transaction.get(vehicleReference);
        if (!vehicleSnapshot.exists) {
          throw StateError('Vehicle record no longer exists.');
        }

        final persistedMileage =
            (vehicleSnapshot.data()?['currentMileage'] as num?)?.round() ?? 0;

        final recordData = <String, dynamic>{
          'vehicleId': vehicleId,
          'maintenanceItem': _selectedMaintenanceItem,
          'serviceDate': Timestamp.fromDate(_serviceDate),
          'mileageAtService': mileage,
          'notes': _notesController.text.trim(),
          'oilSpecification': _isEngineOil ? _oilSpecificationForSave() : null,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (rule.isConditionBased) {
          recordData.addAll({
            'recordType': 'condition_inspection',
            'inspectionDate': Timestamp.fromDate(_serviceDate),
            'mileageAtInspection': mileage,
            'conditionChecklist': Map<String, bool>.from(_conditionChecklist),
            'inspectionStatus': _conditionPassed!
                ? 'good'
                : 'attention_required',
            'conditionPassed': _conditionPassed,
          });
        } else {
          recordData['conditionPassed'] = null;
        }
        if (widget.isEditing) {
          transaction.update(serviceRecord, recordData);
        } else {
          transaction.set(serviceRecord, {
            ...recordData,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (mileage > persistedMileage) {
          transaction.update(vehicleReference, {
            'currentMileage': mileage,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage('Unable to save the service record. Please try again.');

      debugPrint('DLOG RECORD SERVICE ERROR: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),

        backgroundColor: const Color(0xFF17191B),

        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
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

  @override
  Widget build(BuildContext context) {
    final model = (widget.vehicle['model'] ?? 'Vehicle').toString();

    final variant = (widget.vehicle['variant'] ?? '').toString();

    final year = (widget.vehicle['year'] ?? '').toString();

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
                _header(),

                const SizedBox(height: 28),

                Text(
                  _isConditionInspection
                      ? widget.isEditing
                            ? 'EDIT CONDITION INSPECTION'
                            : 'RECORD CONDITION INSPECTION'
                      : widget.isEditing
                      ? 'EDIT SERVICE RECORD'
                      : 'RECORD SERVICE',

                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),

                    fontSize: 11,

                    fontWeight: FontWeight.w800,

                    letterSpacing: 1.8,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.isEditing
                      ? 'Edit maintenance record'
                      : 'Add a completed maintenance',

                  style: const TextStyle(
                    color: Colors.white,

                    fontSize: 27,

                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '$model${variant.isNotEmpty ? ' $variant' : ''}'
                  '${year.isNotEmpty ? ' • $year' : ''}',

                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),

                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 28),

                _sectionLabel(
                  _isConditionInspection
                      ? 'WHAT WAS INSPECTED'
                      : 'WHAT WAS SERVICED',
                ),

                const SizedBox(height: 10),

                _maintenanceDropdown(),

                if (_isEngineOil) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('OIL ACTUALLY USED (OPTIONAL)'),
                  const SizedBox(height: 10),
                  _oilTypeDropdown(),
                  _selectedOilReferenceNote(),
                  const SizedBox(height: 8),
                  Text(
                    _selectedRule?.engineOilOptions.isNotEmpty == true
                        ? 'Record what was used on the service. Matrix references are informational; check the oil container and owner manual.'
                        : 'No vehicle-specific oil grade is listed for this rule group. These choices record your actual oil; they are not DLog recommendations.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.43),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionLabel('VISCOSITY (OPTIONAL)'),
                  const SizedBox(height: 8),
                  _oilValueDropdown(
                    value: _selectedOilViscosity,
                    hint: 'Select viscosity if known',
                    options: _oilViscosityOptions,
                    onChanged: (value) => setState(() {
                      _selectedOilViscosity = value;
                      if (value != _otherOilValue) {
                        _oilViscosityController.clear();
                      }
                    }),
                  ),
                  if (_selectedOilViscosity == _otherOilValue) ...[
                    const SizedBox(height: 8),
                    _oilTextField(
                      controller: _oilViscosityController,
                      hint: 'Enter viscosity from the oil container',
                    ),
                  ],
                  const SizedBox(height: 14),
                  _sectionLabel('API SPECIFICATION (OPTIONAL)'),
                  const SizedBox(height: 8),
                  _oilValueDropdown(
                    value: _selectedOilApi,
                    hint: 'Select API specification if known',
                    options: _oilApiOptions,
                    onChanged: (value) => setState(() {
                      _selectedOilApi = value;
                      if (value != _otherOilValue) _oilApiController.clear();
                    }),
                  ),
                  if (_selectedOilApi == _otherOilValue) ...[
                    const SizedBox(height: 8),
                    _oilTextField(
                      controller: _oilApiController,
                      hint: 'Enter API label from the oil container',
                    ),
                  ],
                ],

                if (_selectedRule?.isConditionBased == true) ...[
                  const SizedBox(height: 22),
                  _sectionLabel('CONDITION CHECK'),
                  const SizedBox(height: 10),
                  _conditionChecklistField(),
                ],

                const SizedBox(height: 22),

                _sectionLabel(
                  _isConditionInspection ? 'INSPECTION DATE' : 'SERVICE DATE',
                ),

                const SizedBox(height: 10),

                _dateField(),

                const SizedBox(height: 22),

                _sectionLabel(
                  _isConditionInspection
                      ? 'ODOMETER AT INSPECTION'
                      : 'ODOMETER AT SERVICE',
                ),

                const SizedBox(height: 10),

                _mileageField(),

                const SizedBox(height: 22),

                _sectionLabel('NOTES'),

                const SizedBox(height: 10),

                _notesField(),

                const SizedBox(height: 30),

                _saveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),

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

        const Text(
          'DLog',

          style: TextStyle(
            color: Colors.white,

            fontSize: 22,

            fontWeight: FontWeight.w900,

            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,

      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.48),

        fontSize: 10,

        fontWeight: FontWeight.w800,

        letterSpacing: 1.5,
      ),
    );
  }

  Widget _maintenanceDropdown() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 17),

      decoration: BoxDecoration(
        color: const Color(0xFF111416),

        borderRadius: BorderRadius.circular(17),

        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),

      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMaintenanceItem,

          isExpanded: true,

          dropdownColor: const Color(0xFF17191B),

          icon: Icon(
            Icons.keyboard_arrow_down_rounded,

            color: Colors.white.withValues(alpha: 0.65),
          ),

          hint: Text(
            'Select maintenance item',

            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),

              fontSize: 14,
            ),
          ),

          style: const TextStyle(
            color: Colors.white,

            fontSize: 14,

            fontWeight: FontWeight.w700,
          ),

          items: _maintenanceItems.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item));
          }).toList(),

          onChanged: _saving
              ? null
              : (value) {
                  setState(() {
                    _selectedMaintenanceItem = value;
                    _conditionPassed = null;
                    _conditionChecklist = {};
                  });
                },
        ),
      ),
    );
  }

  Widget _oilTypeDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        color: const Color(0xFF111416),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedOilType,
          isExpanded: true,
          dropdownColor: const Color(0xFF17191B),
          hint: Text(
            'Select the oil type used',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 14,
            ),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withValues(alpha: 0.65),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          items: _oilTypeOptions
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: _saving
              ? null
              : (value) => setState(() => _selectedOilType = value),
        ),
      ),
    );
  }

  Widget _selectedOilReferenceNote() {
    final reference = _selectedOilReference;
    if (reference == null) return const SizedBox.shrink();

    final details = [
      if (reference.viscosity != null) reference.viscosity!,
      if (reference.apiSpecification != null) reference.apiSpecification!,
    ].join(' • ');
    if (details.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Text(
        'Matrix reference only: $details',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          fontSize: 11,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _oilValueDropdown({
    required String? value,
    required String hint,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        color: const Color(0xFF111416),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF17191B),
          hint: Text(
            hint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 14,
            ),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withValues(alpha: 0.65),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          items: [
            const DropdownMenuItem<String>(
              value: _notRecordedValue,
              child: Text('Not recorded'),
            ),
            ...options.map(
              (option) =>
                  DropdownMenuItem<String>(value: option, child: Text(option)),
            ),
          ],
          onChanged: _saving
              ? null
              : (selected) =>
                    onChanged(selected == _notRecordedValue ? null : selected),
        ),
      ),
    );
  }

  Widget _oilTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111416),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: TextField(
        controller: controller,
        enabled: !_saving,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 17,
          ),
        ),
      ),
    );
  }

  Widget _conditionChecklistField() {
    final policy = _selectedRule?.conditionInspectionPolicy;
    if (policy == null) {
      return const Text(
        'No inspection checklist is configured for this item.',
        style: TextStyle(color: Color(0xFF9EA2A8), fontSize: 12),
      );
    }
    return ConditionChecklistEditor(
      items: policy.checklistItems,
      completedItems: _conditionChecklist,
      conditionPassed: _conditionPassed,
      enabled: !_saving,
      accentColor: DLogColors.burgundy,
      onItemChanged: (value) => setState(() => _conditionChecklist = value),
      onConditionChanged: (value) => setState(() => _conditionPassed = value),
    );
  }

  Widget _dateField() {
    return GestureDetector(
      onTap: _saving ? null : _pickDate,

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),

        decoration: BoxDecoration(
          color: const Color(0xFF111416),

          borderRadius: BorderRadius.circular(17),

          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),

        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,

              color: DLogColors.burgundy,

              size: 21,
            ),

            const SizedBox(width: 13),

            Text(
              _formatDate(_serviceDate),

              style: const TextStyle(
                color: Colors.white,

                fontSize: 14,

                fontWeight: FontWeight.w700,
              ),
            ),

            const Spacer(),

            Icon(
              Icons.chevron_right_rounded,

              color: Colors.white.withValues(alpha: 0.38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mileageField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111416),

        borderRadius: BorderRadius.circular(17),

        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),

      child: TextField(
        controller: _mileageController,

        enabled: !_saving,

        keyboardType: TextInputType.number,

        style: const TextStyle(
          color: Colors.white,

          fontSize: 15,

          fontWeight: FontWeight.w700,
        ),

        decoration: InputDecoration(
          prefixIcon: Icon(Icons.speed_rounded, color: DLogColors.burgundy),

          suffixText: 'KM',

          suffixStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),

            fontWeight: FontWeight.w800,
          ),

          hintText: 'e.g. 20000',

          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),

          border: InputBorder.none,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,

            vertical: 17,
          ),
        ),
      ),
    );
  }

  Widget _notesField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111416),

        borderRadius: BorderRadius.circular(17),

        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),

      child: TextField(
        controller: _notesController,

        enabled: !_saving,

        maxLines: 4,

        style: const TextStyle(color: Colors.white, fontSize: 14),

        decoration: InputDecoration(
          hintText: 'Optional notes about this service...',

          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),

          border: InputBorder.none,

          contentPadding: const EdgeInsets.all(17),
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,

      height: 56,

      child: ElevatedButton(
        onPressed: _saving ? null : _saveServiceRecord,

        style: ElevatedButton.styleFrom(
          backgroundColor: DLogColors.burgundy,

          disabledBackgroundColor: DLogColors.burgundy.withValues(alpha: 0.45),

          foregroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),

          elevation: 0,
        ),

        child: _saving
            ? const SizedBox(
                width: 22,

                height: 22,

                child: CircularProgressIndicator(
                  strokeWidth: 2.2,

                  color: Colors.white,
                ),
              )
            : Text(
                widget.isEditing
                    ? _isConditionInspection
                          ? 'UPDATE INSPECTION'
                          : 'UPDATE SERVICE RECORD'
                    : _isConditionInspection
                    ? 'SAVE INSPECTION'
                    : 'SAVE SERVICE RECORD',

                style: TextStyle(
                  fontSize: 12,

                  fontWeight: FontWeight.w900,

                  letterSpacing: 0.7,
                ),
              ),
      ),
    );
  }
}
