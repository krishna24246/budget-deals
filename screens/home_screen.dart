import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/deal.dart';
import '../services/deal_service.dart';
import '../services/wishlist_service.dart';
import '../services/cross_platform_auth_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/native_ad_widget.dart';
import 'deal_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DealService _dealService = DealService();
  final WishlistService _wishlistService = WishlistService();
  final CrossPlatformAuthService _authService = CrossPlatformAuthService();

  bool _isLoading = false;

  List<Deal> _hotDeals = [];
  List<Deal> _trendingDeals = [];
  Set<String> _savedDealIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitialDeals();
    _loadSavedDealIds();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadInitialDeals() async {
    setState(() => _isLoading = true);
    try {
      _hotDeals = await _dealService.getHotDeals();
      _trendingDeals = await _dealService.getTrendingDeals();
    } catch (e) {
      debugPrint("Load Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDeals() async {
    try {
      _hotDeals = await _dealService.getHotDeals();
      _trendingDeals = await _dealService.getTrendingDeals();
    } catch (e) {
      debugPrint("Refresh Error: $e");
    }
    setState(() {});
  }

  Future<void> _likeDeal(String dealId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like deals')),
        );
        return;
      }

      final allDeals = [..._hotDeals, ..._trendingDeals];
      final deal = allDeals.firstWhere((d) => d.id == dealId);
      if (deal.likedBy.contains(user.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already liked this deal')),
        );
        return;
      }

      await _dealService.incrementDealLikes(dealId, user.uid);
      setState(() {
        final hotIndex = _hotDeals.indexWhere((deal) => deal.id == dealId);
        if (hotIndex != -1) {
          final deal = _hotDeals[hotIndex];
          _hotDeals[hotIndex] = deal.copyWith(
            likes: deal.likes + 1,
            likedBy: [...deal.likedBy, user.uid],
          );
        }
        final trendingIndex = _trendingDeals.indexWhere(
          (deal) => deal.id == dealId,
        );
        if (trendingIndex != -1) {
          final deal = _trendingDeals[trendingIndex];
          _trendingDeals[trendingIndex] = deal.copyWith(
            likes: deal.likes + 1,
            likedBy: [...deal.likedBy, user.uid],
          );
        }
      });
    } catch (e) {
      debugPrint("Like Error: $e");
    }
  }

  Future<void> _shareDeal(String dealId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to share deals')),
        );
        return;
      }

      final allDeals = [..._hotDeals, ..._trendingDeals];
      final deal = allDeals.firstWhere((d) => d.id == dealId);

      await _dealService.incrementDealShares(dealId, user.uid);

      if (!deal.sharedBy.contains(user.uid)) {
        setState(() {
          final hotIndex = _hotDeals.indexWhere((deal) => deal.id == dealId);
          if (hotIndex != -1) {
            final deal = _hotDeals[hotIndex];
            _hotDeals[hotIndex] = deal.copyWith(
              shares: deal.shares + 1,
              sharedBy: [...deal.sharedBy, user.uid],
            );
          }
          final trendingIndex = _trendingDeals.indexWhere(
            (deal) => deal.id == dealId,
          );
          if (trendingIndex != -1) {
            final deal = _trendingDeals[trendingIndex];
            _trendingDeals[trendingIndex] = deal.copyWith(
              shares: deal.shares + 1,
              sharedBy: [...deal.sharedBy, user.uid],
            );
          }
        });
      }

      await _performShare(deal);
    } catch (e) {
      debugPrint("Share Error: $e");
    }
  }

  Future<void> _performShare(Deal deal) async {
    try {
      final shareText =
          '''
Check out this amazing deal on Budget Deals: ${deal.displayTitle}

${deal.pastedText ?? deal.description ?? 'Great deal available!'}

${deal.externalUrl ?? ''}

Download Budget Deals app for more great deals!
      '''
              .trim();

      await Share.share(
        shareText,
        subject: 'Great Deal on Budget Deals: ${deal.displayTitle}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deal shared successfully!')),
      );
    } catch (e) {
      debugPrint("Share perform error: $e");
    }
  }

  Future<void> _loadSavedDealIds() async {
    try {
      final wishlist = await _wishlistService.getWishlist();
      setState(() {
        _savedDealIds = wishlist.map((deal) => deal.id).toSet();
      });
    } catch (e) {
      debugPrint("Load Saved Deals Error: $e");
    }
  }

  Future<void> _toggleSaveDeal(String dealId) async {
    try {
      final isCurrentlySaved = _savedDealIds.contains(dealId);
      if (isCurrentlySaved) {
        final allDeals = [..._hotDeals, ..._trendingDeals];
        final deal = allDeals.firstWhere((d) => d.id == dealId);
        await _wishlistService.removeFromWishlist(dealId);
        setState(() {
          _savedDealIds.remove(dealId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from saved deals')),
        );
      } else {
        final allDeals = [..._hotDeals, ..._trendingDeals];
        final deal = allDeals.firstWhere((d) => d.id == dealId);
        await _wishlistService.addToWishlist(deal);
        setState(() {
          _savedDealIds.add(dealId);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to saved deals')));
      }
    } catch (e) {
      debugPrint("Save Deal Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving deal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Budget Deals',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimary,
          ),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshDeals,
              child: Column(
                children: [
                  Expanded(child: _buildHomeMode()),
                  const BannerAdWidget(),
                ],
              ),
            ),
    );
  }

  Widget _buildHomeMode() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("🔥 Hot Deals"),
          _buildHotDealsRow(),
          _sectionTitle("📈 Trending Now"),
          _buildTrendingList(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildHotDealsRow() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _hotDeals.length,
        itemBuilder: (context, index) {
          final deal = _hotDeals[index];
          debugPrint(
            'Hot deal ${deal.id}: title length=${deal.displayTitle.length}, likes=${deal.likes}, shares=${deal.shares}',
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              debugPrint(
                'Hot deal card constraints: width=${constraints.maxWidth}, height=${constraints.maxHeight}',
              );
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          deal.pastedText ??
                              deal.description ??
                              'No description available',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DealDetailsScreen(deal: deal),
                                ),
                              );
                            },
                            child: const Text('View Details'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTrendingList() {
    final itemCount = _trendingDeals.length + (_trendingDeals.length ~/ 5);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final adIndex = index ~/ 6;
        final isAd = index % 6 == 5;

        if (isAd) {
          return const NativeAdWidget();
        }

        final dealIndex = index - adIndex;
        final deal = _trendingDeals[dealIndex];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deal.displayTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deal.pastedText ??
                          deal.description ??
                          'No description available',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Spacer(),
                        if (deal.discountPercent != null &&
                            deal.discountPercent! > 0)
                          Chip(
                            label: Text("${deal.discountPercent}% Off"),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondary.withOpacity(0.8),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DealDetailsScreen(deal: deal),
                        ),
                      );
                    },
                    child: const Text('View Details'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
