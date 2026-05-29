import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/delivery_zone_service.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import 'home_page.dart';
import 'admin_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  String? _emailError;
  String? _passError;

  bool _validate() {
    setState(() {
      _emailError = _emailCtl.text.trim().isEmpty ? 'Email is required' : null;
      _passError = _passCtl.text.isEmpty ? 'Password is required' : null;
    });
    return _emailError == null && _passError == null;
  }
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

  Future<void> _login() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    try {
      final resp = await ApiService().login(_emailCtl.text.trim(), _passCtl.text);
      if (!mounted) return;
      final role = resp['user']?['role'] ?? 'user';

      if (role != 'admin') {
        try {
          final locResult = await LocationService().getCurrentLocation();
          if (locResult.error == null) {
            try {
              final zoneCheck = await DeliveryZoneService().checkLocation(locResult.latitude, locResult.longitude);
              if (!zoneCheck.serviceable && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(zoneCheck.message ?? 'Sorry, delivery not available in your area'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.error,
                ));
              }
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Could not verify delivery area. Please try again.'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.warning,
                ));
              }
            }
            await LocationService().saveLocationToServer(locResult.latitude, locResult.longitude);
          }
        } catch (_) {}
      }

      if (!mounted) return;
      final nav = Navigator.of(context);
      if (role == 'admin') {
        nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AdminHomePage()), (route) => false);
      } else if (nav.canPop()) {
        nav.pop(true);
      } else {
        nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection failed. Check server.'), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    _animCtl.dispose();
    super.dispose();
  }

  InputDecoration _fieldStyle(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
      prefixIconConstraints: const BoxConstraints(minWidth: 40),
      suffixIcon: suffix,
      border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
    );
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
                    const Text('Welcome Back!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
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
                            TextField(
                              controller: _emailCtl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _fieldStyle('Email', Icons.email_outlined).copyWith(errorText: _emailError),
                              onChanged: (_) { if (_emailError != null) setState(() => _emailError = null); },
                            ),
                            if (_emailError != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 4, top: 2),
                                child: Text(_emailError!, style: const TextStyle(fontSize: 11, color: AppColors.error)),
                              ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passCtl,
                              obscureText: _obscurePass,
                              decoration: _fieldStyle('Password', Icons.lock_outlined,
                                suffix: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Colors.grey.shade400),
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                ),
                              ).copyWith(errorText: _passError),
                              onChanged: (_) { if (_passError != null) setState(() => _passError = null); },
                            ),
                            if (_passError != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 4, top: 2),
                                child: Text(_passError!, style: const TextStyle(fontSize: 11, color: AppColors.error)),
                              ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                                child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Don't have an account? ", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage())),
                  child: const Text('Sign Up', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ]),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
