import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../repositories/admin_repository.dart';
import '../../theme/dlog_colors.dart';
import '../../widgets/dlog_background.dart';

class SupportTicketFormScreen extends StatefulWidget {
  const SupportTicketFormScreen({super.key});

  @override
  State<SupportTicketFormScreen> createState() =>
      _SupportTicketFormScreenState();
}

class _SupportTicketFormScreenState extends State<SupportTicketFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _repository = AdminRepository();

  static const _categories = [
    'App bug',
    'Maintenance data',
    'Account',
    'Other',
  ];

  String _category = _categories.first;
  bool _isSaving = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _repository.submitSupportTicket(
        category: _category,
        subject: _subjectController.text,
        message: _messageController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'permission-denied' =>
          'Firebase denied the ticket write. Check the supportTickets Firestore rules.',
        'unavailable' =>
          'Firebase is unavailable. Check your connection and try again.',
        _ => error.message ?? 'Firebase could not save the support request.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send your request. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _decoration({String? hint, Widget? prefix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    );
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: const Color(0xFF111417),
      hintStyle: TextStyle(color: DLogColors.grey.withValues(alpha: 0.65)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: DLogColors.burgundyBright),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: DLogColors.warningRed),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: DLogColors.warningRed),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      text,
      style: const TextStyle(
        color: DLogColors.grey,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.7,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DLogColors.black,
      body: DLogBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.maybePop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF111315),
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                        fixedSize: const Size(50, 50),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'DLOG SUPPORT',
                      style: TextStyle(
                        color: DLogColors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                const Text(
                  'REPORT AN APP ISSUE',
                  style: TextStyle(
                    color: DLogColors.burgundyBright,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'How can we help?',
                  style: TextStyle(
                    color: DLogColors.white,
                    fontSize: 34,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tell the DLog team what happened. Your request will be attached to your account for follow-up.',
                  style: TextStyle(
                    color: DLogColors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                _label('CATEGORY'),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  dropdownColor: const Color(0xFF171A1D),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  iconEnabledColor: DLogColors.grey,
                  decoration: _decoration(
                    prefix: const Icon(Icons.topic_outlined),
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _category = value);
                        },
                ),
                const SizedBox(height: 22),
                _label('SUBJECT'),
                TextFormField(
                  controller: _subjectController,
                  enabled: !_isSaving,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: _decoration(hint: 'Briefly describe the issue')
                      .copyWith(
                        counterStyle: const TextStyle(color: DLogColors.grey),
                      ),
                  validator: (value) {
                    if (value == null || value.trim().length < 4) {
                      return 'Enter a short, clear subject.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _label('DETAILS'),
                TextFormField(
                  controller: _messageController,
                  enabled: !_isSaving,
                  minLines: 5,
                  maxLines: 8,
                  maxLength: 1200,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
                  ),
                  decoration:
                      _decoration(
                        hint: 'What were you doing, and what did you see?',
                      ).copyWith(
                        alignLabelWithHint: true,
                        counterStyle: const TextStyle(color: DLogColors.grey),
                      ),
                  validator: (value) {
                    if (value == null || value.trim().length < 12) {
                      return 'Add at least a sentence so the team can understand the issue.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111417),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: DLogColors.grey,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This form is for DLog app issues. For immediate danger or roadside emergencies, use SOS and call 999.',
                          style: TextStyle(
                            color: DLogColors.grey,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DLogColors.burgundyBright,
                      disabledBackgroundColor: DLogColors.burgundy.withValues(
                        alpha: 0.45,
                      ),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'SENDING…' : 'SEND SUPPORT REQUEST',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
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
}
