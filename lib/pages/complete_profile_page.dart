import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/delivery_zone_service.dart';
import '../widgets/app_snackbar.dart';
import '../models/cart_model.dart';
import 'home_page.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _phoneCtl = TextEditingController();
  bool _loading = false;
  String? _phoneError;

  bool _isValidPhone(String p) => RegExp(r'^\+?[1-9]\d{9,14}$').hasMatch(p);

  Future<void> _save() async {
    final phone = _phoneCtl.text.trim();
    if (!_isValidPhone(phone)) {
      setState(() => _phoneError = 'Enter a valid phone number (10-15 digits)');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService().updatePhone(phone);
      if (!mounted) return;
      try {
        final locResult = await LocationService().getCurrentLocation();
        if (locResult.error == null) {
          try {
            final zoneCheck = await DeliveryZoneService().checkLocation(locResult.latitude, locResult.longitude);
            if (!zoneCheck.serviceable && mounted) {
              AppSnackbar.show(context, zoneCheck.message ?? 'Sorry, delivery not available in your area', type: SnackbarType.error);
            }
          } catch (e) {
            debugPrint("CompleteProfilePage: $e");
          }
          try {
            await LocationService().saveLocationToServer(locResult.latitude, locResult.longitude);
          } catch (e) {
            debugPrint("CompleteProfilePage - saveLocationToServer: $e");
          }
        }
      } catch (e) {
        debugPrint("CompleteProfilePage location: $e");
      }
      wishlistNotifier.load();
      cartNotifier.load();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomePage()), (route) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.message, type: SnackbarType.error);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, 'Failed to save. Please try again.', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneCtl.dispose();
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
                      child: const Icon(Icons.phone_android_rounded, size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 22),
                    const Text('Complete Your Profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text('Add your phone number to continue', style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Container(
                  padding: const EdgeInsets.all(28),
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
                        controller: _phoneCtl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'e.g. 9988776655',
                          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                          prefixIcon: Icon(Icons.phone_outlined, size: 20, color: Colors.grey.shade400),
                          border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                          errorText: _phoneError,
                        ),
                        onChanged: (_) { if (_phoneError != null) setState(() => _phoneError = null); },
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _loading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                              : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
