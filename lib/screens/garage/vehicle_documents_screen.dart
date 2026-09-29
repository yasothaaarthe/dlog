import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vehicle_documents.dart';
import '../../repositories/vehicle_repository.dart';
import '../../services/grace_period_notification_service.dart';
import '../../theme/dlog_colors.dart';
import '../../widgets/dlog_background.dart';

class VehicleDocumentsScreen extends StatefulWidget {
  const VehicleDocumentsScreen({super.key, required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  State<VehicleDocumentsScreen> createState() => _VehicleDocumentsScreenState();
}

class _VehicleDocumentsScreenState extends State<VehicleDocumentsScreen> {
  static const _legacyInsuranceKey = 'dlog_sos_insurance';
  static const _legacyRoadTaxKey = 'dlog_sos_road_tax';

  final VehicleRepository _repository = VehicleRepository();
  InsuranceDetails? _insurance;
  RoadTaxDetails? _roadTax;
  bool _saving = false;

  String get _vehicleId => widget.vehicle['id']?.toString() ?? '';
  String get _vehicleLabel {
    final model = widget.vehicle['model']?.toString() ?? 'Vehicle';
    final variant = widget.vehicle['variant']?.toString() ?? '';
    return variant.isEmpty ? model : '$model $variant';
  }

  @override
  void initState() {
    super.initState();
    _insurance = _readInsurance(widget.vehicle['insuranceDetails']);
    _roadTax = _readRoadTax(widget.vehicle['roadTaxDetails']);
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerLegacyImport());
  }

  InsuranceDetails? _readInsurance(dynamic value) {
    if (value is! Map) return null;
    try {
      return InsuranceDetails.fromMap(Map<String, dynamic>.from(value));
    } catch (_) {
      return null;
    }
  }

  RoadTaxDetails? _readRoadTax(dynamic value) {
    if (value is! Map) return null;
    try {
      return RoadTaxDetails.fromMap(Map<String, dynamic>.from(value));
    } catch (_) {
      return null;
    }
  }

  Future<void> _offerLegacyImport() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final insuranceJson = prefs.getString(_legacyInsuranceKey);
    final roadTaxJson = prefs.getString(_legacyRoadTaxKey);
    if ((insuranceJson == null || insuranceJson.isEmpty) &&
        (roadTaxJson == null || roadTaxJson.isEmpty)) {
      return;
    }

    InsuranceDetails? insurance;
    RoadTaxDetails? roadTax;
    try {
      if (insuranceJson != null && insuranceJson.isNotEmpty) {
        insurance = InsuranceDetails.fromMap(
          Map<String, dynamic>.from(jsonDecode(insuranceJson)),
        );
      }
      if (roadTaxJson != null && roadTaxJson.isNotEmpty) {
        roadTax = RoadTaxDetails.fromMap(
          Map<String, dynamic>.from(jsonDecode(roadTaxJson)),
        );
      }
    } catch (_) {
      if (mounted) {
        _message(
          'Older SOS document data was found but could not be read. It has been kept on this device.',
        );
      }
      return;
    }

    final importInsurance = _insurance == null ? insurance : null;
    final importRoadTax = _roadTax == null ? roadTax : null;
    if (importInsurance == null && importRoadTax == null) return;

    if (!mounted) return;
    final registration =
        importInsurance?.vehicleRegistration ??
        importRoadTax?.vehicleRegistration ??
        'No registration number';
    final import = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF151719),
        title: const Text(
          'Move saved SOS documents?',
          style: TextStyle(color: DLogColors.white),
        ),
        content: Text(
          'DLog found older document details for $registration. Add them to $_vehicleLabel in Garage? The old copy will only be removed after it is saved successfully.',
          style: const TextStyle(color: DLogColors.grey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('NOT NOW'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DLogColors.burgundyBright,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('MOVE TO THIS VEHICLE'),
          ),
        ],
      ),
    );

    if (import != true || !mounted) return;
    final saved = await _saveDocuments(
      insurance: importInsurance ?? _insurance,
      roadTax: importRoadTax ?? _roadTax,
      showMessage: false,
    );
    if (!saved) return;
    if (importInsurance != null) await prefs.remove(_legacyInsuranceKey);
    if (importRoadTax != null) await prefs.remove(_legacyRoadTaxKey);
    if (mounted) _message('Saved SOS documents were moved to this vehicle.');
  }

  Future<bool> _saveDocuments({
    required InsuranceDetails? insurance,
    required RoadTaxDetails? roadTax,
    bool showMessage = true,
  }) async {
    if (_vehicleId.isEmpty) {
      if (showMessage) _message('Could not identify this vehicle.');
      return false;
    }
    setState(() => _saving = true);
    try {
      await _repository.updateVehicleDocuments(
        vehicleId: _vehicleId,
        insurance: insurance,
        roadTax: roadTax,
      );
      if (!mounted) return false;
      setState(() {
        _insurance = insurance;
        _roadTax = roadTax;
        _saving = false;
      });

      try {
        final remindersScheduled = await GracePeriodNotificationService.instance
            .syncVehicleDocumentReminders(
              vehicleId: _vehicleId,
              vehicleLabel: _vehicleLabel,
              insuranceExpiry: insurance?.expiryDate,
              roadTaxExpiry: roadTax?.expiryDate,
            );
        if (showMessage && mounted) {
          _message(
            remindersScheduled
                ? 'Vehicle documents saved. Expiry reminders are set.'
                : 'Documents saved. Allow notifications on this device to receive expiry reminders.',
          );
        }
      } catch (error) {
        debugPrint('DLOG VEHICLE DOCUMENT REMINDER ERROR: $error');
        if (showMessage && mounted) {
          _message('Documents saved, but expiry reminders could not be set.');
        }
      }
      return true;
    } catch (error) {
      debugPrint('DLOG VEHICLE DOCUMENT SAVE ERROR: $error');
      if (mounted) {
        setState(() => _saving = false);
        if (showMessage) {
          _message(
            'Could not save these details. Check your connection and try again.',
          );
        }
      }
      return false;
    }
  }

  Future<void> _editInsurance() async {
    final result = await _insuranceForm(_insurance);
    if (result == null) return;
    await _saveDocuments(insurance: result, roadTax: _roadTax);
  }

  Future<void> _editRoadTax() async {
    final result = await _roadTaxForm(_roadTax);
    if (result == null) return;
    await _saveDocuments(insurance: _insurance, roadTax: result);
  }

  Future<InsuranceDetails?> _insuranceForm(InsuranceDetails? current) async {
    final provider = TextEditingController(text: current?.provider ?? '');
    final policy = TextEditingController(text: current?.policyNumber ?? '');
    final registration = TextEditingController(
      text: current?.vehicleRegistration ?? '',
    );
    final roadside = TextEditingController(text: current?.roadsideNumber ?? '');
    DateTime? expiry = current?.expiryDate;
    final result = await showModalBottomSheet<InsuranceDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101417),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _FormSheet(
          title: current == null ? 'Add insurance details' : 'Edit insurance',
          children: [
            _input(provider, 'Insurance provider', 'e.g. Etiqa'),
            _input(policy, 'Policy number', 'Enter the policy number'),
            _input(
              registration,
              'Vehicle registration',
              'e.g. PXX 1234',
              capitalization: TextCapitalization.characters,
            ),
            _expiryPicker(
              label: 'Insurance expiry date',
              expiry: expiry,
              onSelected: (date) => setSheetState(() => expiry = date),
            ),
            _input(
              roadside,
              'Roadside assistance number',
              'Phone number from your policy',
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            _saveButton(
              label: current == null ? 'SAVE INSURANCE' : 'UPDATE INSURANCE',
              onPressed: () {
                if (provider.text.trim().isEmpty ||
                    policy.text.trim().isEmpty ||
                    registration.text.trim().isEmpty ||
                    roadside.text.trim().isEmpty ||
                    expiry == null) {
                  _message('Complete all insurance fields first.');
                  return;
                }
                Navigator.pop(
                  sheetContext,
                  InsuranceDetails(
                    provider: provider.text.trim(),
                    policyNumber: policy.text.trim(),
                    expiryDate: expiry!,
                    vehicleRegistration: registration.text.trim().toUpperCase(),
                    roadsideNumber: roadside.text.trim(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
    provider.dispose();
    policy.dispose();
    registration.dispose();
    roadside.dispose();
    return result;
  }

  Future<RoadTaxDetails?> _roadTaxForm(RoadTaxDetails? current) async {
    final registration = TextEditingController(
      text: current?.vehicleRegistration ?? _vehicleRegistrationHint,
    );
    DateTime? expiry = current?.expiryDate;
    final result = await showModalBottomSheet<RoadTaxDetails>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101417),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _FormSheet(
          title: current == null ? 'Add road tax details' : 'Edit road tax',
          children: [
            _input(
              registration,
              'Vehicle registration',
              'e.g. PXX 1234',
              capitalization: TextCapitalization.characters,
            ),
            _expiryPicker(
              label: 'Road tax expiry date',
              expiry: expiry,
              onSelected: (date) => setSheetState(() => expiry = date),
            ),
            const SizedBox(height: 8),
            _saveButton(
              label: current == null ? 'SAVE ROAD TAX' : 'UPDATE ROAD TAX',
              onPressed: () {
                if (registration.text.trim().isEmpty || expiry == null) {
                  _message('Enter the registration and expiry date first.');
                  return;
                }
                Navigator.pop(
                  sheetContext,
                  RoadTaxDetails(
                    vehicleRegistration: registration.text.trim().toUpperCase(),
                    expiryDate: expiry!,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
    registration.dispose();
    return result;
  }

  String get _vehicleRegistrationHint =>
      _insurance?.vehicleRegistration ?? _roadTax?.vehicleRegistration ?? '';

  Future<void> _pickExpiry(
    DateTime? current,
    ValueChanged<DateTime> onSelected,
  ) async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: DLogColors.burgundyBright,
            surface: Color(0xFF101417),
          ),
        ),
        child: child!,
      ),
    );
    if (selected != null) onSelected(selected);
  }

  Widget _expiryPicker({
    required String label,
    required DateTime? expiry,
    required ValueChanged<DateTime> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _pickExpiry(expiry, onSelected),
        child: InputDecorator(
          decoration: _decoration(label, Icons.calendar_month_outlined),
          child: Text(
            expiry == null ? 'Select date' : _formatDate(expiry),
            style: TextStyle(
              color: expiry == null ? DLogColors.grey : DLogColors.white,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        textCapitalization: capitalization,
        style: const TextStyle(color: DLogColors.white, fontSize: 14),
        decoration: _decoration(label, Icons.edit_note_rounded, hint: hint),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: DLogColors.burgundyBright),
        labelStyle: const TextStyle(color: DLogColors.grey, fontSize: 12),
        hintStyle: const TextStyle(color: DLogColors.grey),
        filled: true,
        fillColor: const Color(0xFF0B1012),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: DLogColors.burgundyBright),
        ),
      );

  Widget _saveButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: DLogColors.burgundyBright,
          foregroundColor: DLogColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DLogBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                child: Row(
                  children: [
                    _backButton(),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'VEHICLE DOCUMENTS',
                        style: TextStyle(
                          color: DLogColors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                    if (_saving)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DLogColors.burgundyBright,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                  children: [
                    Text(
                      _vehicleLabel.toUpperCase(),
                      style: const TextStyle(
                        color: DLogColors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.vehicle['variant'] ?? ''} • ${widget.vehicle['year'] ?? ''}'
                          .replaceAll(RegExp(r'^\s*•\s*|\s*•\s*$'), ''),
                      style: const TextStyle(
                        color: DLogColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Insurance and road tax are saved separately for this vehicle.',
                      style: TextStyle(
                        color: DLogColors.grey,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 26),
                    _sectionLabel('INSURANCE'),
                    const SizedBox(height: 10),
                    _insurance == null
                        ? _emptyCard(
                            icon: Icons.shield_outlined,
                            title: 'Insurance details needed',
                            description:
                                'Add the provider, policy number, registration, roadside number, and expiry date.',
                            button: 'ADD INSURANCE',
                            onTap: _saving ? null : _editInsurance,
                          )
                        : _documentCard(
                            icon: Icons.shield_outlined,
                            title: _insurance!.provider,
                            subtitle: _expiryStatus(_insurance!.expiryDate),
                            accent: _expiryColor(_insurance!.expiryDate),
                            lines: [
                              'Policy: ${_insurance!.policyNumber}',
                              'Vehicle: ${_insurance!.vehicleRegistration}',
                              'Expires: ${_formatDate(_insurance!.expiryDate)}',
                              'Roadside: ${_insurance!.roadsideNumber}',
                            ],
                            onEdit: _saving ? null : _editInsurance,
                          ),
                    const SizedBox(height: 22),
                    _sectionLabel('ROAD TAX (LKM)'),
                    const SizedBox(height: 10),
                    _roadTax == null
                        ? _emptyCard(
                            icon: Icons.description_outlined,
                            title: 'Road tax details needed',
                            description:
                                'Add the vehicle registration and road tax expiry date.',
                            button: 'ADD ROAD TAX',
                            onTap: _saving ? null : _editRoadTax,
                          )
                        : _documentCard(
                            icon: Icons.description_outlined,
                            title: 'Motor Vehicle Licence',
                            subtitle: _expiryStatus(_roadTax!.expiryDate),
                            accent: _expiryColor(_roadTax!.expiryDate),
                            lines: [
                              'Vehicle: ${_roadTax!.vehicleRegistration}',
                              'Expires: ${_formatDate(_roadTax!.expiryDate)}',
                            ],
                            onEdit: _saving ? null : _editRoadTax,
                          ),
                    const SizedBox(height: 22),
                    _reminderInfo(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backButton() => InkWell(
    borderRadius: BorderRadius.circular(15),
    onTap: () => Navigator.pop(context),
    child: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: DLogColors.white,
        size: 18,
      ),
    ),
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: DLogColors.grey,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.8,
    ),
  );

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String description,
    required String button,
    required VoidCallback? onTap,
  }) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon, DLogColors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: DLogColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: DLogColors.grey,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _outlinedButton(button, onTap),
        ],
      ),
    );
  }

  Widget _documentCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required List<String> lines,
    required VoidCallback? onEdit,
  }) {
    return _panel(
      borderColor: accent.withValues(alpha: 0.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon, accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: DLogColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.lock_outline, color: DLogColors.grey, size: 17),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1012),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: DLogColors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _outlinedButton('EDIT DETAILS', onEdit),
        ],
      ),
    );
  }

  Widget _reminderInfo() => _panel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.notifications_active_outlined,
          color: DLogColors.burgundyBright,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Expiry reminders are scheduled for 30 days, 7 days, 1 day, and the expiry date. DLog asks permission before sending device notifications.',
            style: TextStyle(color: DLogColors.grey, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _panel({required Widget child, Color? borderColor}) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: const Color(0xFF101417),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.11),
      ),
    ),
    child: child,
  );

  Widget _iconBox(IconData icon, Color color) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Icon(icon, color: color),
  );

  Widget _outlinedButton(String label, VoidCallback? onTap) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: DLogColors.burgundyBright,
        side: BorderSide(
          color: DLogColors.burgundyBright.withValues(alpha: .65),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
    ),
  );

  String _expiryStatus(DateTime expiry) {
    final today = DateTime.now();
    final days = DateTime(
      expiry.year,
      expiry.month,
      expiry.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days < 0) return 'Expired ${days.abs()} days ago';
    if (days == 0) return 'Expires today';
    if (days <= 30) return 'Expires in $days days';
    return 'Valid';
  }

  Color _expiryColor(DateTime expiry) {
    final today = DateTime.now();
    final days = DateTime(
      expiry.year,
      expiry.month,
      expiry.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days < 0) return const Color(0xFFFF4C3B);
    if (days <= 30) return const Color(0xFFFFA500);
    return const Color(0xFF00D17A);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year}';

  String _month(int month) => const [
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
  ][month - 1];

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          22,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF424A4F),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                color: DLogColors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
