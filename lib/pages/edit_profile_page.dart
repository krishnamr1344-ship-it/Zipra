import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameCtl;
  late TextEditingController _phoneCtl;
  late TextEditingController _emailCtl;
  final _api = ApiService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.user['name'] ?? '');
    _phoneCtl = TextEditingController(text: widget.user['phone'] ?? '');
    _emailCtl = TextEditingController(text: widget.user['email'] ?? '');
  }

  Future<void> _save() async {
    if (_nameCtl.text.trim().isEmpty) {
      _showSnack('Name is required');
      return;
    }
    setState(() => _saving = true);
    await _api.saveUser(_nameCtl.text.trim(), _emailCtl.text.trim(), phone: _phoneCtl.text.trim());
    if (!mounted) return;
    Navigator.pop(context, {
      'name': _nameCtl.text.trim(),
      'email': _emailCtl.text.trim(),
      'phone': _phoneCtl.text.trim(),
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  InputDecoration _fieldStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, size: 20, color: AppColors.textHint),
      prefixIconConstraints: const BoxConstraints(minWidth: 40),
      border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textHint)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
    );
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: CircleAvatar(
                      radius: 40,
                        backgroundColor: AppColors.primary,
                      child: Text(
                        (_nameCtl.text.isNotEmpty ? _nameCtl.text[0] : 'U').toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Tap to change photo', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nameCtl,
                    decoration: _fieldStyle('Full Name', Icons.person_outline),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phoneCtl,
                    keyboardType: TextInputType.phone,
                    decoration: _fieldStyle('Phone Number', Icons.phone_outlined),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _fieldStyle('Email', Icons.email_outlined),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
