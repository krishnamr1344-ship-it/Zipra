import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  bool _sent = false;
  bool _resetting = false;
  bool _showResetForm = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _codeCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) return;
    setState(() => _sent = true);
    try {
      final result = await ApiService().forgotPassword(email);
      if (!mounted) return;
      final code = result['code'] as String?;
      if (code != null) {
        _codeCtl.text = code;
        setState(() => _showResetForm = true);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, 'Failed: $e', type: SnackbarType.error);
      setState(() => _sent = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtl.text.trim();
    final code = _codeCtl.text.trim();
    final password = _passwordCtl.text.trim();
    if (code.isEmpty || password.isEmpty) return;
    setState(() => _resetting = true);
    try {
      await ApiService().resetPassword(email, code, password);
      if (!mounted) return;
      AppSnackbar.show(context, 'Password reset successful!', type: SnackbarType.success);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, '$e', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text('Enter your email to receive a password reset code.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            TextField(
              controller: _emailCtl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
            if (_showResetForm) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _codeCtl,
                decoration: InputDecoration(labelText: 'Reset Code', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'New Password', prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _showResetForm
                    ? (_resetting ? null : _resetPassword)
                    : (_sent ? null : _sendResetCode),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _resetting ? 'Resetting...' : _sent && !_showResetForm ? 'Code Sent!' : _showResetForm ? 'Reset Password' : 'Send Reset Code',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
