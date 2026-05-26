import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with SingleTickerProviderStateMixin {
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _confirmPassCtl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
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

  Future<void> _signup() async {
    if (_nameCtl.text.isEmpty || _emailCtl.text.isEmpty || _passCtl.text.isEmpty || _confirmPassCtl.text.isEmpty) {
      _showSnack('Please fill all fields');
      return;
    }
    if (_passCtl.text != _confirmPassCtl.text) {
      _showSnack('Passwords do not match');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService().register(_nameCtl.text.trim(), _emailCtl.text.trim(), _phoneCtl.text.trim(), _passCtl.text);
      if (!mounted) return;
      _showSnack('Account created successfully! Please login.');
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Connection failed. Check server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  InputDecoration _fieldStyle(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
      prefixIconConstraints: const BoxConstraints(minWidth: 40),
      suffixIcon: suffix,
      border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF), width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
    );
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _confirmPassCtl.dispose();
    _animCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 50, 28, 60),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF7B73FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60)),
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
                      child: const Icon(Icons.person_add_rounded, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 22),
                    const Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text('Join us and start shopping', style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 0.2)),
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
                            BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.10), blurRadius: 40, offset: const Offset(0, 15)),
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameCtl,
                              decoration: _fieldStyle('Full Name', Icons.person_outline),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneCtl,
                              keyboardType: TextInputType.phone,
                              decoration: _fieldStyle('Phone Number', Icons.phone_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailCtl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _fieldStyle('Email', Icons.email_outlined),
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
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmPassCtl,
                              obscureText: _obscureConfirm,
                              decoration: _fieldStyle('Confirm Password', Icons.lock_outlined,
                                suffix: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Colors.grey.shade400),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _signup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  shadowColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
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
                Text("Already have an account? ", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Sign In', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w700, fontSize: 14)),
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
