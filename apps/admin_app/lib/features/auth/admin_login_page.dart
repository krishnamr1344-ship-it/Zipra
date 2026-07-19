import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';
import '../../core/api/api_service.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().loginEmail(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      if (!mounted) return;
      final role = res['user']?['role'] ?? res['role'] ?? '';
      if (role != 'admin') {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied. Admin only.')),
        );
        return;
      }
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      String msg = 'Login failed. Please try again.';
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('invalid credentials')) msg = 'Invalid email or password.';
      if (errStr.contains('not found') || errStr.contains('404')) msg = 'Account not found.';
      if (errStr.contains('connection') || errStr.contains('socket')) msg = 'No internet connection.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          margin: const EdgeInsets.all(AppSpacing.lg),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height - 100),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      SizedBox(height: isSmall ? 40 : 60),
                      _buildHeader(),
                      const SizedBox(height: AppSpacing.xxl),
                      _buildForm(),
                      const Spacer(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [AppShadows.colored],
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Welcome Back', style: AppText.h1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sign in to admin dashboard',
          style: AppText.subtitle.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildInput(
            controller: _emailCtrl,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter valid email';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInput(
            controller: _passCtrl,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Icon(
                _obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.textHint,
                size: 20,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [AppShadows.soft],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        style: AppText.body,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppText.body.copyWith(color: AppColors.textHint),
          prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.divider, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide:
                const BorderSide(color: AppColors.error, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
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
            : const Text('Sign In', style: AppText.button),
      ),
    );
  }
}
