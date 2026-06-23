import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/permission_service.dart';
import '../services/cloudinary_service.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/permission_bottom_sheet.dart';

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
  final _picker = ImagePicker();
  final _permissionService = PermissionService();
  bool _saving = false;
  String? _profileImageUrl;

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
    try {
      await _api.updateProfile(_nameCtl.text.trim(), _emailCtl.text.trim(), phone: _phoneCtl.text.trim());
    } catch (e) {
        debugPrint("pages.edit_profile_page: $e");
      await _api.saveUser(_nameCtl.text.trim(), _emailCtl.text.trim(), phone: _phoneCtl.text.trim());
    }
    if (!mounted) return;
    Navigator.pop(context, {
      'name': _nameCtl.text.trim(),
      'email': _emailCtl.text.trim(),
      'phone': _phoneCtl.text.trim(),
    });
  }

  void _showSnack(String msg) {
    AppSnackbar.show(context, msg, type: SnackbarType.warning);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final status = await _permissionService.ensure(AppPermission.camera);
        if (!mounted) return;
        if (status == PermissionStatus.permanentlyDenied) {
          showPermissionSheet(
            context: context,
            permission: AppPermission.camera,
            title: 'Camera Access Required',
            message: 'Allow Zipra to take pictures to set your profile photo.',
            isPermanentlyDenied: true,
          );
          return;
        }
        if (status == PermissionStatus.denied) {
          showPermissionSheet(
            context: context,
            permission: AppPermission.camera,
            title: 'Camera Access Required',
            message: 'Allow Zipra to take pictures to set your profile photo.',
            onGranted: () => _openPicker(source),
          );
          return;
        }
      } else {
        final status = await _permissionService.ensure(AppPermission.photos);
        if (!mounted) return;
        if (status == PermissionStatus.permanentlyDenied) {
          showPermissionSheet(
            context: context,
            permission: AppPermission.photos,
            title: 'Photo Access Required',
            message: 'Allow Zipra to access your photos to set your profile photo.',
            isPermanentlyDenied: true,
          );
          return;
        }
        if (status == PermissionStatus.denied) {
          showPermissionSheet(
            context: context,
            permission: AppPermission.photos,
            title: 'Photo Access Required',
            message: 'Allow Zipra to access your photos to set your profile photo.',
            onGranted: () => _openPicker(source),
          );
          return;
        }
      }
      await _openPicker(source);
    } catch (e) {
      debugPrint("pages.edit_profile_page: $e");
      if (mounted) _showSnack('Failed to pick image');
    }
  }

  Future<void> _openPicker(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null || !mounted) return;
      setState(() => _saving = true);
      final url = await CloudinaryService.uploadImage(picked.path);
      if (!mounted) return;
      setState(() {
        _profileImageUrl = url;
        _saving = false;
      });
      _showSnack('Profile photo updated');
    } catch (e) {
      debugPrint("pages.edit_profile_page upload: $e");
      if (mounted) {
        setState(() => _saving = false);
        _showSnack('Failed to upload image');
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                  GestureDetector(
                    onTap: _showImageSourceSheet,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primary,
                            backgroundImage: _profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!)
                                : null,
                            child: _profileImageUrl == null
                                ? Text(
                                    (_nameCtl.text.isNotEmpty ? _nameCtl.text[0] : 'U').toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _showImageSourceSheet,
                    child: Text(
                      'Tap to change photo',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ),
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
