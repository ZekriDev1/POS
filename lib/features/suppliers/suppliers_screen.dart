import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/database/providers.dart';
import 'package:restropos/core/utils/app_theme.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 32, right: 32, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Suppliers', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            ElevatedButton.icon(
              onPressed: _addSupplier,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Supplier'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ]),
          const SizedBox(height: 24),
          FutureBuilder(
            future: ref.read(databaseProvider).getAllSuppliers(),
            builder: (ctx, snap) {
              final suppliers = snap.data ?? <dynamic>[];
              if (suppliers.isEmpty) {
                return const Center(child: Padding(padding: EdgeInsets.all(60), child: Text('No suppliers yet', style: TextStyle(color: AppTheme.textMuted))));
              }
              return Column(children: suppliers.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (s.phone != null) Text(s.phone!, style: const TextStyle(color: AppTheme.textMuted)),
                ]),
              )).toList());
            },
          ),
        ],
      ),
    );
  }

  void _addSupplier() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Supplier'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Name', labelText: 'Name')),
        const SizedBox(height: 12),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(hintText: 'Phone', labelText: 'Phone')),
        const SizedBox(height: 12),
        TextField(controller: emailCtrl, decoration: const InputDecoration(hintText: 'Email', labelText: 'Email')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () async {
          if (nameCtrl.text.trim().isEmpty) return;
          await ref.read(databaseProvider).createSupplier(
            's${DateTime.now().millisecondsSinceEpoch}',
            nameCtrl.text.trim(),
            phoneCtrl.text.isEmpty ? null : phoneCtrl.text.trim(),
            emailCtrl.text.isEmpty ? null : emailCtrl.text.trim(),
          );
          if (ctx.mounted) Navigator.pop(ctx);
          setState(() {});
        }, child: const Text('Save')),
      ],
    ));
  }
}
