import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/success_modal.dart';
import 'home_page.dart';

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
  final _otpCtl = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passError;
  String? _confirmError;
  String? _otpError;

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

  bool _isValidEmail(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
  bool _isValidPhone(String p) => RegExp(r'^\+?[1-9]\d{9,14}$').hasMatch(p);

  Future<void> _signup() async {
    setState(() {
      final name = _nameCtl.text.trim();
      final email = _emailCtl.text.trim();
      final phone = _phoneCtl.text.trim();
      _nameError = name.isEmpty ? 'Name is required' : null;
      _emailError = email.isEmpty ? 'Email is required' : (!_isValidEmail(email) ? 'Invalid email format' : null);
      _phoneError = phone.isEmpty ? 'Phone number is required' : (!_isValidPhone(phone) ? 'Invalid phone number (10-15 digits)' : null);
      _passError = _passCtl.text.isEmpty ? 'Password is required' : null;
      _confirmError = _confirmPassCtl.text.isEmpty ? 'Confirm your password' : null;
      if (_passCtl.text.isNotEmpty && _confirmPassCtl.text.isNotEmpty && _passCtl.text != _confirmPassCtl.text) {
        _confirmError = 'Passwords do not match';
      }
    });
    if (_nameError != null || _emailError != null || _phoneError != null || _passError != null || _confirmError != null) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().register(_nameCtl.text.trim(), _emailCtl.text.trim(), _phoneCtl.text.trim(), _passCtl.text);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      AppSnackbar.show(context, 'Verification code sent to your email', type: SnackbarType.success);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.message, type: SnackbarType.error);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, 'Connection failed. Check server.', type: SnackbarType.error);
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtl.text.trim();
    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _otpError = 'Enter a valid 6-digit OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService().verifyRegistration(_emailCtl.text.trim(), otp);
      if (!mounted) return;
      var navigated = false;
      await SuccessModal.show(
        context,
        title: 'Account Created Successfully',
        subtitle: 'Welcome to Zipra',
        description: 'Your account is ready. Start shopping now.',
        primaryLabel: 'Continue Shopping',
        secondaryLabel: 'View Profile',
        onPrimary: () {
          navigated = true;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        },
        onSecondary: () {
          navigated = true;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        },
      );
      if (!navigated && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.message, type: SnackbarType.error);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, 'Connection failed. Check server.', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 50, 28, 60),
                decoration: const BoxDecoration(
                  gradient: AppColors.headerGradient,
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
                            BoxShadow(color: AppColors.shadow, blurRadius: 40, offset: const Offset(0, 15)),
                            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameCtl,
                              decoration: _fieldStyle('Full Name', Icons.person_outline).copyWith(errorText: _nameError),
                              onChanged: (_) { if (_nameError != null) setState(() => _nameError = null); },
                            ),
                            if (_nameError != null)
                              Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: Text(_nameError!, style: const TextStyle(fontSize: 11, color: AppColors.error))),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneCtl,
                              keyboardType: TextInputType.phone,
                              decoration: _fieldStyle('Phone Number', Icons.phone_outlined).copyWith(errorText: _phoneError),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailCtl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _fieldStyle('Email', Icons.email_outlined).copyWith(errorText: _emailError),
                              onChanged: (_) { if (_emailError != null) setState(() => _emailError = null); },
                            ),
                            if (_emailError != null)
                              Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: Text(_emailError!, style: const TextStyle(fontSize: 11, color: AppColors.error))),
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
                              Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: Text(_passError!, style: const TextStyle(fontSize: 11, color: AppColors.error))),
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
                              ).copyWith(errorText: _confirmError),
                              onChanged: (_) { if (_confirmError != null) setState(() => _confirmError = null); },
                            ),
                            if (_confirmError != null)
                              Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: Text(_confirmError!, style: const TextStyle(fontSize: 11, color: AppColors.error))),
                            if (_otpSent) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.mail_outline, size: 18, color: Colors.orange.shade700),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Verification code sent to ${_emailCtl.text.trim()}',
                                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _otpCtl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: 'Enter OTP',
                                  hintText: '000000',
                                  labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                  counterText: '',
                                  border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                                ),
                              ),
                              if (_otpError != null)
                                Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: Text(_otpError!, style: const TextStyle(fontSize: 11, color: AppColors.error))),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : (_otpSent ? _verifyOtp : _signup),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                    : Text(_otpSent ? 'Verify OTP' : 'Create Account', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
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
                  child: const Text('Sign In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ]),
              const SizedBox(height: 30),
            ],
          ),
        ),
            if (Navigator.canPop(context))
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white.withValues(alpha: 0.9)),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
