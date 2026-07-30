import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restropos/core/l10n/translations.dart';
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
import 'package:restropos/core/remote_access/screens/remote_access_screen.dart';

enum AppView { dashboard, menu, history, wallet, invoice, categories, customers, suppliers, inventory, settings, remoteAccess }

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
          _Sidebar(
            currentView: view,
            onViewChanged: (v) => ref.read(appViewProvider.notifier).state = v,
            labelDashboard: ref.t('dashboard'),
            labelMenu: ref.t('menu'),
            labelHistory: ref.t('history'),
            labelWallet: ref.t('wallet'),
            labelInvoice: ref.t('invoice'),
            labelSettings: ref.t('settings'),
            labelRemoteAccess: ref.t('remoteAccess'),
          ),
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
          if (view == AppView.menu) BillingPanel(key: ValueKey(ref.watch(localeProvider))),
        ],
        ),
      ),
    );
  }

  String _titleFor(AppView view) {
    const keys = {
      AppView.dashboard: 'dashboard',
      AppView.menu: 'menu',
      AppView.history: 'history',
      AppView.wallet: 'wallet',
      AppView.invoice: 'invoiceSettings',
      AppView.categories: 'categories',
      AppView.customers: 'customers',
      AppView.suppliers: 'suppliers',
      AppView.inventory: 'inventory',
      AppView.settings: 'settings',
      AppView.remoteAccess: 'remoteAccess',
    };
    return ref.t(keys[view]!);
  }

  Widget _buildContent(AppView view, BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    switch (view) {
      case AppView.dashboard: return DashboardScreen(key: ValueKey(locale));
      case AppView.menu: return PosScreen(key: ValueKey(locale));
      case AppView.history: return SalesHistoryScreen(key: ValueKey(locale));
      case AppView.wallet: return WalletScreen(key: ValueKey(locale));
      case AppView.invoice: return InvoiceScreen(key: ValueKey(locale));
      case AppView.categories: return CategoriesScreen(key: ValueKey(locale));
      case AppView.customers: return CustomersScreen(key: ValueKey(locale));
      case AppView.suppliers: return SuppliersScreen(key: ValueKey(locale));
      case AppView.inventory: return InventoryScreen(key: ValueKey(locale));
      case AppView.settings: return SettingsScreen(key: ValueKey(locale));
      case AppView.remoteAccess: return RemoteAccessScreen(key: ValueKey(locale));
    }
  }
}

class _Sidebar extends StatelessWidget {
  final AppView currentView;
  final ValueChanged<AppView> onViewChanged;
  final String labelDashboard;
  final String labelMenu;
  final String labelHistory;
  final String labelWallet;
  final String labelInvoice;
  final String labelSettings;
  final String labelRemoteAccess;

  const _Sidebar({
    required this.currentView,
    required this.onViewChanged,
    required this.labelDashboard,
    required this.labelMenu,
    required this.labelHistory,
    required this.labelWallet,
    required this.labelInvoice,
    required this.labelSettings,
    required this.labelRemoteAccess,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      width: 120,
      child: Material(
        color: AppTheme.cardBg,
        borderRadius: rtl
            ? const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24))
            : const BorderRadius.only(topRight: Radius.circular(24), bottomRight: Radius.circular(24)),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/Logo.png', width: 48, height: 48, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _navItem(Icons.dashboard, labelDashboard, AppView.dashboard),
                    const SizedBox(height: 6),
                    _navItem(Icons.menu_book, labelMenu, AppView.menu),
                    const SizedBox(height: 6),
                    _navItem(Icons.history, labelHistory, AppView.history),
                    const SizedBox(height: 6),
                    _navItem(Icons.account_balance_wallet, labelWallet, AppView.wallet),
                    const SizedBox(height: 6),
                    _navItem(Icons.receipt, labelInvoice, AppView.invoice),
                    const SizedBox(height: 6),
                    _navItem(Icons.settings, labelSettings, AppView.settings),
                    const SizedBox(height: 6),
                    _navItem(Icons.cloud, labelRemoteAccess, AppView.remoteAccess),
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
            ref.invalidate(updateCheckProvider);
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
