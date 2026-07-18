import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/api/api_service.dart';
import '../dashboard/admin_home_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> with SingleTickerProviderStateMixin {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _loading = false;
  bool _obscure = true;
  String? _emailError;
  String? _passError;
  late AnimationController _animCtl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtl, curve: Curves.easeOutCubic),
    );
    _animCtl.forward();
  }

  @override
  void dispose() {
    _animCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;
    setState(() {
      _emailError = null;
      _passError = null;
    });
    if (email.isEmpty) {
      setState(() => _emailError = 'Email is required');
      valid = false;
    } else if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      valid = false;
    }
    if (pass.isEmpty) {
      setState(() => _passError = 'Password is required');
      valid = false;
    } else if (pass.length < 6) {
      setState(() => _passError = 'Password must be at least 6 characters');
      valid = false;
    }
    return valid;
  }

  Future<void> _login() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    try {
      final body = await ApiService().loginEmail(_emailCtl.text.trim(), _passCtl.text);
      if (!mounted) return;
      final role = body['user']?['role'] ?? '';
      if (role == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminHomePage()),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access denied. Admin only.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      String msg = 'Login failed. Please try again.';
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('invalid credentials')) msg = 'Invalid email or password.';
      if (errStr.contains('not found') || errStr.contains('404')) msg = 'Account not found.';
      if (errStr.contains('connection') || errStr.contains('socket')) msg = 'No internet connection.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)), margin: const EdgeInsets.all(AppSpacing.lg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(isWide ? 48 : 24),
                    child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return SizedBox(
      width: 900,
      child: Row(
        children: [
          Expanded(child: _buildBrandPanel()),
          const SizedBox(width: 32),
          Expanded(child: _buildFormCard()),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBrandPanel(),
        const SizedBox(height: 24),
        _buildFormCard(),
      ],
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [AppShadows.strong],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40F97316),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.shield, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'Zipra Admin',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textOnDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enterprise Management',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textOnDark.withValues(alpha: 0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Monitor orders, manage products,\nand grow your business.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textOnDark.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: const [AppShadows.medium],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to your admin account',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailCtl,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _passFocus.requestFocus(),
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'admin@example.com',
                errorText: _emailError,
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: _emailError != null ? AppColors.error : AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: _emailError != null ? AppColors.error : AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: _emailError != null ? AppColors.error : AppColors.accent, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                floatingLabelStyle: TextStyle(color: _emailError != null ? AppColors.error : AppColors.accent),
              ),
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _passCtl,
              focusNode: _passFocus,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                errorText: _passError,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: _passError != null ? AppColors.error : AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: _passError != null ? AppColors.error : AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide(color: _passError != null ? AppColors.error : AppColors.accent, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                floatingLabelStyle: TextStyle(color: _passError != null ? AppColors.error : AppColors.accent),
              ),
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x30F97316),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Sign In'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
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
