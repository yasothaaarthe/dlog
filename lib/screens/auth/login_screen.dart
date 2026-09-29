import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../theme/dlog_colors.dart';
import '../../widgets/dlog_background.dart';
import '../../repositories/vehicle_repository.dart';
import '../admin/admin_dashboard_screen.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';
import 'welcome_screen.dart';
import '../onboarding/vehicle_onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late Future<void> _googleInitialization;

  @override
  void initState() {
    super.initState();
    _googleInitialization = GoogleSignIn.instance.initialize();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw StateError('User session not found.');
      await _routeAfterSignIn(user);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
          message = 'Incorrect email or password.';
          break;
        case 'user-not-found':
          message = 'No account exists with this email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;
        default:
          message = e.message ?? 'Unable to log in.';
      }
      if (mounted) _showMessage(message, isError: true);
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Unable to load your DLog account. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _routeAfterSignIn(User user) async {
    final profileRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final profileSnapshot = await profileRef.get();
    final profile = Map<String, dynamic>.from(
      profileSnapshot.data() ?? <String, dynamic>{},
    );

    // Older accounts may not have a profile document. Create only a regular-user
    // profile; never infer or grant admin access from sign-in details.
    if (!profileSnapshot.exists) {
      final fullName = user.displayName?.trim() ?? '';
      await profileRef.set({
        'uid': user.uid,
        'fullName': fullName,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'user',
      });
      profile['role'] = 'user';
      profile['fullName'] = fullName;
    }

    final role = profile['role']?.toString().trim().toLowerCase();
    if (role == 'admin') {
      final storedName = profile['fullName']?.toString().trim() ?? '';
      final emailName = user.email?.split('@').first ?? '';
      final adminName = storedName.isNotEmpty
          ? storedName
          : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : (emailName.isNotEmpty ? emailName : 'Admin'));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(adminName: adminName),
        ),
      );
      return;
    }

    final vehicles = await VehicleRepository().getVehiclesForUser(user.uid);
    if (!mounted) return;
    if (vehicles.isNotEmpty) {
      final storedName = profile['fullName']?.toString().trim() ?? '';
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            userName: storedName.isNotEmpty
                ? storedName
                : (user.displayName ?? 'Driver'),
            vehicleData: vehicles.first,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VehicleOnboardingScreen()),
      );
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        'Enter your email first, then tap Forgot password.',
        isError: true,
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        _showMessage(
          'Password reset email sent. Check your inbox.',
          isError: false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showMessage(
          e.message ?? 'Unable to send password reset email.',
          isError: true,
        );
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _isLoading = true);
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
      if (user == null) throw StateError('User session not found.');
      await _routeAfterSignIn(user);
    } on GoogleSignInException catch (e) {
      if (mounted) {
        _showMessage(
          e.description ?? 'Google sign-in was cancelled or failed.',
          isError: true,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showMessage(e.message ?? 'Google login failed.', isError: true);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Unable to continue with Google. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DLogBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 35),
            children: [
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WelcomeScreen(),
                          ),
                        ),
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

              const SizedBox(height: 24),

              // Heading
              const Text(
                'Welcome back.',
                style: TextStyle(
                  color: DLogColors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Sign in to continue your DLog journey.',
                style: TextStyle(color: DLogColors.silver, fontSize: 18),
              ),

              const SizedBox(height: 52),

              // Email
              const Text(
                'EMAIL',
                style: TextStyle(
                  color: DLogColors.silver,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 9),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                style: const TextStyle(color: DLogColors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    color: DLogColors.silver,
                  ),
                  hintStyle: TextStyle(
                    color: DLogColors.silver.withValues(alpha: 0.55),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.045),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 19,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: DLogColors.burgundy,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 34),

              // Password
              const Text(
                'PASSWORD',
                style: TextStyle(
                  color: DLogColors.silver,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 9),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                style: const TextStyle(color: DLogColors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: DLogColors.silver,
                  ),
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
                  hintStyle: TextStyle(
                    color: DLogColors.silver.withValues(alpha: 0.55),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.045),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 19,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: DLogColors.burgundy,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _forgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: DLogColors.burgundy,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Login button
              SizedBox(
                height: 58,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
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
                            Text('LOG IN'),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 50),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.white.withValues(alpha: 0.16)),
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
                    child: Divider(color: Colors.white.withValues(alpha: 0.16)),
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

              const SizedBox(height: 48),

              // Create account
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(color: DLogColors.silver, fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                      child: const Text(
                        'Create account',
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
    );
  }
}
