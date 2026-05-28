import 'package:flutter/material.dart';
import '../constants/theme.dart';

class SuggestProductsPage extends StatefulWidget {
  const SuggestProductsPage({super.key});

  @override
  State<SuggestProductsPage> createState() => _SuggestProductsPageState();
}

class _SuggestProductsPageState extends State<SuggestProductsPage> {
  final _productController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _productController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thanks for your suggestion!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
    _productController.clear();
    _reasonController.clear();
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
              decoration: const InputDecoration(
                hintText: 'Enter product name',
                hintStyle: TextStyle(color: AppColors.textHint),
                border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
              ),
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              cursorColor: AppColors.primary,
            ),
            const SizedBox(height: 24),
            const Text('Why do you need this?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tell us why...',
                hintStyle: TextStyle(color: AppColors.textHint),
                border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2)),
              ),
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              cursorColor: AppColors.primary,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Submit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
