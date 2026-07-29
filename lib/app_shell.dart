import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/features/dashboard/screens/dashboard_screen.dart';
import 'package:restropos/features/pos/pos_screen.dart';
import 'package:restropos/features/pos/billing_panel.dart';
import 'package:restropos/features/sales/sales_history_screen.dart';
import 'package:restropos/features/wallet/wallet_screen.dart';
import 'package:restropos/features/invoices/invoice_screen.dart';
import 'package:restropos/features/categories/categories_screen.dart';
import 'package:restropos/features/customers/customers_screen.dart';
import 'package:restropos/features/suppliers/suppliers_screen.dart';
import 'package:restropos/features/inventory/inventory_screen.dart';
import 'package:restropos/features/settings/settings_screen.dart';

enum AppView { dashboard, menu, history, wallet, invoice, categories, customers, suppliers, inventory, settings }

final appViewProvider = StateProvider<AppView>((ref) => AppView.dashboard);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(appViewProvider);
    return Row(
      children: [
        _Sidebar(currentView: view, onViewChanged: (v) => ref.read(appViewProvider.notifier).state = v),
        Expanded(
          child: Column(
            children: [
              _Header(title: _titleFor(view)),
              Expanded(
                child: _buildContent(view, context, ref),
              ),
            ],
          ),
        ),
        if (view == AppView.menu) const BillingPanel(),
      ],
    );
  }

  String _titleFor(AppView view) {
    switch (view) {
      case AppView.dashboard: return 'Dashboard';
      case AppView.menu: return 'Menu';
      case AppView.history: return 'History';
      case AppView.wallet: return 'Wallet';
      case AppView.invoice: return 'Invoice Settings';
      case AppView.categories: return 'Categories';
      case AppView.customers: return 'Customers';
      case AppView.suppliers: return 'Suppliers';
      case AppView.inventory: return 'Inventory';
      case AppView.settings: return 'Settings';
    }
  }

  Widget _buildContent(AppView view, BuildContext context, WidgetRef ref) {
    switch (view) {
      case AppView.dashboard: return const DashboardScreen();
      case AppView.menu: return const PosScreen();
      case AppView.history: return const SalesHistoryScreen();
      case AppView.wallet: return const WalletScreen();
      case AppView.invoice: return const InvoiceScreen();
      case AppView.categories: return const CategoriesScreen();
      case AppView.customers: return const CustomersScreen();
      case AppView.suppliers: return const SuppliersScreen();
      case AppView.inventory: return const InventoryScreen();
      case AppView.settings: return const SettingsScreen();
    }
  }
}

class _Sidebar extends StatelessWidget {
  final AppView currentView;
  final ValueChanged<AppView> onViewChanged;
  const _Sidebar({required this.currentView, required this.onViewChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.point_of_sale, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Column(
              children: [
                _navItem(Icons.dashboard, 'Dashboard', AppView.dashboard),
                const SizedBox(height: 8),
                _navItem(Icons.menu_book, 'Menu', AppView.menu),
                const SizedBox(height: 8),
                _navItem(Icons.history, 'History', AppView.history),
                const SizedBox(height: 8),
                _navItem(Icons.account_balance_wallet, 'Wallet', AppView.wallet),
                const SizedBox(height: 8),
                _navItem(Icons.receipt, 'Invoice', AppView.invoice),
              ],
            ),
          ),
          const Divider(height: 1),
          _navItem(Icons.category, 'Categories', AppView.categories, compact: true),
          _navItem(Icons.people, 'Customers', AppView.customers, compact: true),
          _navItem(Icons.local_shipping, 'Suppliers', AppView.suppliers, compact: true),
          _navItem(Icons.inventory, 'Inventory', AppView.inventory, compact: true),
          const Divider(height: 1),
          _navItem(Icons.settings, 'Settings', AppView.settings),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, AppView view, {bool compact = false}) {
    final active = currentView == view;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: 2),
      child: InkWell(
        onTap: () => onViewChanged(view),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? Colors.white : AppTheme.textMuted, size: compact ? 18 : 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                color: active ? Colors.white : AppTheme.textMuted,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w500,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppTheme.textMain)),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(children: [
                Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                SizedBox(width: 8),
                Text('Search...', style: TextStyle(color: AppTheme.textMuted)),
              ]),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.notifications_outlined, color: AppTheme.textMuted),
            const SizedBox(width: 16),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary,
              child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
      ),
    );
  }
}
