import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin/support_ticket_form_screen.dart';
import '../../theme/dlog_colors.dart';
import '../../widgets/dlog_background.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  static const _contactsKey = 'dlog_sos_contacts';

  List<EmergencyContact> _contacts = [];

  bool _loading = true;
  bool _sharingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // ============================================================
  // LOCAL STORAGE
  // ============================================================

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactJson = prefs.getString(_contactsKey);

      if (!mounted) return;

      setState(() {
        if (contactJson != null && contactJson.isNotEmpty) {
          final decoded = jsonDecode(contactJson) as List;
          _contacts = decoded
              .map(
                (item) =>
                    EmergencyContact.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList();
        }

        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(
        'Some saved SOS details could not be loaded. Please check or re-enter them.',
      );
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _contactsKey,
      jsonEncode(_contacts.map((e) => e.toMap()).toList()),
    );
  }

  // ============================================================
  // CALL 999
  // ============================================================

  Future<void> _callEmergency() async {
    final uri = Uri(scheme: 'tel', path: '999');

    try {
      // Android package visibility can make canLaunchUrl return false even
      // when an external dialer is installed, so try opening it directly.
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage(
          'No phone dialer is available. If this is an emergency, dial 999 manually.',
        );
      }
    } catch (error) {
      debugPrint('DLOG SOS DIALER ERROR: $error');
      if (!mounted) return;
      _showMessage(
        'No phone dialer is available. If this is an emergency, dial 999 manually.',
      );
    }
  }

  Future<void> _callContact(EmergencyContact contact) async {
    final number = contact.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) {
      _showMessage('This emergency contact does not have a valid phone number.');
      return;
    }

    final uri = Uri(scheme: 'tel', path: number);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('Unable to open the dialer for ${contact.name}.');
      }
    } catch (error) {
      debugPrint('DLOG CONTACT DIALER ERROR: $error');
      if (!mounted) return;
      _showMessage('Unable to open the dialer for ${contact.name}.');
    }
  }

  // ============================================================
  // DLOG APP SUPPORT (not roadside emergency support)
  // ============================================================

  Future<void> _openSupportTicket() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SupportTicketFormScreen()),
    );
    if (!mounted || submitted != true) return;
    _showMessage('Your support request was submitted to the DLog team.');
  }

  Widget _supportTicketCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openSupportTicket,
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: const Color(0xFF101417),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: DLogColors.burgundy.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: DLogColors.burgundyBright,
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report an app issue',
                    style: TextStyle(
                      color: DLogColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Send a support ticket for account, vehicle, or maintenance data problems.',
                    style: TextStyle(
                      color: DLogColors.grey,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'For emergencies, use SOS above and call 999.',
                    style: TextStyle(
                      color: DLogColors.grey,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: DLogColors.grey),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<void> _shareLocation() async {
    if (_sharingLocation) return;

    setState(() {
      _sharingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        _showMessage('Please turn on Location Services first.');

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        _showMessage('Location permission is required to share your location.');

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final latitude = position.latitude.toStringAsFixed(6);

      final longitude = position.longitude.toStringAsFixed(6);

      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

      await SharePlus.instance.share(
        ShareParams(
          text:
              'My current location shared from DLog:\n\n'
              '$mapsUrl',
        ),
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage('Unable to get your current location.');
    } finally {
      if (mounted) {
        setState(() {
          _sharingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // ADD / EDIT CONTACT
  // ============================================================

  Future<void> _openContactForm({EmergencyContact? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');

    final phoneController = TextEditingController(text: existing?.phone ?? '');

    final relationshipController = TextEditingController(
      text: existing?.relationship ?? '',
    );

    final result = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101417),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return _FormSheet(
          title: existing == null
              ? 'Add Emergency Contact'
              : 'Edit Emergency Contact',
          children: [
            _formField(
              controller: nameController,
              label: 'Name',
              hint: 'e.g. Mum',
              icon: Icons.person_outline_rounded,
            ),
            _formField(
              controller: phoneController,
              label: 'Phone Number',
              hint: '+60 12-345 6789',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            _formField(
              controller: relationshipController,
              label: 'Relationship',
              hint: 'e.g. Mother',
              icon: Icons.people_outline_rounded,
            ),
            const SizedBox(height: 10),
            _formButton(
              label: existing == null ? 'ADD CONTACT' : 'SAVE CHANGES',
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    phoneController.text.trim().isEmpty ||
                    relationshipController.text.trim().isEmpty) {
                  _showMessage('Please complete all contact details.');
                  return;
                }

                Navigator.pop(
                  sheetContext,
                  EmergencyContact(
                    id:
                        existing?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    relationship: relationshipController.text.trim(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    relationshipController.dispose();

    if (result == null) return;

    setState(() {
      final index = _contacts.indexWhere((contact) => contact.id == result.id);

      if (index == -1) {
        _contacts.add(result);
      } else {
        _contacts[index] = result;
      }
    });

    await _saveContacts();
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    final confirmed = await _confirmDelete(
      title: 'Delete contact?',
      message: 'Remove ${contact.name} from your emergency contacts?',
    );

    if (!confirmed) return;

    setState(() {
      _contacts.removeWhere((item) => item.id == contact.id);
    });

    await _saveContacts();
  }

  // ============================================================
  // CONFIRM DELETE
  // ============================================================

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151A1D),
          title: Text(
            title,
            style: const TextStyle(
              color: DLogColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(color: DLogColors.grey),
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
                style: TextStyle(color: DLogColors.burgundyBright),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: DLogColors.grey, size: 20),
      labelStyle: const TextStyle(color: DLogColors.grey),
      hintStyle: const TextStyle(color: DLogColors.grey),
      filled: true,
      fillColor: const Color(0xFF0B1012),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF283136)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DLogColors.burgundyBright),
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: const TextStyle(color: DLogColors.white, fontSize: 14),
        decoration: _inputDecoration(label: label, hint: hint, icon: icon),
      ),
    );
  }

  Widget _formButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: DLogColors.burgundyBright,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF20272B),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: DLogColors.grey,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _header() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF111315),
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
            fixedSize: const Size(52, 52),
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 14),
        const Text(
          'DLOG',
          style: TextStyle(
            color: DLogColors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PRIMARY SOS
  // ============================================================

  Widget _sosButton() {
    return GestureDetector(
      onTap: _callEmergency,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DLogColors.burgundy.withValues(alpha: 0.38),
              const Color(0xFF101417),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: DLogColors.burgundyBright.withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: DLogColors.burgundy.withValues(alpha: 0.16),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: DLogColors.burgundyBright,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sos_rounded,
                color: Colors.white,
                size: 31,
              ),
            ),
            const SizedBox(width: 17),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EMERGENCY SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Call Malaysia Emergency 999',
                    style: TextStyle(color: DLogColors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: DLogColors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION CARD
  // ============================================================

  Widget _locationCard() {
    return GestureDetector(
      onTap: _shareLocation,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF101417),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: DLogColors.burgundy.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: DLogColors.burgundyBright,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share live location',
                    style: TextStyle(
                      color: DLogColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Share your current GPS location with someone you trust.',
                    style: TextStyle(
                      color: DLogColors.grey,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            _sharingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DLogColors.burgundyBright,
                    ),
                  )
                : const Text(
                    'SHARE',
                    style: TextStyle(
                      color: DLogColors.burgundyBright,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTACT CARD
  // ============================================================

  Widget _contactCard(EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF101417),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _callContact(contact),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: DLogColors.burgundy.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: DLogColors.burgundyBright,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            style: const TextStyle(
                              color: DLogColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${contact.relationship}  •  ${contact.phone}',
                            style: const TextStyle(
                              color: DLogColors.grey,
                              fontSize: 11,
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: DLogColors.grey),
            color: const Color(0xFF1A2024),
            onSelected: (value) {
              if (value == 'edit') {
                _openContactForm(existing: contact);
              }

              if (value == 'delete') {
                _deleteContact(contact);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit', style: TextStyle(color: DLogColors.white)),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: DLogColors.burgundyBright),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADD CONTACT BUTTON
  // ============================================================

  Widget _addButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1012),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: DLogColors.burgundy.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_rounded,
              color: DLogColors.burgundyBright,
              size: 20,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: DLogColors.burgundyBright,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
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
    if (_loading) {
      return const Scaffold(
        backgroundColor: DLogColors.black,
        body: Center(
          child: CircularProgressIndicator(color: DLogColors.burgundyBright),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DLogColors.black,
      body: DLogBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            children: [
              // HEADER
              _header(),

              const SizedBox(height: 32),

              // TITLE
              const Text(
                'EMERGENCY SUPPORT',
                style: TextStyle(
                  color: DLogColors.burgundyBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'SOS',
                style: TextStyle(
                  color: DLogColors.white,
                  fontSize: 42,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Emergency assistance for you and your vehicle.',
                style: TextStyle(
                  color: DLogColors.grey,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 26),

              // ONE EMERGENCY BUTTON
              _sosButton(),

              const SizedBox(height: 30),

              // LOCATION
              _sectionTitle('QUICK ASSISTANCE'),

              const SizedBox(height: 14),

              _locationCard(),

              const SizedBox(height: 30),

              // CONTACTS
              _sectionTitle('EMERGENCY CONTACTS'),

              const SizedBox(height: 14),

              if (_contacts.isEmpty)
                _emptyContact()
              else
                ..._contacts.map(_contactCard),

              const SizedBox(height: 8),

              _addButton(
                label: 'ADD EMERGENCY CONTACT',
                onTap: () => _openContactForm(),
              ),

              const SizedBox(height: 30),

              _sectionTitle('DLOG APP SUPPORT'),
              const SizedBox(height: 14),
              _supportTicketCard(),

              const SizedBox(height: 28),

              const Center(
                child: Text(
                  'For immediate danger, call 999.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DLogColors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyContact() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101417),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: DLogColors.grey,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No contacts added',
                  style: TextStyle(
                    color: DLogColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Add someone you trust for emergencies.',
                  style: TextStyle(color: DLogColors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FORM SHEET
// ============================================================================

class _FormSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormSheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF424A4F),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: const TextStyle(
                color: DLogColors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
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

// ============================================================================
// MODELS
// ============================================================================

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      relationship: map['relationship'] as String,
    );
  }
}
