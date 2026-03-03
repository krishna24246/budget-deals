import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter/services.dart';
import '../models/deal.dart';
import '../services/deal_service.dart';
import '../services/wishlist_service.dart';
import '../services/cross_platform_auth_service.dart';
import '../services/ad_service.dart';
import '../widgets/native_ad_widget.dart';

class DealDetailsScreen extends StatefulWidget {
  final Deal deal;

  const DealDetailsScreen({super.key, required this.deal});

  @override
  State<DealDetailsScreen> createState() => _DealDetailsScreenState();
}

class _DealDetailsScreenState extends State<DealDetailsScreen> {
  final DealService _dealService = DealService();
  final WishlistService _wishlistService = WishlistService();
  final CrossPlatformAuthService _authService = CrossPlatformAuthService();
  final AdService _adService = AdService();
  bool _isInWishlist = false;
  bool _isLiked = false;
  bool _isLoading = false;
  bool _isDescriptionUnlocked = false;

  @override
  void initState() {
    super.initState();
    _loadWishlistStatus();
    _loadLikedStatus();
    _incrementViews();
  }

  Future<void> _loadWishlistStatus() async {
    try {
      final isInWishlist = await _wishlistService.isDealInWishlist(
        widget.deal.id,
      );
      if (mounted) {
        setState(() {
          _isInWishlist = isInWishlist;
        });
      }
    } catch (e) {}
  }

  Future<void> _loadLikedStatus() async {
    final user = _authService.currentUser;
    if (user != null && mounted) {
      setState(() {
        _isLiked = widget.deal.likedBy.contains(user.uid);
      });
    }
  }

  Future<void> _incrementViews() async {
    try {
      await _dealService.incrementDealViews(widget.deal.id);
    } catch (e) {}
  }

  Future<void> _toggleWishlist() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isInWishlist) {
        await _wishlistService.removeFromWishlist(widget.deal.id);
        setState(() {
          _isInWishlist = false;
        });
        _showMessage('Removed from wishlist');
      } else {
        await _wishlistService.addToWishlist(widget.deal);
        setState(() {
          _isInWishlist = true;
        });
        _showMessage('Added to wishlist');
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _likeDeal() async {
    final user = _authService.currentUser;
    if (user == null) {
      _showMessage('Please log in to like deals');
      return;
    }

    try {
      if (_isLiked) {
        await _dealService.decrementDealLikes(widget.deal.id, user.uid);
        setState(() {
          _isLiked = false;
        });
        _showMessage('Deal unliked!');
      } else {
        await _dealService.incrementDealLikes(widget.deal.id, user.uid);
        setState(() {
          _isLiked = true;
        });
        _showMessage('Deal liked!');
      }
    } catch (e) {
      _showMessage('Error updating like');
    }
  }

  Future<void> _shareDeal() async {
    final user = _authService.currentUser;
    if (user == null) {
      _showMessage('Please log in to share deals');
      return;
    }

    try {
      await _dealService.incrementDealShares(widget.deal.id, user.uid);
      await _performShare();
    } catch (e) {
      _showMessage('Error sharing deal');
    }
  }

  Future<void> _performShare() async {
    try {
      final shareText =
          '''
Check out this amazing deal on Budget Deals: ${widget.deal.displayTitle}

${widget.deal.pastedText ?? widget.deal.description ?? 'Great deal available!'}

${widget.deal.externalUrl ?? ''}

Download Budget Deals app for more great deals!
      '''
              .trim();

      await Share.share(
        shareText,
        subject: 'Great Deal on Budget Deals: ${widget.deal.displayTitle}',
      );

      _showMessage('Deal shared successfully!');
    } catch (e) {
      debugPrint("Share perform error: $e");
    }
  }

  Future<void> _launchExternalUrl() async {
    try {
      if (widget.deal.externalUrl == null) {
        _showMessage('No external link available');
        return;
      }
      final Uri url = Uri.parse(widget.deal.externalUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showMessage('Cannot open external link');
      }
    } catch (e) {
      _showMessage('Error opening link: ${e.toString()}');
    }
  }

  Future<void> _copyLink() async {
    try {
      final link = widget.deal.externalUrl ?? widget.deal.link ?? '';
      if (link.isEmpty) {
        _showMessage('No link available to copy');
        return;
      }
      await Clipboard.setData(ClipboardData(text: link));
      _showMessage('Link copied to clipboard!');
    } catch (e) {
      _showMessage('Error copying link: ${e.toString()}');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _unlockDescription() async {
    _adService.showRewardedAd(
      () {
        setState(() {
          _isDescriptionUnlocked = true;
        });
        _showMessage('Description unlocked!');
      },
      onError: (message) {
        _showMessage(message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _adService.showInterstitialAd();
        return true;
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: Colors.orange[600],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.deal.displayTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black87,
                      ),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      widget.deal.imageUrl ?? '',
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        );
                      },
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                    if (widget.deal.originalPrice != null)
                      Positioned(
                        bottom: 10,
                        left: 16,
                        child: Text(
                          '\$${widget.deal.originalPrice!.toStringAsFixed(2)}',
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPriceSection(),

                    const SizedBox(height: 20),

                    _buildStoreCategorySection(),

                    const SizedBox(height: 20),

                    _buildDescriptionSection(),

                    const SizedBox(height: 20),

                    _buildExpiryViewsSection(),

                    const SizedBox(height: 30),

                    _buildActionButtons(),

                    const SizedBox(height: 20),

                    _buildDisclaimer(),

                    const SizedBox(height: 30),

                    _buildNativeAd(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[50]!, Colors.orange[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.deal.discountPrice != null
                      ? '\$${widget.deal.discountPrice!.toStringAsFixed(2)}'
                      : 'Pricing available upon request',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      widget.deal.originalPrice != null
                          ? '\$${widget.deal.originalPrice!.toStringAsFixed(2)}'
                          : '',
                      style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.deal.discountPercent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${widget.deal.discountPercent}% OFF',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                if (widget.deal.savings != null) const SizedBox(height: 8),
                if (widget.deal.savings != null)
                  Text(
                    'You save \$${widget.deal.savings!.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCategorySection() {
    return Row(
      children: [
        Icon(Icons.store, color: Colors.orange[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.deal.storeName != null)
                Text(
                  widget.deal.storeName!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              Text(
                widget.deal.category ?? 'No category',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    final descriptionText =
        widget.deal.pastedText ??
        widget.deal.description ??
        'No description available';
    final isLongDescription = descriptionText.length > 200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (isLongDescription && !_isDescriptionUnlocked)
          Column(
            children: [
              Text(
                '${descriptionText.substring(0, 200)}...',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _unlockDescription,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Watch Ad to Unlock Full Description'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          )
        else if (isLongDescription && _isDescriptionUnlocked)
          ExpansionTile(
            title: Text(
              '${descriptionText.substring(0, 200)}...',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SingleChildScrollView(
                  child: Linkify(
                    text: descriptionText,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    linkStyle: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    onOpen: (link) async {
                      final Uri url = Uri.parse(link.url);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          )
        else
          Linkify(
            text: descriptionText,
            style: const TextStyle(fontSize: 16, height: 1.5),
            linkStyle: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            onOpen: (link) async {
              final Uri url = Uri.parse(link.url);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
      ],
    );
  }

  Widget _buildExpiryViewsSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.deal.isExpiringSoon
                  ? Colors.red[50]
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.deal.isExpiringSoon
                    ? Colors.red[200]!
                    : Colors.grey[300]!,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timer,
                  color: widget.deal.isExpiringSoon
                      ? Colors.red[600]
                      : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  'Expires in',
                  style: TextStyle(
                    color: widget.deal.isExpiringSoon
                        ? Colors.red[600]
                        : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  widget.deal.daysLeft > 0
                      ? '${widget.deal.daysLeft} days'
                      : '${widget.deal.hoursLeft} hours',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.deal.isExpiringSoon
                        ? Colors.red[600]
                        : Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.visibility, color: Colors.blue[600], size: 24),
                const SizedBox(height: 4),
                Text(
                  'Views',
                  style: TextStyle(color: Colors.blue[600], fontSize: 12),
                ),
                Text(
                  '${widget.deal.views}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _copyLink,
            icon: const Icon(Icons.copy),
            label: const Text(
              'Copy Link',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _likeDeal,
                icon: Icon(
                  _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  color: _isLiked
                      ? Colors.blue
                      : (Colors.orange[600] ?? Colors.orange),
                ),
                label: Text(
                  _isLiked ? 'Liked' : 'Like',
                  style: TextStyle(
                    color: _isLiked
                        ? Colors.blue
                        : (Colors.orange[600] ?? Colors.orange),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _isLiked
                        ? Colors.blue
                        : (Colors.orange[600] ?? Colors.orange),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _toggleWishlist,
                icon: Icon(
                  _isInWishlist ? Icons.favorite : Icons.favorite_border,
                  color: _isInWishlist
                      ? Colors.red
                      : (Colors.orange[600] ?? Colors.orange),
                ),
                label: Text(
                  _isInWishlist ? 'Saved' : 'Save Deal',
                  style: TextStyle(
                    color: _isInWishlist
                        ? Colors.red
                        : (Colors.orange[600] ?? Colors.orange),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _isInWishlist
                        ? Colors.red
                        : (Colors.orange[600] ?? Colors.orange),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareDeal,
                icon: Icon(
                  Icons.share,
                  color: (Colors.orange[600] ?? Colors.orange),
                ),
                label: Text(
                  'Share',
                  style: TextStyle(
                    color: (Colors.orange[600] ?? Colors.orange),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: (Colors.orange[600] ?? Colors.orange),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.deal.disclaimer ?? 'No disclaimer',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeAd() {
    return const NativeAdWidget();
  }
}
