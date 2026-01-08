import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream to listen to user login state
  Stream<User?> get user => _auth.authStateChanges();

  // Sign In with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      return userCredential.user;
    } catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }

  // FIX: Complete Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect(); // Clears the cached account
      await _googleSignIn.signOut(); // Necessary for Google Login
      await _auth.signOut();
    } catch (e) {
      print("Error signing out: $e");
      // Even if it fails, try to sign out locally
      await _auth.signOut();
    }
  }
}
