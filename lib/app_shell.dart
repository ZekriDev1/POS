import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/services/update/update_providers.dart';
import 'package:restropos/core/services/update/update_service.dart';
import 'package:restropos/core/utils/app_theme.dart';
import 'package:restropos/features/settings/widgets/dev_menu.dart';
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
import 'package:restropos/features/settings/widgets/update_dialog.dart';

enum AppView { dashboard, menu, history, wallet, invoice, categories, customers, suppliers, inventory, settings }

final appViewProvider = StateProvider<AppView>((ref) => AppView.dashboard);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final pressed = HardwareKeyboard.instance.logicalKeysPressed;
      final isCtrl = pressed.contains(LogicalKeyboardKey.controlLeft) || pressed.contains(LogicalKeyboardKey.controlRight);
      final isShift = pressed.contains(LogicalKeyboardKey.shiftLeft) || pressed.contains(LogicalKeyboardKey.shiftRight);
      final isAlt = pressed.contains(LogicalKeyboardKey.altLeft) || pressed.contains(LogicalKeyboardKey.altRight);
      if (isCtrl && isShift && isAlt && event.logicalKey == LogicalKeyboardKey.keyZ) {
        showDialog(context: context, builder: (_) => const DevMenu());
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(appViewProvider);
    return Material(
      color: AppTheme.bgColor,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Row(
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
        ),
      ),
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
    return SizedBox(
      width: 120,
      child: Material(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24)),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.point_of_sale, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _navItem(Icons.dashboard, 'Dashboard', AppView.dashboard),
                    const SizedBox(height: 6),
                    _navItem(Icons.menu_book, 'Menu', AppView.menu),
                    const SizedBox(height: 6),
                    _navItem(Icons.history, 'History', AppView.history),
                    const SizedBox(height: 6),
                    _navItem(Icons.account_balance_wallet, 'Wallet', AppView.wallet),
                    const SizedBox(height: 6),
                    _navItem(Icons.receipt, 'Invoice', AppView.invoice),
                    const SizedBox(height: 6),
                    _navItem(Icons.settings, 'Settings', AppView.settings),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, AppView view, {bool compact = false}) {
    final active = currentView == view;
    return InkWell(
      onTap: () => onViewChanged(view),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: compact ? 10 : 14),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
    );
  }
}

class _UpdateIcon extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateStateProvider);
    final hasUpdate = state.status == UpdateStatus.updateAvailable;
    final isChecking = state.status == UpdateStatus.checking;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (hasUpdate) {
            final service = ref.read(updateServiceProvider);
            final release = state.release;
            if (release == null) return;
            showUpdateDialog(
              context,
              currentVersion: state.currentVersion ?? '--',
              release: release,
              onUpdateNow: () async {
                final filePath = await service.downloadUpdate(
                  release: release,
                  onProgress: (_) {},
                );
                await service.installUpdate(filePath);
              },
              onSkip: () => service.skipVersion(release.version),
              onNeverAsk: () => service.neverAskAgain(),
            );
          } else {
            ref.read(updateStateProvider.notifier).state = const UpdateState(status: UpdateStatus.checking);
            ref.refresh(updateCheckProvider);
          }
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            isChecking
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                : const Icon(Icons.notifications_outlined, color: AppTheme.textMuted),
            if (hasUpdate)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
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
          _UpdateIcon(),
        ],
      ),
    );
  }
}
