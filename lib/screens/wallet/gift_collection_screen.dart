import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';

class GiftCollectionScreen extends StatefulWidget {
  const GiftCollectionScreen({super.key});

  @override
  State<GiftCollectionScreen> createState() => _GiftCollectionScreenState();
}

class _GiftCollectionScreenState extends State<GiftCollectionScreen> {
  final AuthController _authController = Get.find<AuthController>();
  Map<String, dynamic>? _collection;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _authController.apiService.get(
        ApiConstants.myGiftCollection,
      );
      if (response.data['success'] != true) {
        throw StateError(
          response.data['message']?.toString() ??
              'Unable to load your gift collection.',
        );
      }

      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      if (mounted) {
        setState(() {
          _collection = data;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString().replaceFirst('Bad state: ', '');
          _isLoading = false;
        });
      }
    }
  }

  int _intValue(dynamic value) => int.tryParse(value.toString()) ?? 0;

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _collection?['summary'] is Map
        ? Map<String, dynamic>.from(_collection!['summary'] as Map)
        : const <String, dynamic>{};
    final gifts = (_collection?['collection'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final recentGifts = (_collection?['recent_gifts'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gift Collection'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadCollection,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadCollection,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(
                    _intValue(summary['total_gifts']),
                    _intValue(summary['unique_gifts']),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('My collection'),
                  const SizedBox(height: 12),
                  if (gifts.isEmpty)
                    _buildEmptyCollection()
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: gifts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.12,
                          ),
                      itemBuilder: (context, index) =>
                          _buildCollectionItem(gifts[index]),
                    ),
                  const SizedBox(height: 24),
                  _sectionTitle('Recently received'),
                  const SizedBox(height: 12),
                  if (recentGifts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Gifts from chats and Parties will appear here.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...recentGifts.map(_buildRecentGift),
                  const SizedBox(height: 12),
                  const Text(
                    'Gifts are collectibles and do not add VPC coins to your balance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadCollection,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int total, int unique) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5B8A), Color(0xFF9C4DCC)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.white, size: 42),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total ${total == 1 ? 'gift' : 'gifts'} collected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$unique ${unique == 1 ? 'unique design' : 'unique designs'}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  );

  Widget _buildEmptyCollection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('🎁', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            const Text(
              'Your collection is waiting for its first gift.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionItem(Map<String, dynamic> gift) {
    final name = gift['name']?.toString() ?? 'Gift';
    final emoji = gift['emoji']?.toString() ?? '🎁';
    final quantity = _intValue(gift['quantity']);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 38)),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Collected ×$quantity',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'First received ${_dateLabel(gift['first_received_at'])}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentGift(Map<String, dynamic> gift) {
    final senderName = gift['sender_name']?.toString() ?? 'Someone';
    final contextLabel = gift['context_type'] == 'party' ? 'Party' : 'chat';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            gift['emoji']?.toString() ?? '🎁',
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          '${gift['name'] ?? 'Gift'} from $senderName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('Sent in $contextLabel'),
        trailing: Text(
          _dateLabel(gift['created_at']),
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
