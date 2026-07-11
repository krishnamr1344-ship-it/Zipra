import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import 'home_page.dart';
import 'admin_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  bool _loading = false;
  late AnimationController _animCtl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _animCtl, curve: Curves.easeOutCubic));
    _animCtl.forward();
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      final info = await FirebaseService.instance.signInWithGoogle();
      if (!mounted) return;
      final user = info['user'] as Map<String, dynamic>;
      final idToken = info['token'] as String;
      final body = await ApiService().socialLogin(
        user['email'] ?? '',
        user['name'] ?? '',
        idToken,
        '',
      );
      if (!mounted) return;

      final role = body['user']?['role'] ?? 'user';
      final nav = Navigator.of(context);
      if (role == 'admin') {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminHomePage()),
          (route) => false,
        );
      } else if (nav.canPop()) {
        nav.pop(true);
      } else {
        nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 50, 28, 60),
                decoration: const BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(60)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Icon(Icons.shopping_bag_rounded, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 22),
                    const Text('Welcome!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text('Sign in to continue shopping', style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 0.2)),
                  ],
                ),
              ),
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(color: AppColors.shadow, blurRadius: 40, offset: const Offset(0, 15)),
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Continue with your Google account to start ordering groceries delivered to your door.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _loginWithGoogle,
                                icon: Image.network(
                                  'https://developers.google.com/identity/images/g-logo.png',
                                  height: 22,
                                  width: 22,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
                                ),
                                label: _loading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                                    : const Text('Continue with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade800,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
