import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mysme/core/providers/http_client.dart';

// ---------------------------------------------------------------------------
// Product IDs — must match App Store Connect & Google Play Console
// ---------------------------------------------------------------------------
const kPremiumMonthlyId = 'mystme_premium_monthly';
const kUnlockSingleId = 'mystme_unlock_single';
const _kProductIds = <String>{kPremiumMonthlyId, kUnlockSingleId};

// ---------------------------------------------------------------------------
// IAP Service
// ---------------------------------------------------------------------------

class IapService {
  IapService(this._client);
  final HttpClient _client;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _statusController = StreamController<bool>.broadcast();

  /// Emits true/false whenever premium status changes.
  Stream<bool> get premiumStream => _statusController.stream;

  bool _available = false;
  Map<String, ProductDetails> products = {};

  /// Pending conversation ID for single-unlock flow.
  String? _pendingUnlockConversationId;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      debugPrint('[IapService] Store not available');
      return;
    }

    // Load product details.
    final response = await _iap.queryProductDetails(_kProductIds);
    if (response.error != null) {
      debugPrint('[IapService] queryProductDetails error: ${response.error}');
    }
    for (final p in response.productDetails) {
      products[p.id] = p;
    }

    // Listen to purchase updates.
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => debugPrint('[IapService] purchaseStream error: $e'),
    );
  }

  void dispose() {
    _sub?.cancel();
    _statusController.close();
  }

  // ------------------------------------------------------------------
  // Purchase triggers
  // ------------------------------------------------------------------

  /// Buy the monthly premium subscription.
  Future<bool> buyPremium() async {
    final product = products[kPremiumMonthlyId];
    if (product == null) return false;
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Buy a single-conversation unlock (consumable).
  Future<bool> buyUnlock(String conversationId) async {
    final product = products[kUnlockSingleId];
    if (product == null) return false;
    _pendingUnlockConversationId = conversationId;
    final param = PurchaseParam(productDetails: product);
    return _iap.buyConsumable(purchaseParam: param);
  }

  // ------------------------------------------------------------------
  // Status checks
  // ------------------------------------------------------------------

  /// Ask the backend whether the current user has premium.
  Future<bool> checkPremium() async {
    try {
      final json = await _client.get('/subscription/status');
      return (json as Map<String, dynamic>)['premium'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Ask the backend whether a conversation is unlocked.
  Future<bool> checkUnlock(String conversationId) async {
    try {
      final json = await _client.get('/subscription/unlock/$conversationId');
      return (json as Map<String, dynamic>)['unlocked'] == true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Internal — handle purchase completions
  // ------------------------------------------------------------------

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyAndDeliver(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndDeliver(PurchaseDetails purchase) async {
    final store = Platform.isIOS ? 'apple' : 'google';
    final token = purchase.verificationData.serverVerificationData;

    try {
      if (purchase.productID == kPremiumMonthlyId) {
        await _client.post('/subscription/verify', {
          'productId': purchase.productID,
          'store': store,
          'purchaseToken': token,
        });
        _statusController.add(true);
      } else if (purchase.productID == kUnlockSingleId) {
        final cid = _pendingUnlockConversationId;
        if (cid != null) {
          await _client.post('/subscription/unlock', {
            'conversationId': cid,
            'productId': purchase.productID,
            'store': store,
            'purchaseToken': token,
          });
          _pendingUnlockConversationId = null;
        }
      }
    } catch (e) {
      debugPrint('[IapService] verification failed: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final iapServiceProvider = Provider<IapService>((ref) {
  final client = ref.watch(httpClientProvider);
  final svc = IapService(client);
  ref.onDispose(svc.dispose);
  return svc;
});

/// Stream of premium status changes.
final premiumStreamProvider = StreamProvider<bool>((ref) {
  return ref.watch(iapServiceProvider).premiumStream;
});
