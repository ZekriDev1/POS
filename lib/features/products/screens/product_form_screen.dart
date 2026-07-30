import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _qtyCtrl;
  String? _categoryId;
  String? _imagePath;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _costCtrl = TextEditingController(text: p?.costPrice?.toString() ?? '');
    _priceCtrl = TextEditingController(text: p?.sellingPrice.toString() ?? '');
    _qtyCtrl = TextEditingController(text: p?.quantity.toString() ?? '0');
    _categoryId = p?.categoryId;
    _imagePath = p?.image;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _descCtrl.dispose();
    _costCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _imagePath = file.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = ref.read(databaseProvider);
    final id = widget.product?.id;
    final price = double.parse(_priceCtrl.text);
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    final cost = double.tryParse(_costCtrl.text);

    if (id != null) {
      await db.updateProductFields(
        id: id,
        barcode: _barcodeCtrl.text.isEmpty ? null : _barcodeCtrl.text,
        name: _nameCtrl.text,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
        image: _imagePath,
        categoryId: _categoryId,
        costPrice: cost,
        sellingPrice: price,
        quantity: qty,
      );
    } else {
      await db.createProduct(
        id: 'p${DateTime.now().millisecondsSinceEpoch}',
        barcode: _barcodeCtrl.text.isEmpty ? null : _barcodeCtrl.text,
        name: _nameCtrl.text,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
        image: _imagePath,
        categoryId: _categoryId,
        costPrice: cost,
        sellingPrice: price,
        quantity: qty,
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: Text(isEdit ? 'Edit Product' : 'Add Product'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(24)),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField('Product Name', _nameCtrl, required: true),
                  const SizedBox(height: 16),
                  _buildField('Barcode', _barcodeCtrl),
                  const SizedBox(height: 16),
                  _buildField('Description', _descCtrl),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _buildField('Cost Price', _costCtrl, keyboardType: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField('Selling Price', _priceCtrl, keyboardType: TextInputType.number, required: true)),
                  ]),
                  const SizedBox(height: 16),
                  _buildField('Quantity', _qtyCtrl, keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 16),
                  _buildImagePicker(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isEdit ? 'Update Product' : 'Save Product', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {bool required = false, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label${required ? " *" : ""}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
          decoration: InputDecoration(
            filled: true, fillColor: AppTheme.bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return FutureBuilder(
      future: ref.read(databaseProvider).getAllCategories(),
      builder: (ctx, snap) {
        final cats = snap.data ?? <dynamic>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
              const Spacer(),
              GestureDetector(
                onTap: () => _addCategory(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 14, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text('New', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _categoryId,
              items: cats.map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _categoryId = v),
              decoration: InputDecoration(
                filled: true, fillColor: AppTheme.bgColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addCategory() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Category'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Category name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () async {
          if (ctrl.text.trim().isEmpty) return;
          final db = ref.read(databaseProvider);
          final id = 'cat${DateTime.now().millisecondsSinceEpoch}';
          await db.createCategory(id, ctrl.text.trim());
          if (ctx.mounted) Navigator.pop(ctx);
          setState(() => _categoryId = id);
        }, child: const Text('Add')),
      ],
    ));
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.bgColor,
            ),
            child: _imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_imagePath!), fit: BoxFit.cover, width: double.infinity, height: 120),
                  )
                : const Center(child: Icon(Icons.add_photo_alternate, color: AppTheme.textMuted, size: 32)),
          ),
        ),
      ],
    );
  }
}
