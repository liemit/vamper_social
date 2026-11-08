import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';
import '../../widgets/vpc_coin_icon.dart';
import 'store_screen.dart';

class CoinShopScreen extends StatefulWidget {
  const CoinShopScreen({super.key});

  @override
  State<CoinShopScreen> createState() => _CoinShopScreenState();
}

class _CoinShopScreenState extends State<CoinShopScreen> {
  static const bool _playBillingEnabled = false;
  static const Map<String, int> _playProducts = {
    'vamper_coins_100': 100,
    'vamper_coins_500': 500,
    'vamper_coins_1200': 1200,
    'vamper_coins_3000': 3000,
  };

  final InAppPurchase _billing = InAppPurchase.instance;
  final Map<String, ProductDetails> _productDetails = {};
  final Set<String> _processingPurchaseTokens = {};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isLoadingPlayProducts = false;
  String? _playBillingError;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _usesGooglePlayBilling => _playBillingEnabled && _isAndroid;

  @override
  void initState() {
    super.initState();
    if (_usesGooglePlayBilling) {
      _purchaseSubscription = _billing.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object error) {
          if (mounted) {
            setState(() => _playBillingError = error.toString());
          }
        },
      );
      _loadPlayProducts();
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  String _obfuscatedAccountId(String userId) =>
      sha256.convert(utf8.encode('vamper-user-$userId')).toString();

  Future<void> _loadPlayProducts() async {
    setState(() {
      _isLoadingPlayProducts = true;
      _playBillingError = null;
    });

    try {
      final isAvailable = await _billing.isAvailable();
      if (!isAvailable) {
        throw StateError('Google Play Billing is unavailable on this device.');
      }

      final response = await _billing.queryProductDetails(_playProducts.keys.toSet());
      if (response.error != null) {
        throw StateError(response.error!.message);
      }

      _productDetails
        ..clear()
        ..addEntries(response.productDetails.map((product) => MapEntry(product.id, product)));
      if (response.notFoundIDs.isNotEmpty) {
        _playBillingError =
            'Play Console products not found: ${response.notFoundIDs.join(', ')}';
      }
    } catch (error) {
      _playBillingError = error.toString().replaceFirst('Bad state: ', '');
    } finally {
      if (mounted) setState(() => _isLoadingPlayProducts = false);
    }
  }

  Future<void> _buyGooglePlayProduct(ProductDetails product) async {
    if (_isLoadingPlayProducts) return;
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) {
      Get.snackbar('Sign in required', 'Sign in before purchasing VPC.');
      return;
    }

    try {
      setState(() => _isLoadingPlayProducts = true);
      final started = await _billing.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: _obfuscatedAccountId(user.id),
        ),
        autoConsume: true,
      );
      if (!started) {
        if (mounted) setState(() => _isLoadingPlayProducts = false);
        Get.snackbar('Purchase not started', 'Google Play could not start the purchase.');
      }
    } catch (error) {
      if (mounted) setState(() => _isLoadingPlayProducts = false);
      Get.snackbar(
        'Purchase failed',
        error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _isLoadingPlayProducts = true);
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() => _isLoadingPlayProducts = false);
          Get.snackbar(
            'Purchase failed',
            purchase.error?.message ?? 'Google Play did not complete this purchase.',
          );
        }
        continue;
      }

      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        if (mounted) setState(() => _isLoadingPlayProducts = false);
        continue;
      }

      final purchaseToken = purchase.verificationData.serverVerificationData;
      if (purchaseToken.isEmpty ||
          !_playProducts.containsKey(purchase.productID) ||
          !_processingPurchaseTokens.add(purchaseToken)) {
        continue;
      }

      try {
        final authController = Get.find<AuthController>();
        final user = authController.currentUser.value;
        if (user == null) throw StateError('User session is not available.');

        final response = await authController.apiService.post(
          ApiConstants.verifyGooglePlayPurchase,
          data: {
            'product_id': purchase.productID,
            'purchase_token': purchaseToken,
            'obfuscated_account_id': _obfuscatedAccountId(user.id),
          },
        );
        if (response.data is! Map || response.data['success'] != true) {
          throw StateError(
            response.data is Map
                ? response.data['message']?.toString() ?? 'Purchase verification failed.'
                : 'Purchase verification failed.',
          );
        }

        final data = Map<String, dynamic>.from(response.data['data'] as Map);
        final balance = int.tryParse(data['balance'].toString());
        if (balance == null) throw StateError('Server returned an invalid VPC balance.');
        await authController.updateCachedUser(user.copyWith(coins: balance));

        var completionFailed = false;
        if (purchase.pendingCompletePurchase) {
          try {
            await _billing.completePurchase(purchase);
          } catch (error) {
            completionFailed = true;
            debugPrint('Google Play purchase was credited but could not be finalized: $error');
          }
        }
        if (mounted) {
          Get.snackbar(
            completionFailed ? 'VPC credited' : 'Purchase successful',
            completionFailed
                ? 'VPC is credited. Reopen the app to retry finishing the Google Play transaction.'
                : data['coins_credited'] == 0
                    ? 'This purchase was already credited.'
                    : '${data['coins_credited']} VPC added to your balance.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } catch (error) {
        if (mounted) {
          Get.snackbar(
            'Could not verify purchase',
            error.toString().replaceFirst('Bad state: ', ''),
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 6),
          );
        }
      } finally {
        _processingPurchaseTokens.remove(purchaseToken);
        if (mounted) setState(() => _isLoadingPlayProducts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    final packages = [
      {'coins': 100, 'price': 4.99, 'product_id': 'vamper_coins_100', 'label': 'Starter Pack', 'popular': false},
      {'coins': 500, 'price': 19.99, 'product_id': 'vamper_coins_500', 'label': 'Popular Pack', 'popular': true},
      {'coins': 1200, 'price': 39.99, 'product_id': 'vamper_coins_1200', 'label': 'Best Value', 'popular': false},
      {'coins': 3000, 'price': 89.99, 'product_id': 'vamper_coins_3000', 'label': 'VIP Master', 'popular': false},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Coin Store', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Balance Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Obx(() => Text(
                        '${authController.currentUser.value?.coins ?? 0} Coins',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      )),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const VpcCoinIcon(size: 40),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Get.to(() => const StoreScreen()),
              icon: const Icon(Icons.storefront_rounded, color: AppColors.primary),
              label: const Text('Open Avatar & Frame Store 🛍️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(height: 24),
            const Text('Select Coin Package', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            if (_usesGooglePlayBilling) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shop_2_outlined, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _playBillingError ??
                            (_isLoadingPlayProducts
                                ? 'Loading Google Play products...'
                                : 'Secure checkout and local pricing by Google Play.'),
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      ),
                    ),
                    if (!_isLoadingPlayProducts && _productDetails.isEmpty)
                      IconButton(
                        tooltip: 'Retry loading products',
                        onPressed: _loadPlayProducts,
                        icon: const Icon(Icons.refresh),
                      ),
                  ],
                ),
              ),
            ] else if (kIsWeb) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Web checkout is currently PayPal Sandbox for testing.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ] else if (_isAndroid) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Coin purchases on Android are temporarily unavailable. Google Play Billing will be enabled after Play Console setup.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Coin purchases are not configured for this platform yet.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],

            // Coin packages are only offered where a supported checkout is enabled.
            if (!_isAndroid || _playBillingEnabled)
              GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: packages.length,
              itemBuilder: (context, index) {
                final pkg = packages[index];
                final isPopular = pkg['popular'] as bool;
                final productId = pkg['product_id'] as String;
                final playProduct = _productDetails[productId];

                return InkWell(
                  onTap: _isLoadingPlayProducts
                      ? null
                      : _usesGooglePlayBilling
                          ? (playProduct == null
                              ? null
                              : () => _buyGooglePlayProduct(playProduct))
                          : kIsWeb
                              ? () => _showPayPalCheckout(
                                    context,
                                    authController,
                                    pkg['coins'] as int,
                                    pkg['price'] as double,
                                  )
                              : () => Get.snackbar(
                                    'Purchases unavailable',
                                    'Coin purchases are not configured for this platform.',
                                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPopular ? AppColors.primary : AppColors.border,
                        width: isPopular ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Stack(
                      children: [
                        if (isPopular)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const VpcCoinIcon(size: 44),
                              const SizedBox(height: 12),
                              Text('${pkg['coins']} Coins', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Text(pkg['label'] as String, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _usesGooglePlayBilling
                                      ? (playProduct?.price ??
                                          (_isLoadingPlayProducts ? 'Loading...' : 'Unavailable'))
                                      : '\$${pkg['price']} USD',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Get.to(() => const StoreScreen()),
              icon: const Icon(Icons.storefront),
              label: const Text('Visit Avatar & Frame Store 💎', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayPalCheckout(BuildContext context, AuthController authController, int coins, double price) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.payment, color: Color(0xFF003087)),
            const SizedBox(width: 8),
            const Text('PayPal Sandbox Checkout'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You are purchasing:', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 4),
            Text('$coins Vamper Coins', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount:', style: TextStyle(fontSize: 16)),
                Text('\$$price USD', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clicking below will open PayPal Sandbox login in your browser to test payment.',
                      style: TextStyle(fontSize: 12, color: Colors.blueAccent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087), // PayPal Blue
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Get.back();
              final paymentToken = 'pp_sandbox_${DateTime.now().millisecondsSinceEpoch}';
              
              // 1. Open PayPal Sandbox Login URL
              final Uri sandboxUrl = Uri.parse('https://www.sandbox.paypal.com/signin');
              if (await canLaunchUrl(sandboxUrl)) {
                await launchUrl(sandboxUrl, mode: LaunchMode.externalApplication);
              }

              // 2. Show 2nd step confirmation dialog with secure token verification
              _showPaymentConfirmationDialog(context, authController, coins, price, paymentToken);
            },
            child: const Text('Open PayPal Sandbox'),
          ),
        ],
      ),
    );
  }

  void _showPaymentConfirmationDialog(BuildContext context, AuthController authController, int coins, double price, String paymentToken) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Confirm Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Did you successfully complete your payment of \$$price USD on PayPal Sandbox?', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Text('Clicking "Confirm" will securely verify and credit $coins coins to your account.', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Not Yet', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Get.back();
              await authController.verifyAndRechargePayment(coins, price, paymentToken);
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }
}
