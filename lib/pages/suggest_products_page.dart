import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';

class SuggestProductsPage extends StatefulWidget {
  const SuggestProductsPage({super.key});

  @override
  State<SuggestProductsPage> createState() => _SuggestProductsPageState();
}

class _SuggestProductsPageState extends State<SuggestProductsPage> {
  final _productController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _saving = false;

  String? _productError;
  String? _reasonError;

  @override
  void dispose() {
    _productController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _productError = _productController.text.trim().isEmpty
          ? 'Product name is required'
          : null;
      _reasonError = null;
    });
    return _productError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService().suggestProduct(
        _productController.text.trim(),
        _reasonController.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Thanks for your suggestion!', type: SnackbarType.success);
      _productController.clear();
      _reasonController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.message, type: SnackbarType.error);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, '$e', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Suggest a Product', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Product Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _productController,
              decoration: InputDecoration(
                hintText: 'Enter product name',
                hintStyle: const TextStyle(color: AppColors.textHint),
                errorText: _productError,
                border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
              ),
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              cursorColor: AppColors.primary,
            ),
            if (_productError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_productError!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
              ),
            const SizedBox(height: 24),
            const Text('Why do you need this?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tell us why...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                errorText: _reasonError,
                border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
              ),
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              cursorColor: AppColors.primary,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Submit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}