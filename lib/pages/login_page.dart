import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/delivery_zone_service.dart';
import '../models/cart_model.dart';
import '../widgets/app_snackbar.dart';
import 'home_page.dart';
import 'admin_home_page.dart';
import 'complete_profile_page.dart';
import 'terms_page.dart';

final _googleSignIn = GoogleSignIn();
final _firebaseAuth = FirebaseAuth.instance;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) throw Exception('Failed to get ID token');

      final resp = await ApiService().googleLogin(idToken);
      if (!mounted) return;
      final userMap = resp['user'] as Map<String, dynamic>?;
      final phone = userMap?['phone'] as String? ?? '';
      final role = userMap?['role'] ?? 'user';

      if (phone.isEmpty && role != 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CompleteProfilePage()));
        return;
      }

      if (role != 'admin') {
        try {
          final locResult = await LocationService().getCurrentLocation();
          if (locResult.error == null) {
            try {
              final zoneCheck = await DeliveryZoneService().checkLocation(locResult.latitude, locResult.longitude);
              if (!zoneCheck.serviceable && mounted) {
                AppSnackbar.show(context, zoneCheck.message ?? 'Sorry, delivery not available in your area', type: SnackbarType.error);
              }
            } catch (e) {
              debugPrint("login_page: $e");
              if (mounted) AppSnackbar.show(context, 'Could not verify delivery area. Please try again.', type: SnackbarType.warning);
            }
            try {
              await LocationService().saveLocationToServer(locResult.latitude, locResult.longitude);
            } catch (e) {
              debugPrint("login_page - saveLocationToServer: $e");
            }
          }
        } catch (e) {
          debugPrint("login_page: $e");
        }
      }

      if (!mounted) return;
      wishlistNotifier.load();
      cartNotifier.load();
      final nav = Navigator.of(context);
      if (role == 'admin') {
        nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AdminHomePage()), (route) => false);
      } else {
        nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.message ?? 'Sign in failed', type: SnackbarType.error);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.message, type: SnackbarType.error);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, 'Sign in failed. Please try again.', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Image.asset(
        'login/IMG_20260623_030259.png',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),
      // Google Sign-In button overlay
      Positioned(
        left: MediaQuery.of(context).size.width * 0.08,
        right: MediaQuery.of(context).size.width * 0.08,
        bottom: MediaQuery.of(context).size.height * 0.40,
        height: 56,
        child: ElevatedButton(
          onPressed: _loading ? null : _signInWithGoogle,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF3C4043),
            elevation: 3,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            side: BorderSide(color: Colors.grey.shade200, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22, height: 22,
                child: CustomPaint(
                  painter: _GoogleGPainter(),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Continue with Google',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: Color(0xFF3C4043)),
              ),
            ],
          ),
        ),
      ),
      // Terms text below Google button
      Positioned(
        left: MediaQuery.of(context).size.width * 0.08,
        right: MediaQuery.of(context).size.width * 0.08,
        bottom: MediaQuery.of(context).size.height * 0.10,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
            children: [
              const TextSpan(text: 'By continuing, you agree to our\n'),
              TextSpan(text: 'Terms of Service', style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w600), recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPage()))),
              const TextSpan(text: ' and '),
              TextSpan(text: 'Privacy Policy', style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w600), recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPage()))),
            ],
          ),
        ),
      ),
    ];
    if (_loading) {
      children.insert(1,
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        ),
      );
    }
    return Scaffold(
      body: Stack(children: children),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // White circle background
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);

    // Multi-color G using Google brand colors
    const googleColors = [
      Color(0xFF4285F4), // Blue
      Color(0xFFEA4335), // Red
      Color(0xFFFBBC05), // Yellow
      Color(0xFF34A853), // Green
    ];

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(
          fontSize: size.width * 0.85,
          fontWeight: FontWeight.w700,
          foreground: Paint()
            ..shader = LinearGradient(
              colors: googleColors,
              stops: const [0.0, 0.4, 0.7, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
