import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../theme/dlog_colors.dart';
import '../../widgets/dlog_background.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  late Future<void> _googleInitialization;

  @override
  void initState() {
    super.initState();
    _googleInitialization = GoogleSignIn.instance.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToTerms) {
      _showMessage('Please agree to the Terms & Conditions.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      final user = credential.user;

      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': _nameController.text.trim(),
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'user',
        });
      }

      if (!mounted) return;

      _showMessage('Account created successfully.', isError: false);

      // Temporary:
      // We will replace this with Vehicle Onboarding later.
      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'weak-password':
          message = 'Your password is too weak.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;

        default:
          message = e.message ?? 'Unable to create account.';
      }

      if (mounted) {
        _showMessage(message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Something went wrong. Please try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    if (!_agreedToTerms) {
      _showMessage('Please agree to the Terms & Conditions.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _googleInitialization;

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user != null) {
        final profileRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final existingProfile = await profileRef.get();
        await profileRef.set({
          'uid': user.uid,
          'fullName': user.displayName ?? googleUser.displayName ?? '',
          'email': user.email,
          if (!existingProfile.exists) ...{
            'createdAt': FieldValue.serverTimestamp(),
            'role': 'user',
          },
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      _showMessage('Google account connected successfully.', isError: false);

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      Navigator.pop(context);
    } on GoogleSignInException catch (e) {
      if (mounted) {
        _showMessage(
          e.description ?? 'Google sign-in was cancelled or failed.',
          isError: true,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showMessage(e.message ?? 'Google sign-in failed.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Unable to continue with Google.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? DLogColors.burgundy : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required IconData icon,
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: DLogColors.silver),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.045),
      hintStyle: TextStyle(
        color: DLogColors.silver.withValues(alpha: 0.55),
        fontSize: 16,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: DLogColors.burgundy, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text,
        style: const TextStyle(
          color: DLogColors.silver,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DLogBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 35),
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 19,
                      color: DLogColors.silverLight,
                    ),
                    label: const Text(
                      'Back',
                      style: TextStyle(color: DLogColors.silver, fontSize: 16),
                    ),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                ),

                const SizedBox(height: 30),

                // Heading
                const Text(
                  'Create your\naccount.',
                  style: TextStyle(
                    color: DLogColors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Start your journey with DLog.',
                  style: TextStyle(color: DLogColors.silver, fontSize: 18),
                ),

                const SizedBox(height: 35),

                // Full name
                _sectionLabel('FULL NAME'),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: DLogColors.white, fontSize: 16),
                  decoration: _fieldDecoration(
                    icon: Icons.person_outline_rounded,
                    hint: 'Enter your full name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name.';
                    }

                    if (value.trim().length < 2) {
                      return 'Please enter your full name.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 22),

                // Email
                _sectionLabel('EMAIL'),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: DLogColors.white, fontSize: 16),
                  decoration: _fieldDecoration(
                    icon: Icons.mail_outline_rounded,
                    hint: 'Enter your email',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email.';
                    }

                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 22),

                // Password
                _sectionLabel('PASSWORD'),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: DLogColors.white, fontSize: 16),
                  decoration: _fieldDecoration(
                    icon: Icons.lock_outline_rounded,
                    hint: 'Create a password',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: DLogColors.silver,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please create a password.';
                    }

                    if (value.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 22),

                // Confirm password
                _sectionLabel('CONFIRM PASSWORD'),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(color: DLogColors.white, fontSize: 16),
                  decoration: _fieldDecoration(
                    icon: Icons.lock_outline_rounded,
                    hint: 'Confirm your password',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: DLogColors.silver,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password.';
                    }

                    if (value != _passwordController.text) {
                      return 'Passwords do not match.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                // Terms checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _agreedToTerms = value ?? false;
                              });
                            },
                      activeColor: DLogColors.burgundy,
                      side: const BorderSide(color: DLogColors.silver),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'I agree to the Terms & Conditions.',
                          style: TextStyle(
                            color: DLogColors.silver,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Create account
                SizedBox(
                  height: 58,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAccount,
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('CREATE ACCOUNT'),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 28),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'OR CONTINUE WITH',
                        style: TextStyle(
                          color: DLogColors.silver,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // Google
                SizedBox(
                  height: 58,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _continueWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'G',
                            style: TextStyle(
                              color: Color(0xFF4285F4),
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: DLogColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Login link
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: DLogColors.silver,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                        child: const Text(
                          'Log in',
                          style: TextStyle(
                            color: DLogColors.burgundy,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
}
