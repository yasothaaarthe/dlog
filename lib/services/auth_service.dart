import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Current logged-in user
  User? get currentUser => _auth.currentUser;

  // Listen for login/logout changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email and password
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Login with email and password
  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    await _googleSignIn.initialize();

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // Logout
  Future<void> logout() async {
    // Email/password users may never have initialized GoogleSignIn.
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase sign-out remains authoritative for every provider.
    }
    await _auth.signOut();
  }
}
