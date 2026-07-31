import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/db_helper.dart';
import 'premium_config.dart';
import 'results_exporter.dart';

/// Owns premium entitlement, free-tier counters, and store purchases.
class EntitlementService extends ChangeNotifier {
  EntitlementService._();
  static final EntitlementService instance = EntitlementService._();

  static const _kPremium = 'entitlement_premium';
  static const _kScanMonth = 'scan_month_key';
  static const _kScanCount = 'scan_month_count';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _loaded = false;
  bool isPremium = false;
  bool storeAvailable = false;
  bool purchasePending = false;
  String? lastError;
  ProductDetails? premiumProduct;
  int scansUsedThisMonth = 0;
  String _monthKey = '';

  bool get isLoaded => _loaded;
  String get monthKey => _monthKey;
  int get scansRemaining =>
      isPremium ? 999999 : (PremiumConfig.freeScansPerMonth - scansUsedThisMonth).clamp(0, PremiumConfig.freeScansPerMonth);

  String? get premiumPriceLabel => premiumProduct?.price;

  Future<void> init() async {
    await _loadLocal();
    storeAvailable = await _iap.isAvailable();
    _purchaseSub?.cancel();
    if (storeAvailable) {
      _purchaseSub = _iap.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object e) {
          lastError = e.toString();
          purchasePending = false;
          notifyListeners();
        },
      );
      await _queryProducts();
      await restorePurchases(silent: true);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    isPremium = p.getBool(_kPremium) ?? false;
    _monthKey = DateFormat('yyyy-MM').format(DateTime.now());
    final storedMonth = p.getString(_kScanMonth);
    if (storedMonth != _monthKey) {
      scansUsedThisMonth = 0;
      await p.setString(_kScanMonth, _monthKey);
      await p.setInt(_kScanCount, 0);
    } else {
      scansUsedThisMonth = p.getInt(_kScanCount) ?? 0;
    }
  }

  Future<void> _setPremium(bool value) async {
    isPremium = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPremium, value);
    notifyListeners();
  }

  Future<void> _queryProducts() async {
    final response = await _iap.queryProductDetails({PremiumConfig.premiumProductId});
    if (response.error != null) {
      lastError = response.error!.message;
    }
    if (response.productDetails.isNotEmpty) {
      premiumProduct = response.productDetails.first;
    }
    notifyListeners();
  }

  Future<void> buyPremium() async {
    lastError = null;
    if (!storeAvailable) {
      lastError = 'Store is not available on this device.';
      notifyListeners();
      return;
    }
    if (premiumProduct == null) {
      await _queryProducts();
    }
    if (premiumProduct == null) {
      lastError =
          'Premium product not found. Create "${PremiumConfig.premiumProductId}" in Play Console / App Store Connect.';
      notifyListeners();
      return;
    }
    purchasePending = true;
    notifyListeners();
    final param = PurchaseParam(productDetails: premiumProduct!);
    final started = await _iap.buyNonConsumable(purchaseParam: param);
    if (!started) {
      purchasePending = false;
      lastError = 'Could not start purchase.';
      notifyListeners();
    }
  }

  Future<void> restorePurchases({bool silent = false}) async {
    lastError = null;
    if (!storeAvailable) {
      if (!silent) {
        lastError = 'Store is not available on this device.';
        notifyListeners();
      }
      return;
    }
    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (!silent) {
        lastError = e.toString();
        notifyListeners();
      }
    }
  }

  /// Debug / TestFlight helper when store products are not set up yet.
  Future<void> debugUnlockPremium() async {
    if (!kDebugMode) return;
    await _setPremium(true);
  }

  Future<void> debugLockPremium() async {
    if (!kDebugMode) return;
    await _setPremium(false);
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != PremiumConfig.premiumProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          purchasePending = true;
          notifyListeners();
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _setPremium(true);
          purchasePending = false;
          lastError = null;
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          notifyListeners();
        case PurchaseStatus.error:
          purchasePending = false;
          lastError = purchase.error?.message ?? 'Purchase failed';
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          notifyListeners();
        case PurchaseStatus.canceled:
          purchasePending = false;
          notifyListeners();
      }
    }
  }

  // ---- Gates ----

  Future<bool> canCreateExam() async {
    if (isPremium) return true;
    final exams = await DBHelper.instance.getExams();
    return exams.length < PremiumConfig.freeExamLimit;
  }

  Future<bool> canScanSheet() async {
    await _loadLocal(); // refresh month rollover
    if (isPremium) return true;
    return scansUsedThisMonth < PremiumConfig.freeScansPerMonth;
  }

  bool canUseExamSettings() => isPremium;

  bool canExport(ExportFormat format) {
    if (isPremium) return true;
    return format == ExportFormat.csv;
  }

  Future<void> recordSuccessfulScan() async {
    if (isPremium) return;
    await _loadLocal();
    scansUsedThisMonth += 1;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kScanMonth, _monthKey);
    await p.setInt(_kScanCount, scansUsedThisMonth);
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
