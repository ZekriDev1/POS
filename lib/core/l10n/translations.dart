import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en'));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('locale') ?? 'en';
    state = Locale(code);
  }

  Future<void> setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', code);
    state = Locale(code);
  }

  bool get isRtl => state.languageCode == 'ar';
}

extension TranslateX on BuildContext {
  String t(String key, [Map<String, String>? params]) {
    String code;
    try {
      code = ProviderScope.containerOf(this).read(localeProvider).languageCode;
    } catch (_) {
      code = Localizations.localeOf(this).languageCode;
    }
    return Translations.get(key, code, params);
  }
}

extension TranslateXWidgetRef on WidgetRef {
  String t(String key, [Map<String, String>? params]) {
    final locale = watch(localeProvider);
    return Translations.get(key, locale.languageCode, params);
  }
}

class Translations {
  Translations._();

  static const _all = <String, Map<String, String>>{
    // ── App ──
    'appTitle': {'en': 'CashManager', 'ar': 'كاش مانجير', 'fr': 'CashManager'},

    // ── Sidebar / Navigation ──
    'dashboard': {'en': 'Dashboard', 'ar': 'لوحة التحكم', 'fr': 'Tableau de bord'},
    'menu': {'en': 'Menu', 'ar': 'القائمة', 'fr': 'Menu'},
    'history': {'en': 'History', 'ar': 'السجل', 'fr': 'Historique'},
    'wallet': {'en': 'Wallet', 'ar': 'المحفظة', 'fr': 'Portefeuille'},
    'invoice': {'en': 'Invoice', 'ar': 'الفواتير', 'fr': 'Facture'},
    'invoiceSettings': {'en': 'Invoice Settings', 'ar': 'إعدادات الفاتورة', 'fr': 'Paramètres de facture'},
    'categories': {'en': 'Categories', 'ar': 'التصنيفات', 'fr': 'Catégories'},
    'customers': {'en': 'Customers', 'ar': 'العملاء', 'fr': 'Clients'},
    'suppliers': {'en': 'Suppliers', 'ar': 'الموردين', 'fr': 'Fournisseurs'},
    'inventory': {'en': 'Inventory', 'ar': 'المخزون', 'fr': 'Inventaire'},
    'settings': {'en': 'Settings', 'ar': 'الإعدادات', 'fr': 'Paramètres'},

    // ── POS / Menu ──
    'searchHint': {'en': 'Search category or product...', 'ar': 'البحث عن فئة أو منتج...', 'fr': 'Rechercher une catégorie ou un produit...'},
    'all': {'en': 'All', 'ar': 'الكل', 'fr': 'Tout'},
    'addProduct': {'en': 'Add Product', 'ar': 'إضافة منتج', 'fr': 'Ajouter un produit'},
    'deleteProduct': {'en': 'Delete Product', 'ar': 'حذف المنتج', 'fr': 'Supprimer produit'},
    'deleteProductConfirm': {'en': 'Are you sure you want to delete "{name}"?', 'ar': 'هل أنت متأكد من حذف "{name}"؟', 'fr': 'Voulez-vous vraiment supprimer "{name}" ?'},
    'cancel': {'en': 'Cancel', 'ar': 'إلغاء', 'fr': 'Annuler'},
    'delete': {'en': 'Delete', 'ar': 'حذف', 'fr': 'Supprimer'},
    'addToBilling': {'en': 'Add to Billing', 'ar': 'أضف إلى الفاتورة', 'fr': 'Ajouter à la facturation'},
    'editProduct': {'en': 'Edit Product', 'ar': 'تعديل المنتج', 'fr': 'Modifier produit'},

    // ── Billing Panel ──
    'bills': {'en': 'Bills', 'ar': 'الفواتير', 'fr': 'Factures'},
    'cartEmpty': {'en': 'Cart is empty', 'ar': 'السلة فارغة', 'fr': 'Le panier est vide'},
    'subtotal': {'en': 'Subtotal', 'ar': 'المجموع الفرعي', 'fr': 'Sous-total'},
    'paymentMethod': {'en': 'Payment Method', 'ar': 'طريقة الدفع', 'fr': 'Moyen de paiement'},
    'cash': {'en': 'Cash', 'ar': 'نقداً', 'fr': 'Espèces'},
    'card': {'en': 'Card', 'ar': 'بطاقة', 'fr': 'Carte'},
    'total': {'en': 'Total', 'ar': 'المجموع', 'fr': 'Total'},
    'printBill': {'en': 'PRINT BILL', 'ar': 'طباعة الفاتورة', 'fr': 'IMPRIMER FACTURE'},
    'receiptPreview': {'en': 'Receipt Preview', 'ar': 'معاينة الإيصال', 'fr': 'Aperçu du reçu'},
    'close': {'en': 'Close', 'ar': 'إغلاق', 'fr': 'Fermer'},
    'print': {'en': 'Print', 'ar': 'طباعة', 'fr': 'Imprimer'},

    // ── Sales History ──
    'noOrders': {'en': 'No orders yet', 'ar': 'لا توجد طلبات بعد', 'fr': 'Aucune commande'},
    'deleteSale': {'en': 'Delete Sale', 'ar': 'حذف البيع', 'fr': 'Supprimer vente'},
    'deleteSaleConfirm': {'en': 'Delete sale #{number}? This cannot be undone.', 'ar': 'حذف البيع #{number}؟ لا يمكن التراجع عن هذا.', 'fr': 'Supprimer vente #{number} ? Cette action est irréversible.'},

    // ── Settings ──
    'storeName': {'en': 'Store Name', 'ar': 'اسم المتجر', 'fr': 'Nom du magasin'},
    'currencySymbol': {'en': 'Currency Symbol', 'ar': 'رمز العملة', 'fr': 'Symbole monétaire'},
    'cashierName': {'en': 'Cashier Name', 'ar': 'اسم البائع', 'fr': 'Nom du caissier'},
    'storeLogo': {'en': 'Store Logo', 'ar': 'شعار المتجر', 'fr': 'Logo du magasin'},
    'saveSettings': {'en': 'Save Settings', 'ar': 'حفظ الإعدادات', 'fr': 'Enregistrer'},
    'settingsSaved': {'en': 'Settings saved', 'ar': 'تم حفظ الإعدادات', 'fr': 'Paramètres enregistrés'},
    'backupRestore': {'en': 'Backup & Restore', 'ar': 'النسخ الاحتياطي والاستعادة', 'fr': 'Sauvegarde et restauration'},
    'backupDesc': {'en': 'Export all your data (products, sales, categories, etc.) to a single file, or restore from a previous backup.', 'ar': 'تصدير جميع بياناتك (المنتجات، المبيعات، التصنيفات، إلخ) إلى ملف واحد، أو الاستعادة من نسخة احتياطية سابقة.', 'fr': 'Exportez toutes vos données (produits, ventes, catégories, etc.) vers un seul fichier, ou restaurez à partir d\'une sauvegarde.'},
    'backup': {'en': 'Backup', 'ar': 'نسخ احتياطي', 'fr': 'Sauvegarder'},
    'backingUp': {'en': 'Backing up...', 'ar': 'جارٍ النسخ الاحتياطي...', 'fr': 'Sauvegarde...'},
    'restore': {'en': 'Restore', 'ar': 'استعادة', 'fr': 'Restaurer'},
    'restoring': {'en': 'Restoring...', 'ar': 'جارٍ الاستعادة...', 'fr': 'Restauration...'},
    'restoreData': {'en': 'Restore Data', 'ar': 'استعادة البيانات', 'fr': 'Restaurer données'},
    'restoreConfirm': {'en': 'This will replace ALL current data with the backup. This cannot be undone. Continue?', 'ar': 'سيتم استبدال جميع البيانات الحالية بالنسخة الاحتياطية. لا يمكن التراجع عن هذا. هل تريد المتابعة؟', 'fr': 'Cela remplacera TOUTES les données actuelles par la sauvegarde. Action irréversible. Continuer ?'},
    'backupSuccess': {'en': 'Backup saved to {path}', 'ar': 'تم حفظ النسخة الاحتياطية في {path}', 'fr': 'Sauvegarde enregistrée vers {path}'},
    'backupFailed': {'en': 'Backup failed: {error}', 'ar': 'فشل النسخ الاحتياطي: {error}', 'fr': 'Échec de la sauvegarde : {error}'},
    'restoreSuccess': {'en': 'Data restored successfully. Please restart the app.', 'ar': 'تمت استعادة البيانات بنجاح. يرجى إعادة تشغيل التطبيق.', 'fr': 'Données restaurées. Veuillez redémarrer l\'application.'},
    'restoreFailed': {'en': 'Restore failed: {error}', 'ar': 'فشلت الاستعادة: {error}', 'fr': 'Échec de la restauration : {error}'},
    'saveBackup': {'en': 'Save Database Backup', 'ar': 'حفظ نسخة احتياطية', 'fr': 'Sauvegarder la base de données'},
    'selectBackup': {'en': 'Select Backup File to Restore', 'ar': 'اختر ملف النسخ الاحتياطي للاستعادة', 'fr': 'Sélectionner le fichier de sauvegarde'},

    // ── Update ──
    'appUpdates': {'en': 'Application Updates', 'ar': 'تحديثات التطبيق', 'fr': 'Mises à jour'},
    'currentVersion': {'en': 'Current Version', 'ar': 'الإصدار الحالي', 'fr': 'Version actuelle'},
    'latestVersion': {'en': 'Latest Version', 'ar': 'آخر إصدار', 'fr': 'Dernière version'},
    'lastChecked': {'en': 'Last Checked', 'ar': 'آخر فحص', 'fr': 'Dernière vérification'},
    'autoCheck': {'en': 'Automatically check for updates', 'ar': 'التحقق التلقائي من التحديثات', 'fr': 'Vérifier automatiquement'},
    'autoCheckSub': {'en': 'Check for updates on app startup', 'ar': 'التحقق من التحديثات عند بدء التطبيق', 'fr': 'Vérifier au démarrage'},
    'checkUpdates': {'en': 'Check for Updates', 'ar': 'التحقق من التحديثات', 'fr': 'Vérifier mises à jour'},
    'checking': {'en': 'Checking...', 'ar': 'جارٍ الفحص...', 'fr': 'Vérification...'},
    'upToDate': {'en': 'Up to date', 'ar': 'آخر إصدار', 'fr': 'À jour'},
    'never': {'en': 'Never', 'ar': 'أبداً', 'fr': 'Jamais'},
    'newUpdate': {'en': 'New Update Available', 'ar': 'تحديث جديد متاح', 'fr': 'Nouvelle mise à jour'},
    'releaseDate': {'en': 'Release Date', 'ar': 'تاريخ الإصدار', 'fr': 'Date de sortie'},
    'fileSize': {'en': 'File Size', 'ar': 'حجم الملف', 'fr': 'Taille du fichier'},
    'releaseNotes': {'en': 'Release Notes', 'ar': 'ملاحظات الإصدار', 'fr': 'Notes de version'},
    'later': {'en': 'Later', 'ar': 'لاحقاً', 'fr': 'Plus tard'},
    'neverAsk': {'en': 'Never Ask Again', 'ar': 'لا تسأل مرة أخرى', 'fr': 'Ne plus demander'},
    'updateNow': {'en': 'Update Now', 'ar': 'تحديث الآن', 'fr': 'Mettre à jour'},
    'downloadComplete': {'en': 'Download Complete', 'ar': 'تم التحميل', 'fr': 'Téléchargement terminé'},
    'downloadingUpdate': {'en': 'Downloading Update...', 'ar': 'جارٍ تحميل التحديث...', 'fr': 'Téléchargement...'},
    'downloaded': {'en': 'Downloaded', 'ar': 'تم التحميل', 'fr': 'Téléchargé'},
    'speed': {'en': 'Speed', 'ar': 'السرعة', 'fr': 'Vitesse'},
    'remaining': {'en': 'Remaining', 'ar': 'المتبقي', 'fr': 'Restant'},
    'eta': {'en': 'ETA', 'ar': 'الوقت المتبقي', 'fr': 'Estimation'},
    'startingDownload': {'en': 'Starting download...', 'ar': 'بدء التحميل...', 'fr': 'Démarrage...'},
    'downloadSuccess': {'en': 'Update downloaded successfully. Installing...', 'ar': 'تم تحميل التحديث بنجاح. جارٍ التثبيت...', 'fr': 'Mise à jour téléchargée. Installation...'},
    'downloadFailed': {'en': 'Download Failed', 'ar': 'فشل التحميل', 'fr': 'Échec du téléchargement'},
    'downloadError': {'en': 'An unexpected error occurred', 'ar': 'حدث خطأ غير متوقع', 'fr': 'Erreur inattendue'},
    'upToDateSnack': {'en': 'You have the latest version', 'ar': 'لديك أحدث إصدار', 'fr': 'Vous avez la dernière version'},
    'updateCheckFailed': {'en': 'Update check failed', 'ar': 'فشل التحقق من التحديث', 'fr': 'Vérification échouée'},
    'updateRestarting': {'en': 'Update downloaded successfully. Restarting...', 'ar': 'تم تحميل التحديث. جارٍ إعادة التشغيل...', 'fr': 'Mise à jour téléchargée. Redémarrage...'},

    // ── Invoice Settings ──
    'companyName': {'en': 'Company / Store Name', 'ar': 'اسم الشركة / المتجر', 'fr': 'Nom entreprise / magasin'},
    'phone': {'en': 'Phone', 'ar': 'الهاتف', 'fr': 'Téléphone'},
    'tvaNumber': {'en': 'TVA Number', 'ar': 'رقم الضريبة', 'fr': 'Numéro TVA'},
    'address': {'en': 'Address', 'ar': 'العنوان', 'fr': 'Adresse'},
    'tvaRate': {'en': 'TVA Rate (%)', 'ar': 'نسبة الضريبة (%)', 'fr': 'Taux TVA (%)'},
    'footer': {'en': 'Footer', 'ar': 'التذييل', 'fr': 'Pied de page'},
    'showTva': {'en': 'Show TVA on invoice', 'ar': 'إظهار الضريبة في الفاتورة', 'fr': 'Afficher la TVA'},
    'saveInvoice': {'en': 'Save Invoice Settings', 'ar': 'حفظ إعدادات الفاتورة', 'fr': 'Enregistrer facture'},
    'invoiceSaved': {'en': 'Invoice settings saved', 'ar': 'تم حفظ إعدادات الفاتورة', 'fr': 'Paramètres facture enregistrés'},

    // ── Receipt Widget ──
    'receiptDate': {'en': 'Date: {value}', 'ar': ':التاريخ {value}', 'fr': 'Date : {value}'},
    'receiptTime': {'en': 'Time: {value}', 'ar': ':الساعة {value}', 'fr': 'Heure : {value}'},
    'receiptOrder': {'en': 'Order No: {value}', 'ar': ':رقم الطلب {value}', 'fr': 'N° commande : {value}'},
    'receiptCashier': {'en': 'Cashier: {value}', 'ar': ':البائع {value}', 'fr': 'Caissier : {value}'},
    'receiptPayment': {'en': 'Payment: {value}', 'ar': ':طريقة الدفع {value}', 'fr': 'Paiement : {value}'},
    'colTotal': {'en': 'Total', 'ar': 'المجموع', 'fr': 'Total'},
    'colPrice': {'en': 'Price', 'ar': 'السعر', 'fr': 'Prix'},
    'colItem': {'en': 'Item', 'ar': 'السلعة', 'fr': 'Article'},
    'colUnit': {'en': 'Unit', 'ar': 'الوحدة', 'fr': 'Unité'},
    'colQty': {'en': 'Qty', 'ar': 'الكمية', 'fr': 'Qté'},
    'noItems': {'en': '(No items)', 'ar': '(لا توجد عناصر)', 'fr': '(Aucun article)'},
    'subtotalHt': {'en': 'Amount before tax (HT)', 'ar': 'المبلغ قبل الضريبة (HT)', 'fr': 'Montant HT'},
    'taxLabel': {'en': 'Tax ({rate}%)', 'ar': 'الضريبة ({rate}%)', 'fr': 'TVA ({rate}%)'},
    'totalTtc': {'en': 'Total (TTC)', 'ar': 'المجموع (TTC)', 'fr': 'Total TTC'},
    'tva': {'en': 'TVA: {number}', 'ar': 'TVA: {number}', 'fr': 'TVA : {number}'},
    'receiptCustomer': {'en': 'Customer', 'ar': 'العميل', 'fr': 'Client'},

    // ── Receipt meta labels (short) ──
    'cashLabel': {'en': 'Espèces', 'ar': 'نقداً', 'fr': 'Espèces'},
    'cardLabel': {'en': 'Carte', 'ar': 'بطاقة', 'fr': 'Carte'},
    'unitLabel': {'en': 'Unité', 'ar': 'وحدة', 'fr': 'Unité'},

    // ── Dashboard ──
    'totalProducts': {'en': 'Total Products', 'ar': 'إجمالي المنتجات', 'fr': 'Total produits'},
    'totalCategories': {'en': 'Categories', 'ar': 'الفئات', 'fr': 'Catégories'},
    'todaySales': {'en': "Today's Sales", 'ar': 'مبيعات اليوم', 'fr': 'Ventes du jour'},
    'totalOrders': {'en': 'Total Orders', 'ar': 'إجمالي الطلبات', 'fr': 'Total commandes'},
    'itemsSold': {'en': 'Items Sold', 'ar': 'العناصر المباعة', 'fr': 'Articles vendus'},
    'totalRevenue': {'en': 'Total Revenue', 'ar': 'إجمالي الإيرادات', 'fr': 'Revenu total'},
    'monthlyRevenue': {'en': 'Monthly Revenue', 'ar': 'الإيرادات الشهرية', 'fr': 'Revenu mensuel'},
    'lowStock': {'en': 'Low Stock Products', 'ar': 'المنتجات منخفضة المخزون', 'fr': 'Stock faible'},
    'recentOrders': {'en': 'Recent Orders', 'ar': 'أحدث الطلبات', 'fr': 'Commandes récentes'},
    'stockSufficient': {'en': 'All products have sufficient stock', 'ar': 'جميع المنتجات تحتوي على مخزون كافٍ', 'fr': 'Tous les produits ont un stock suffisant'},

    // ── Categories ──
    'addCategory': {'en': 'Add Category', 'ar': 'إضافة تصنيف', 'fr': 'Ajouter catégorie'},
    'noCategories': {'en': 'No categories yet', 'ar': 'لا توجد تصنيفات بعد', 'fr': 'Aucune catégorie'},
    'editCategory': {'en': 'Edit Category', 'ar': 'تعديل التصنيف', 'fr': 'Modifier catégorie'},
    'categoryName': {'en': 'Category name', 'ar': 'اسم التصنيف', 'fr': 'Nom catégorie'},
    'icon': {'en': 'Icon', 'ar': 'الأيقونة', 'fr': 'Icône'},
    'parentCategory': {'en': 'Parent Category', 'ar': 'التصنيف الرئيسي', 'fr': 'Catégorie parente'},
    'noneTop': {'en': 'None (top-level)', 'ar': 'بدون (مستوى رئيسي)', 'fr': 'Aucun (racine)'},
    'save': {'en': 'Save', 'ar': 'حفظ', 'fr': 'Enregistrer'},
    'deleteCategory': {'en': 'Delete Category', 'ar': 'حذف التصنيف', 'fr': 'Supprimer catégorie'},
    'deleteCategoryConfirm': {'en': 'Sub-categories will also be deleted. Continue?', 'ar': 'سيتم حذف التصنيفات الفرعية أيضاً. هل تريد المتابعة؟', 'fr': 'Les sous-catégories seront également supprimées. Continuer ?'},

    // ── Categories (POS dialogs) ──
    'add': {'en': 'Add', 'ar': 'إضافة', 'fr': 'Ajouter'},
    'saveChanges': {'en': 'Save Changes', 'ar': 'حفظ التغييرات', 'fr': 'Enregistrer les modifications'},
    'newSubCategory': {'en': 'New Sub-Category', 'ar': 'تصنيف فرعي جديد', 'fr': 'Nouvelle sous-catégorie'},
    'subCategoryName': {'en': 'Sub-category name', 'ar': 'اسم التصنيف الفرعي', 'fr': 'Nom de la sous-catégorie'},
    'renameSubCategory': {'en': 'Rename Sub-Category', 'ar': 'إعادة تسمية التصنيف الفرعي', 'fr': 'Renommer la sous-catégorie'},
    'deleteCategoryMsg': {'en': 'Delete "{name}"?', 'ar': 'حذف "{name}"؟', 'fr': 'Supprimer "{name}" ?'},
    'uncategorizeWarning': {'en': 'Products in this category will become uncategorized.', 'ar': 'ستصبح المنتجات في هذا التصنيف غير مصنفة.', 'fr': 'Les produits de cette catégorie deviendront non catégorisés.'},
    'subCatDeletedOne': {'en': '{count} sub-category will also be deleted.', 'ar': 'سيتم حذف تصنيف فرعي واحد أيضاً.', 'fr': '{count} sous-catégorie sera également supprimée.'},
    'subCatsDeletedMany': {'en': '{count} sub-categories will also be deleted.', 'ar': 'سيتم حذف {count} تصنيفات فرعية أيضاً.', 'fr': '{count} sous-catégories seront également supprimées.'},

    // ── Remote Access Users ──
    'users': {'en': 'Users', 'ar': 'المستخدمون', 'fr': 'Utilisateurs'},
    'addUser': {'en': 'Add User', 'ar': 'إضافة مستخدم', 'fr': 'Ajouter un utilisateur'},
    'createUser': {'en': 'Create User', 'ar': 'إنشاء مستخدم', 'fr': 'Créer un utilisateur'},
    'editUser': {'en': 'Edit User', 'ar': 'تعديل المستخدم', 'fr': 'Modifier l\'utilisateur'},
    'username': {'en': 'Username', 'ar': 'اسم المستخدم', 'fr': 'Nom d\'utilisateur'},
    'password': {'en': 'Password', 'ar': 'كلمة المرور', 'fr': 'Mot de passe'},
    'newPasswordKeep': {'en': 'New Password (leave blank to keep)', 'ar': 'كلمة مرور جديدة (اتركها فارغة للإبقاء)', 'fr': 'Nouveau mot de passe (laisser vide pour conserver)'},
    'role': {'en': 'Role', 'ar': 'الدور', 'fr': 'Rôle'},
    'create': {'en': 'Create', 'ar': 'إنشاء', 'fr': 'Créer'},
    'noUsers': {'en': 'No users created yet', 'ar': 'لا يوجد مستخدمون بعد', 'fr': 'Aucun utilisateur créé'},
    'disabledBadge': {'en': '(disabled)', 'ar': '(معطل)', 'fr': '(désactivé)'},
    'createdOn': {'en': 'Created {date}', 'ar': 'تاريخ الإنشاء {date}', 'fr': 'Créé {date}'},
    'edit': {'en': 'Edit', 'ar': 'تعديل', 'fr': 'Modifier'},
    'deleteUser': {'en': 'Delete User', 'ar': 'حذف المستخدم', 'fr': 'Supprimer l\'utilisateur'},
    'deleteUserConfirm': {'en': 'Delete user "{name}"?', 'ar': 'حذف المستخدم "{name}"؟', 'fr': 'Supprimer l\'utilisateur "{name}" ?'},

    // ── Product Form ──
    'productName': {'en': 'Product Name', 'ar': 'اسم المنتج', 'fr': 'Nom produit'},
    'barcode': {'en': 'Barcode', 'ar': 'الباركود', 'fr': 'Code-barres'},
    'description': {'en': 'Description', 'ar': 'الوصف', 'fr': 'Description'},
    'costPrice': {'en': 'Cost Price', 'ar': 'سعر التكلفة', 'fr': 'Prix d\'achat'},
    'sellingPrice': {'en': 'Selling Price', 'ar': 'سعر البيع', 'fr': 'Prix de vente'},
    'quantity': {'en': 'Quantity', 'ar': 'الكمية', 'fr': 'Quantité'},
    'category': {'en': 'Category', 'ar': 'التصنيف', 'fr': 'Catégorie'},
    'newCategory': {'en': 'New', 'ar': 'جديد', 'fr': 'Nouveau'},
    'image': {'en': 'Image', 'ar': 'الصورة', 'fr': 'Image'},
    'required': {'en': 'Required', 'ar': 'مطلوب', 'fr': 'Requis'},
    'updateProduct': {'en': 'Update Product', 'ar': 'تحديث المنتج', 'fr': 'Modifier produit'},
    'saveProduct': {'en': 'Save Product', 'ar': 'حفظ المنتج', 'fr': 'Enregistrer produit'},

    // ── Customers ──
    'addCustomer': {'en': 'Add Customer', 'ar': 'إضافة عميل', 'fr': 'Ajouter client'},
    'noCustomers': {'en': 'No customers yet', 'ar': 'لا يوجد عملاء بعد', 'fr': 'Aucun client'},
    'name': {'en': 'Name', 'ar': 'الاسم', 'fr': 'Nom'},
    'email': {'en': 'Email', 'ar': 'البريد الإلكتروني', 'fr': 'Email'},

    // ── Suppliers ──
    'addSupplier': {'en': 'Add Supplier', 'ar': 'إضافة مورد', 'fr': 'Ajouter fournisseur'},
    'noSuppliers': {'en': 'No suppliers yet', 'ar': 'لا يوجد موردين بعد', 'fr': 'Aucun fournisseur'},

    // ── Inventory ──
    'allProductsStock': {'en': 'All Products Stock', 'ar': 'مخزون جميع المنتجات', 'fr': 'Stock tous produits'},
    'noProducts': {'en': 'No products yet', 'ar': 'لا توجد منتجات بعد', 'fr': 'Aucun produit'},
    'stock': {'en': 'Stock: {value}', 'ar': 'المخزون: {value}', 'fr': 'Stock : {value}'},

    // ── Wallet ──
    'recentTransactions': {'en': 'Recent Transactions', 'ar': 'المعاملات الأخيرة', 'fr': 'Transactions récentes'},
    'noTransactions': {'en': 'No transactions yet', 'ar': 'لا توجد معاملات بعد', 'fr': 'Aucune transaction'},

    // ── Activation ──
    'activateLicense': {'en': 'Activate your license to continue', 'ar': 'قم بتفعيل الترخيص للمتابعة', 'fr': 'Activez votre licence pour continuer'},
    'enterKey': {'en': 'Enter activation key', 'ar': 'أدخل مفتاح التفعيل', 'fr': 'Entrez la clé d\'activation'},
    'pleaseEnterKey': {'en': 'Please enter an activation key', 'ar': 'يرجى إدخال مفتاح التفعيل', 'fr': 'Veuillez entrer une clé'},
    'activate': {'en': 'Activate', 'ar': 'تفعيل', 'fr': 'Activer'},
    'activationSuccess': {'en': 'Activation Successful', 'ar': 'تم التفعيل بنجاح', 'fr': 'Activation réussie'},
    'activationSuccessMsg': {'en': 'Thanks for purchasing the product.\n\nPlease close the app and re-open it to start using CashManager.', 'ar': 'شكراً لشرائك المنتج.\n\nيرجى إغلاق التطبيق وإعادة فتحه لبدء استخدام كاش مانجير.', 'fr': 'Merci d\'avoir acheté le produit.\n\nVeuillez fermer l\'application et la rouvrir pour utiliser CashManager.'},
    'closeReopen': {'en': 'Close & Reopen', 'ar': 'إغلاق وإعادة فتح', 'fr': 'Fermer et rouvrir'},
    'licenseInUse': {'en': 'License Already In Use', 'ar': 'الترخيص قيد الاستخدام بالفعل', 'fr': 'Licence déjà utilisée'},
    'licenseInUseMsg': {'en': 'This license is already activated on another device.\n\nTo transfer the license to this device, please contact support:\n+212 6 91 15 73 63', 'ar': 'هذا الترخيص مفعل بالفعل على جهاز آخر.\n\nلنقل الترخيص إلى هذا الجهاز، يرجى الاتصال بالدعم:\n+212 6 91 15 73 63', 'fr': 'Cette licence est déjà activée sur un autre appareil.\n\nPour transférer la licence, veuillez contacter le support :\n+212 6 91 15 73 63'},
    'activationFailed': {'en': 'Activation Failed', 'ar': 'فشل التفعيل', 'fr': 'Échec d\'activation'},
    'activationFailedMsg': {'en': 'You need to buy a license.\nPlease contact the support team:\n+212 6 91 15 73 63', 'ar': 'تحتاج إلى شراء ترخيص.\nيرجى الاتصال بفريق الدعم:\n+212 6 91 15 73 63', 'fr': 'Vous devez acheter une licence.\nVeuillez contacter le support :\n+212 6 91 15 73 63'},
    'ok': {'en': 'OK', 'ar': 'حسناً', 'fr': 'OK'},

    // ── Language Selection (first launch) ──
    'selectLanguage': {'en': 'Select Language', 'ar': 'اختر اللغة', 'fr': 'Choisir la langue'},
    'languageSubtitle': {'en': 'Choose your preferred language', 'ar': 'اختر لغتك المفضلة', 'fr': 'Choisissez votre langue préférée'},
    'english': {'en': 'English', 'ar': 'الإنجليزية', 'fr': 'Anglais'},
    'arabic': {'en': 'Arabic', 'ar': 'العربية', 'fr': 'Arabe'},
    'french': {'en': 'French', 'ar': 'الفرنسية', 'fr': 'Français'},
    'continue': {'en': 'Continue', 'ar': 'متابعة', 'fr': 'Continuer'},

    // ── Developer Menu ──
    'devMenu': {'en': 'Developer Menu', 'ar': 'قائمة المطور', 'fr': 'Menu développeur'},
    'generateLicense': {'en': 'Generate License', 'ar': 'إنشاء ترخيص', 'fr': 'Générer licence'},
    'dbStats': {'en': 'DB Stats', 'ar': 'إحصائيات قاعدة البيانات', 'fr': 'Stats BDD'},
    'signOut': {'en': 'Sign Out', 'ar': 'تسجيل الخروج', 'fr': 'Déconnexion'},
    'licenseCheck': {'en': 'License key to check...', 'ar': 'مفتاح الترخيص للتحقق...', 'fr': 'Clé de licence à vérifier...'},
    'check': {'en': 'Check', 'ar': 'تحقق', 'fr': 'Vérifier'},
    'outputHere': {'en': 'Output will appear here...', 'ar': 'سيظهر الناتج هنا...', 'fr': 'Le résultat apparaîtra ici...'},
    'signOutTitle': {'en': 'Sign Out', 'ar': 'تسجيل الخروج', 'fr': 'Déconnexion'},
    'signOutConfirm': {'en': 'This will deactivate the license on this device. Continue?', 'ar': 'سيتم إلغاء تنشيط الترخيص على هذا الجهاز. هل تريد المتابعة؟', 'fr': 'Cela désactivera la licence sur cet appareil. Continuer ?'},

    // ── Update error messages ──
    'noInternet': {'en': 'No internet connection. Please check your network.', 'ar': 'لا يوجد اتصال بالإنترنت. يرجى التحقق من شبكتك.', 'fr': 'Pas de connexion Internet. Vérifiez votre réseau.'},
    'noGitHub': {'en': 'Could not reach GitHub. Try again later.', 'ar': 'لا يمكن الوصول إلى GitHub. حاول مرة أخرى لاحقاً.', 'fr': 'Impossible de joindre GitHub. Réessayez plus tard.'},
    'updateError': {'en': 'Update check failed: {error}', 'ar': 'فشل التحقق من التحديث: {error}', 'fr': 'Échec de vérification : {error}'},

    // ── Remote Access ──
    'remoteAccess': {'en': 'Remote Access', 'ar': 'الوصول عن بُعد', 'fr': 'Accès à distance'},
    'tunnelStatus': {'en': 'Tunnel Status', 'ar': 'حالة النفق', 'fr': 'Statut du tunnel'},
    'httpServer': {'en': 'HTTP Server', 'ar': 'خادم HTTP', 'fr': 'Serveur HTTP'},
    'running': {'en': 'Running', 'ar': 'قيد التشغيل', 'fr': 'En cours'},
    'stopped': {'en': 'Stopped', 'ar': 'متوقف', 'fr': 'Arrêté'},
    'connectionDetails': {'en': 'Connection Details', 'ar': 'تفاصيل الاتصال', 'fr': 'Détails de connexion'},
    'localIp': {'en': 'Local IP', 'ar': 'IP المحلي', 'fr': 'IP locale'},
    'localPort': {'en': 'Local Port', 'ar': 'المنفذ المحلي', 'fr': 'Port local'},
    'publicUrl': {'en': 'Public URL', 'ar': 'الرابط العام', 'fr': 'URL publique'},
    'copyUrl': {'en': 'Copy URL', 'ar': 'نسخ الرابط', 'fr': 'Copier URL'},
    'openUrl': {'en': 'Open URL', 'ar': 'فتح الرابط', 'fr': 'Ouvrir URL'},
    'refreshUrl': {'en': 'Refresh URL', 'ar': 'تحديث الرابط', 'fr': 'Rafraîchir URL'},
    'qrCode': {'en': 'QR Code', 'ar': 'رمز QR', 'fr': 'Code QR'},
    'scanToAccess': {'en': 'Scan to access from your phone', 'ar': 'امسح ضوئياً للوصول من هاتفك', 'fr': 'Scannez pour accéder depuis votre téléphone'},
    'connectedDevices': {'en': 'Connected Devices', 'ar': 'الأجهزة المتصلة', 'fr': 'Appareils connectés'},
    'active': {'en': 'Active', 'ar': 'نشط', 'fr': 'Actif'},
    'noActiveSessions': {'en': 'No active sessions', 'ar': 'لا توجد جلسات نشطة', 'fr': 'Aucune session active'},
    'disconnect': {'en': 'Disconnect', 'ar': 'قطع الاتصال', 'fr': 'Déconnecter'},
    'actions': {'en': 'Actions', 'ar': 'الإجراءات', 'fr': 'Actions'},
    'restartTunnel': {'en': 'Restart Tunnel', 'ar': 'إعادة تشغيل النفق', 'fr': 'Redémarrer le tunnel'},
    'stopRemoteAccess': {'en': 'Stop Remote Access', 'ar': 'إيقاف الوصول عن بُعد', 'fr': 'Arrêter l\'accès à distance'},
    'lastConnection': {'en': 'Last Connection', 'ar': 'آخر اتصال', 'fr': 'Dernière connexion'},
  };

  static String get(String key, String locale, [Map<String, String>? params]) {
    final translations = _all[key];
    if (translations == null) return key;
    var text = translations[locale] ?? translations['en'] ?? key;
    if (params != null) {
      for (final entry in params.entries) {
        text = text.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return text;
  }
}
