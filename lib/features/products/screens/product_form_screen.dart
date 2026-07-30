import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:restropos/core/database/app_database.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/core/l10n/translations.dart';

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
      appBar: AppBar(title: Text(isEdit ? ref.t('editProduct') : ref.t('addProduct')), centerTitle: true),
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
                  _buildField(ref.t('productName'), _nameCtrl, required: true),
                  const SizedBox(height: 16),
                  _buildField(ref.t('barcode'), _barcodeCtrl),
                  const SizedBox(height: 16),
                  _buildField(ref.t('description'), _descCtrl),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _buildField(ref.t('costPrice'), _costCtrl, keyboardType: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField(ref.t('sellingPrice'), _priceCtrl, keyboardType: TextInputType.number, required: true)),
                  ]),
                  const SizedBox(height: 16),
                  _buildField(ref.t('quantity'), _qtyCtrl, keyboardType: TextInputType.number),
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
                      child: Text(isEdit ? ref.t('updateProduct') : ref.t('saveProduct'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
          validator: required ? (v) => (v == null || v.isEmpty) ? ref.t('required') : null : null,
          decoration: InputDecoration(
            filled: true, fillColor: AppTheme.bgColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  final _catIcons = <String, IconData>{
    'category': Icons.category, 'food': Icons.restaurant, 'drink': Icons.local_drink,
    'coffee': Icons.coffee, 'fastfood': Icons.fastfood, 'cake': Icons.cake,
    'icecream': Icons.icecream, 'fruit': Icons.apple, 'bread': Icons.bakery_dining,
    'snack': Icons.shopping_bag, 'tool': Icons.build, 'gift': Icons.card_giftcard,
    'other': Icons.more_horiz,
  };

  Widget _buildCategoryDropdown() {
    return FutureBuilder(
      future: ref.read(databaseProvider).getParentCategories(),
      builder: (ctx, snap) {
        final parents = snap.data ?? <dynamic>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(ref.t('category'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
              const Spacer(),
              GestureDetector(
                onTap: () => _addCategory(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(ref.t('newCategory'), style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            FutureBuilder(
              future: Future.wait(parents.map((p) => ref.read(databaseProvider).getSubCategories(p.id))),
              builder: (ctx, subSnap) {
                final allSubs = subSnap.data ?? <List<dynamic>>[];
                return DropdownButtonFormField<String>(
                  value: _categoryId,
                  items: [
                    DropdownMenuItem<String>(value: null, child: Text(ref.t('noneTop'))),
                    ...parents.asMap().entries.expand((e) {
                      final p = e.value;
                      final subs = e.key < allSubs.length ? allSubs[e.key] : <dynamic>[];
                      return [
                        DropdownMenuItem<String>(
                          value: p.id,
                          child: Row(children: [
                            Icon(_catIcons[p.icon] ?? Icons.category, size: 18, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        ...subs.map((s) => DropdownMenuItem<String>(
                          value: s.id,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Row(children: [
                              Icon(_catIcons[s.icon] ?? Icons.subdirectory_arrow_right, size: 16, color: AppTheme.textMuted),
                              const SizedBox(width: 8),
                              Text(s.name, style: const TextStyle(fontSize: 13)),
                            ]),
                          ),
                        )),
                      ];
                    }),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                  decoration: const InputDecoration(
                    filled: true, fillColor: AppTheme.bgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _addCategory() {
    final ctrl = TextEditingController();
    String? selectedIcon;
    String? selectedParent;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(ref.t('addCategory')),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: ref.t('categoryName'),
                    filled: true, fillColor: AppTheme.bgColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text(ref.t('icon'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  GestureDetector(onTap: () => setDialogState(() => selectedIcon = null),
                    child: Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: selectedIcon == null ? AppTheme.primary.withOpacity(0.1) : AppTheme.bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selectedIcon == null ? AppTheme.primary : Colors.transparent, width: 2),
                      ),
                      child: const Icon(Icons.category, size: 20, color: AppTheme.textMuted),
                    ),
                  ),
                  ...['food', 'drink', 'coffee', 'fastfood', 'cake', 'icecream', 'fruit', 'bread', 'snack', 'tool', 'gift', 'other'].map((key) {
                    final icons = {
                      'food': Icons.restaurant, 'drink': Icons.local_drink, 'coffee': Icons.coffee,
                      'fastfood': Icons.fastfood, 'cake': Icons.cake, 'icecream': Icons.icecream,
                      'fruit': Icons.apple, 'bread': Icons.bakery_dining, 'snack': Icons.shopping_bag,
                      'tool': Icons.build, 'gift': Icons.card_giftcard, 'other': Icons.more_horiz,
                    };
                    final active = selectedIcon == key;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIcon = key),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: active ? AppTheme.primary.withOpacity(0.1) : AppTheme.bgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? AppTheme.primary : Colors.transparent, width: 2),
                        ),
                        child: Icon(icons[key]!, size: 20, color: active ? AppTheme.primary : AppTheme.textMuted),
                      ),
                    );
                  }),
                ]),
                const SizedBox(height: 16),
                Text(ref.t('parentCategory'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                FutureBuilder(
                  future: ref.read(databaseProvider).getParentCategories(),
                  builder: (ctx, snap) {
                    final parents = snap.data ?? <dynamic>[];
                    return DropdownButtonFormField<String?>(
                      value: selectedParent,
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(ref.t('noneTop'))),
                        ...parents.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name))),
                      ],
                      onChanged: (v) => setDialogState(() => selectedParent = v),
                      decoration: const InputDecoration(
                        filled: true, fillColor: AppTheme.bgColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ref.t('cancel'))),
          TextButton(onPressed: () async {
            if (ctrl.text.trim().isEmpty) return;
            final db = ref.read(databaseProvider);
            final id = 'cat${DateTime.now().millisecondsSinceEpoch}';
            await db.createCategory(id: id, name: ctrl.text.trim(), icon: selectedIcon, parentId: selectedParent);
            if (ctx.mounted) Navigator.pop(ctx);
            setState(() => _categoryId = id);
          }, child: Text(ref.t('addCategory'))),
        ],
      ),
    ));
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ref.t('image'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
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
