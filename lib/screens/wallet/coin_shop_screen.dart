import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  String? _paymentMode;
  String? _paymentSettingsError;
  bool _checkoutEnabled = false;
  bool _isLoadingPaymentSettings = true;
  bool _isCreatingOrder = false;

  bool get _canPurchase =>
      !_isLoadingPaymentSettings &&
      _paymentSettingsError == null &&
      _checkoutEnabled &&
      (_paymentMode == 'sandbox' || _paymentMode == 'live');

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
  }

  Future<void> _loadPaymentSettings() async {
    if (mounted) {
      setState(() {
        _isLoadingPaymentSettings = true;
        _paymentSettingsError = null;
      });
    }

    try {
      final response = await Get.find<AuthController>().apiService.get(
        ApiConstants.getPaymentSettings,
      );
      if (response.data['success'] != true) {
        throw StateError(
          response.data['message']?.toString() ??
              'Unable to load payment settings.',
        );
      }

      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      final mode = data['payment_mode']?.toString();
      if (mode != 'sandbox' && mode != 'live') {
        throw StateError('The server returned an unsupported payment mode.');
      }
      final checkoutEnabled = data['checkout_enabled'] == true;

      if (!mounted) return;
      setState(() {
        _paymentMode = mode;
        _checkoutEnabled = checkoutEnabled;
        _isLoadingPaymentSettings = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _paymentSettingsError = error.toString().replaceFirst(
          'Bad state: ',
          '',
        );
        _isLoadingPaymentSettings = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    final packages = [
      {'coins': 100, 'price': 4.99, 'label': 'Starter Pack', 'popular': false},
      {'coins': 500, 'price': 19.99, 'label': 'Popular Pack', 'popular': true},
      {'coins': 1200, 'price': 39.99, 'label': 'Best Value', 'popular': false},
      {'coins': 3000, 'price': 89.99, 'label': 'VIP Master', 'popular': false},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Coin Store',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => Text(
                          '${authController.currentUser.value?.coins ?? 0} Coins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Get.to(() => const StoreScreen()),
              icon: const Icon(
                Icons.storefront_rounded,
                color: AppColors.primary,
              ),
              label: const Text(
                'Open Avatar & Frame Store 🛍️',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Coin Package',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingPaymentSettings) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            ] else if (_paymentSettingsError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not load payment settings: $_paymentSettingsError',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                    TextButton(
                      onPressed: _loadPaymentSettings,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ] else if (_canPurchase && _paymentMode == 'sandbox') ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'PayPal Sandbox is enabled. Complete checkout with a PayPal Sandbox buyer account; no real money is charged.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ] else if (_canPurchase && _paymentMode == 'live') ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'PayPal Live is enabled. Real payments will be captured and verified by the server before coins are added.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
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
                  'PayPal checkout is not configured for the selected mode. Ask the administrator to configure PayPal API credentials, merchant email, and the HTTPS return URL.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],

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

                return Opacity(
                  opacity: _canPurchase ? 1 : 0.6,
                  child: InkWell(
                    onTap: _canPurchase && !_isCreatingOrder
                        ? () => _startPayPalCheckout(
                            authController,
                            pkg['coins'] as int,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPopular
                              ? AppColors.primary
                              : AppColors.border,
                          width: isPopular ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          if (isPopular)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(18),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'POPULAR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const VpcCoinIcon(size: 44),
                                const SizedBox(height: 12),
                                Text(
                                  '${pkg['coins']} Coins',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pkg['label'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '\$${pkg['price']} USD',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Get.to(() => const StoreScreen()),
              icon: const Icon(Icons.storefront),
              label: const Text(
                'Visit Avatar & Frame Store 💎',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPayPalCheckout(
    AuthController authController,
    int coins,
  ) async {
    if (_isCreatingOrder) return;
    setState(() => _isCreatingOrder = true);

    try {
      final order = await authController.createPayPalOrder(coins);
      final checkoutId = order['checkout_id']?.toString();
      final approvalUrl = Uri.tryParse(order['approval_url']?.toString() ?? '');
      final amount = order['amount_usd']?.toString();
      final mode = order['mode']?.toString();
      if (checkoutId == null ||
          approvalUrl == null ||
          approvalUrl.scheme != 'https' ||
          !(approvalUrl.host == 'paypal.com' ||
              approvalUrl.host.endsWith('.paypal.com')) ||
          amount == null ||
          mode == null ||
          (mode != 'sandbox' && mode != 'live')) {
        throw StateError('PayPal returned an invalid checkout response.');
      }

      if (!mounted) return;
      try {
        final opened = await launchUrl(
          approvalUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          Get.snackbar(
            'PayPal did not open',
            'Tap “Open PayPal” to continue checkout.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } catch (error) {
        if (mounted) {
          Get.snackbar(
            'PayPal did not open',
            error.toString().replaceFirst('Bad state: ', ''),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
      if (!mounted) return;
      _showPayPalApprovalDialog(
        authController,
        checkoutId: checkoutId,
        approvalUrl: approvalUrl,
        coins: coins,
        amount: amount,
        mode: mode,
      );
    } catch (error) {
      if (mounted) {
        Get.snackbar(
          'Unable to start checkout',
          error.toString().replaceFirst('Bad state: ', ''),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
  }

  void _showPayPalApprovalDialog(
    AuthController authController, {
    required String checkoutId,
    required Uri approvalUrl,
    required int coins,
    required String amount,
    required String mode,
  }) {
    var isOpeningPayPal = false;
    var isCapturing = false;
    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.payment, color: Color(0xFF003087)),
                const SizedBox(width: 8),
                Text(mode == 'sandbox' ? 'PayPal Sandbox' : 'PayPal Live'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$coins Vamper Coins',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total: \$$amount USD',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  mode == 'sandbox'
                      ? 'Sign in with a PayPal Sandbox buyer account. No real money is charged.'
                      : 'You will be redirected to PayPal to authorize a real payment. The server verifies the captured amount and merchant before adding coins.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'After approving in PayPal, return to Vamper and tap “Verify payment”.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isCapturing ? null : () => Get.back(),
                child: const Text('Close'),
              ),
              OutlinedButton(
                onPressed: isOpeningPayPal || isCapturing
                    ? null
                    : () async {
                        setDialogState(() => isOpeningPayPal = true);
                        try {
                          final opened = await launchUrl(
                            approvalUrl,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!opened) {
                            throw StateError(
                              'Could not open PayPal. Please try again.',
                            );
                          }
                        } catch (error) {
                          Get.snackbar(
                            'PayPal unavailable',
                            error.toString().replaceFirst('Bad state: ', ''),
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        } finally {
                          setDialogState(() => isOpeningPayPal = false);
                        }
                      },
                child: isOpeningPayPal
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Open PayPal again'),
              ),
              ElevatedButton(
                onPressed: isCapturing || isOpeningPayPal
                    ? null
                    : () async {
                        setDialogState(() => isCapturing = true);
                        final success = await authController.capturePayPalOrder(
                          checkoutId,
                        );
                        if (success) {
                          Get.back();
                        } else {
                          setDialogState(() => isCapturing = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: isCapturing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verify payment'),
              ),
            ],
          );
        },
      ),
      barrierDismissible: false,
    );
  }
}
