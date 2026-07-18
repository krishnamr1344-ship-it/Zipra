import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  static FirebaseService? _instance;
  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;

  FirebaseService._();

  static FirebaseService get instance {
    _instance ??= FirebaseService._();
    return _instance!;
  }

  FirebaseAuth get auth => _auth!;
  GoogleSignIn get googleSignIn => _googleSignIn!;

  static Future<void> initialize() async {
    await Firebase.initializeApp();
    instance._auth = FirebaseAuth.instance;
    instance._googleSignIn = GoogleSignIn();

    if (kDebugMode) {
      debugPrint('Firebase initialized');
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    await _googleSignIn!.disconnect();
    final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in cancelled');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth!.signInWithCredential(credential);
    final User? user = userCredential.user;
    if (user == null) {
      throw Exception('Firebase sign-in failed');
    }

    final token = await user.getIdToken();
    return {
      'token': token,
      'user': {
        'id': user.uid,
        'name': user.displayName ?? user.email?.split('@').first ?? '',
        'email': user.email ?? '',
        'role': 'user',
      },
    };
  }

  Future<void> signOut() async {
    await _googleSignIn!.signOut();
    await _auth!.signOut();
  }
}
