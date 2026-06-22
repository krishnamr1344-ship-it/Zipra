import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

final _googleSignIn = GoogleSignIn();
final _firebaseAuth = FirebaseAuth.instance;

const Color _orangeStart = Color(0xFFFF6B00);
const Color _orangeEnd = Color(0xFFE55200);
const Color _yellowHighlight = Color(0xFFFFE082);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _showContent = false;
  late AnimationController _animCtl;
  late Animation<double> _logoScale;
  late Animation<double> _fadeIn;
  late Animation<Offset> _bottomSlide;

  @override
  void initState() {
    super.initState();
    _animCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _animCtl, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)));
    _fadeIn = CurvedAnimation(parent: _animCtl, curve: const Interval(0.3, 0.7, curve: Curves.easeOut));
    _bottomSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animCtl, curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)));

    _animCtl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showContent = true);
      }
    });
    _animCtl.forward();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
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
              debugPrint("SplashScreen: $e");
              if (mounted) AppSnackbar.show(context, 'Could not verify delivery area. Please try again.', type: SnackbarType.warning);
            }
            try {
              await LocationService().saveLocationToServer(locResult.latitude, locResult.longitude);
            } catch (e) {
              debugPrint("SplashScreen - saveLocationToServer: $e");
            }
          }
        } catch (e) {
          debugPrint("SplashScreen: $e");
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
  void dispose() {
    _animCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _orangeStart,
      body: SafeArea(
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_orangeStart, _orangeEnd],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Decorative circles
            Positioned(top: -50, right: -70, child: Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.05)))),
            Positioned(top: 10, right: -30, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.03)))),
            // Top content
            Positioned(
              top: 0, left: 0, right: 0,
              height: MediaQuery.of(context).size.height * 0.56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2.5),
                        ),
                        child: const Icon(Icons.shopping_bag_rounded, size: 48, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: Text('Zipra', style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 3)),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Groceries\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, letterSpacing: -0.5)),
                          TextSpan(text: 'Delivered in\n', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, letterSpacing: -0.5)),
                          TextSpan(text: 'Minutes', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _yellowHighlight, height: 1.1, letterSpacing: -0.5)),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50),
                      child: Text(
                        'Fresh groceries, dairy, fruits &\nvegetables at your doorstep.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withValues(alpha: 0.8), height: 1.5, letterSpacing: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Left grocery bag
            if (_showContent)
              Positioned(
                left: -28, top: 50,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showContent ? 1 : 0,
                    duration: const Duration(milliseconds: 600),
                    child: Transform.rotate(
                      angle: -0.06,
                      child: SizedBox(
                        width: 110, height: 140,
                        child: CustomPaint(painter: _PaperBagPainter()),
                      ),
                    ),
                  ),
                ),
              ),
            // Right grocery basket
            if (_showContent)
              Positioned(
                right: -32, top: 40,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showContent ? 1 : 0,
                    duration: const Duration(milliseconds: 600),
                    child: Transform.rotate(
                      angle: 0.05,
                      child: SizedBox(
                        width: 120, height: 150,
                        child: CustomPaint(painter: _BasketPainter()),
                      ),
                    ),
                  ),
                ),
              ),
            // Bottom card
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: MediaQuery.of(context).size.height * 0.48,
              child: SlideTransition(
                position: _bottomSlide,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                    boxShadow: [
                      BoxShadow(color: Color(0x1A000000), blurRadius: 50, offset: Offset(0, -10)),
                      BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, -5)),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(left: 28, right: 28, top: 32, bottom: MediaQuery.of(context).padding.bottom + 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signInWithGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF3C4043),
                              elevation: 2,
                              shadowColor: Colors.black.withValues(alpha: 0.12),
                              side: BorderSide(color: Colors.grey.shade200, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _loading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.grey))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 22, height: 22,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: const Text('G', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                      const SizedBox(width: 14),
                                      Text('Continue with Google', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: const Color(0xFF3C4043))),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            const Expanded(child: _FeatureColumn(
                              icon: Icons.delivery_dining_rounded, iconColor: Color(0xFFE65100),
                              bgColor: Color(0x20FF5A00), title: 'Fast Delivery',
                              description: 'Lightning fast\ndelivery',
                            )),
                            Container(width: 1, height: 56, color: Colors.grey.shade200),
                            const Expanded(child: _FeatureColumn(
                              icon: Icons.eco_rounded, iconColor: Color(0xFF2E7D32),
                              bgColor: Color(0x202E7D32), title: 'Fresh Products',
                              description: 'Always fresh,\nalways quality',
                            )),
                            Container(width: 1, height: 56, color: Colors.grey.shade200),
                            const Expanded(child: _FeatureColumn(
                              icon: Icons.verified_user_rounded, iconColor: Color(0xFFE65100),
                              bgColor: Color(0x20FF5A00), title: 'Secure Payments',
                              description: '100% secure\ntransactions',
                            )),
                          ],
                        ),
                        const SizedBox(height: 28),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500, height: 1.6),
                            children: const [
                              TextSpan(text: 'By continuing, you agree to our\n'),
                              TextSpan(text: 'Terms of Service', style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w600)),
                              TextSpan(text: ' and '),
                              TextSpan(text: 'Privacy Policy', style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 28,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              const icons = [
                                Icons.apple_rounded, Icons.eco_rounded,
                                Icons.water_drop_rounded, Icons.spa_rounded, Icons.restaurant_rounded,
                              ];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(icons[i], size: 20, color: const Color(0x20FF5A00)),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String description;

  const _FeatureColumn({required this.icon, required this.iconColor, required this.bgColor, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(height: 6),
        Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
        const SizedBox(height: 2),
        Text(description, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500, height: 1.3)),
      ],
    );
  }
}

class _PaperBagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFD4A574).withValues(alpha: 0.5);
    final bagPath = Path()
      ..moveTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.85, 0)
      ..lineTo(size.width * 0.85, size.height * 0.85)
      ..lineTo(size.width * 0.75, size.height * 0.95)
      ..lineTo(size.width * 0.35, size.height * 0.95)
      ..lineTo(size.width * 0.25, size.height * 0.85)
      ..close();
    canvas.drawPath(bagPath, paint);

    paint.color = const Color(0xFF4CAF50).withValues(alpha: 0.6);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.6, size.height * 0.2), width: 25, height: 12), paint);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.45, size.height * 0.25), width: 20, height: 10), paint);

    paint.color = const Color(0xFFE53935).withValues(alpha: 0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(size.width * 0.55, size.height * 0.4), width: 16, height: 20), const Radius.circular(8)), paint);

    paint.color = const Color(0xFFFFD54F).withValues(alpha: 0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(size.width * 0.4, size.height * 0.5), width: 14, height: 18), const Radius.circular(7)), paint);

    paint.color = const Color(0xFFE53935).withValues(alpha: 0.4);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.55), 10, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BasketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF8D6E63).withValues(alpha: 0.4);
    final basketPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.3)
      ..lineTo(size.width * 0.9, size.height * 0.3)
      ..lineTo(size.width * 0.85, size.height * 0.95)
      ..lineTo(size.width * 0.15, size.height * 0.95)
      ..close();
    canvas.drawPath(basketPath, paint);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.color = const Color(0xFF8D6E63).withValues(alpha: 0.5);
    canvas.drawArc(Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.15), width: 50, height: 40), math.pi, math.pi, false, paint);
    paint.style = PaintingStyle.fill;

    paint.color = const Color(0xFF388E3C).withValues(alpha: 0.5);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.45), 12, paint);
    paint.color = const Color(0xFF2E7D32).withValues(alpha: 0.4);
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.4), 8, paint);

    paint.color = const Color(0xFFBBDEFB).withValues(alpha: 0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(size.width * 0.7, size.height * 0.45), width: 14, height: 24), const Radius.circular(4)), paint);

    paint.color = const Color(0xFFFFF176).withValues(alpha: 0.5);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.55), width: 16, height: 12), paint);

    paint.color = const Color(0xFFE53935).withValues(alpha: 0.45);
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.6), 10, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
