import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zipra_shop/core/constants/theme.dart';
import 'package:zipra_shop/core/api/shop_api_service.dart';
import 'package:zipra_shop/core/models/shop_product.dart';

class ShopProductFormPage extends StatefulWidget {
  final ShopProduct? product;
  const ShopProductFormPage({super.key, this.product});

  @override
  State<ShopProductFormPage> createState() => _ShopProductFormPageState();
}

class _ShopProductFormPageState extends State<ShopProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _origPriceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _api = ShopApiService();
  final _picker = ImagePicker();
  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  final List<String> _existingImages = [];
  final List<File> _newImages = [];
  bool _loading = false;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_isEditing) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description ?? '';
      _priceCtrl.text = p.price.toString();
      _origPriceCtrl.text = p.originalPrice?.toString() ?? '';
      _unitCtrl.text = p.unit;
      _stockCtrl.text = p.stock.toString();
      _selectedCategoryId = p.categoryId;
      _existingImages.addAll(p.images);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _origPriceCtrl.dispose();
    _unitCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await _api.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load categories: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty) {
      setState(() {
        _newImages.addAll(files.map((f) => File(f.path)));
      });
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      String? productId;
      if (_isEditing) {
        productId = widget.product!.id;
        final data = {
          'category_id': _selectedCategoryId,
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          'price': double.tryParse(_priceCtrl.text) ?? 0,
          'original_price': _origPriceCtrl.text.isNotEmpty ? double.tryParse(_origPriceCtrl.text) : null,
          'unit': _unitCtrl.text.trim(),
          'stock': int.tryParse(_stockCtrl.text) ?? 0,
          'images': _existingImages,
        };
        await _api.updateProduct(productId, data);
      } else {
        final data = {
          'category_id': _selectedCategoryId,
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          'price': double.tryParse(_priceCtrl.text) ?? 0,
          'original_price': _origPriceCtrl.text.isNotEmpty ? double.tryParse(_origPriceCtrl.text) : null,
          'unit': _unitCtrl.text.trim(),
          'stock': int.tryParse(_stockCtrl.text) ?? 0,
          'images': <String>[],
        };
        final result = await _api.createProduct(data);
        productId = result['id'] as String?;
      }
      if (productId != null) {
        for (final file in _newImages) {
          try {
            final imageUrl = await _api.uploadProductImage(productId, file.path);
            if (imageUrl.isNotEmpty) {
              _existingImages.add(imageUrl);
              setState(() {});
            }
          } catch (e) {
            debugPrint('Image upload failed: $e');
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Product updated' : 'Product created (pending approval)')),
      );
      Navigator.pop(context);
    } on ShopApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save product: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _loading ? _buildLoading() : _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Product' : 'Add Product',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Basic Information', Icons.info_outline),
            const SizedBox(height: AppSpacing.md),
            _buildCategoryDropdown(),
            const SizedBox(height: AppSpacing.lg),
            _buildTextField(
              controller: _nameCtrl,
              label: 'Product Name',
              icon: Icons.label_outline,
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildTextField(
              controller: _descCtrl,
              label: 'Description (optional)',
              icon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSectionHeader('Pricing & Stock', Icons.attach_money_rounded),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _priceCtrl,
                    label: 'Price (\u20B9)',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Invalid price';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildTextField(
                    controller: _origPriceCtrl,
                    label: 'Original (\u20B9)',
                    icon: Icons.price_check_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _unitCtrl,
                    label: 'Unit (kg, L, pack)',
                    icon: Icons.straighten_rounded,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildTextField(
                    controller: _stockCtrl,
                    label: 'Stock',
                    icon: Icons.inventory_2_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (int.tryParse(v) == null || int.parse(v) < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSectionHeader('Product Images', Icons.photo_library_outlined),
            const SizedBox(height: AppSpacing.md),
            _buildImageSection(),
            if (!_isEditing) ...[
              const SizedBox(height: AppSpacing.xxl),
              _buildApprovalNotice(),
            ],
            const SizedBox(height: AppSpacing.xxl),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category_outlined, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: _categories.map<DropdownMenuItem<String>>((c) {
        return DropdownMenuItem(value: c['id'] as String, child: Text(c['name'] as String));
      }).toList(),
      onChanged: (v) => setState(() => _selectedCategoryId = v),
      validator: (v) => v == null ? 'Select a category' : null,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _buildImageSection() {
    final hasImages = _existingImages.isNotEmpty || _newImages.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImages)
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._existingImages.asMap().entries.map(
                  (entry) => _ImageTile(
                    imageUrl: entry.value,
                    onRemove: () => _removeExistingImage(entry.key),
                  ),
                ),
                ..._newImages.asMap().entries.map(
                  (entry) => _ImageTile(
                    file: entry.value,
                    onRemove: () => _removeNewImage(entry.key),
                  ),
                ),
                _AddImageButton(onTap: _pickImages),
              ],
            ),
          )
        else
          _AddImagePlaceholder(onTap: _pickImages),
      ],
    );
  }

  Widget _buildApprovalNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'New products require admin approval before appearing in the customer app.',
              style: TextStyle(fontSize: 13, color: AppColors.warning, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _saving ? null : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: _saving
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _saving ? AppColors.primary.withValues(alpha: 0.6) : Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isEditing ? Icons.check_rounded : Icons.add_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isEditing ? 'Update Product' : 'Create Product',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String? imageUrl;
  final File? file;
  final VoidCallback onRemove;

  const _ImageTile({this.imageUrl, this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: imageUrl != null
                ? Image.network(
                    resolveImageUrl(imageUrl!),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, a, b) => Container(
                      width: 100,
                      height: 100,
                      color: AppColors.surfaceDim,
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.textHint),
                    ),
                  )
                : Image.file(
                    file!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddImageButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddImageButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 26, color: AppColors.primary),
            SizedBox(height: 4),
            Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _AddImagePlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _AddImagePlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.primaryLight),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Tap to add images',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            const Text(
              'At least 1 image required',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
