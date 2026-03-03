import 'package:flutter/material.dart';
import '../models/deal.dart';
import '../services/wishlist_service.dart';
import '../services/deal_service.dart';
import 'deal_details_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final WishlistService _wishlistService = WishlistService();
  final DealService _dealService = DealService();
  List<Deal> _wishlistDeals = [];
  bool _isLoading = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final deals = await _wishlistService.getWishlist();

      if (mounted) {
        setState(() {
          _wishlistDeals = deals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading wishlist: $e')));
      }
    }
  }

  Future<void> _removeFromWishlist(Deal deal) async {
    try {
      await _wishlistService.removeFromWishlist(deal.id);
      setState(() {
        _wishlistDeals.remove(deal);
      });

      _showMessage('Removed from wishlist');
    } catch (e) {
      _showMessage('Error removing deal: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Deals'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isOffline ? Icons.cloud_off : Icons.cloud_done,
              color: _isOffline ? Colors.red[300] : Colors.green[300],
            ),
            onPressed: () {
              setState(() {
                _isOffline = !_isOffline;
              });
              _wishlistService.setOfflineMode(_isOffline);
              _dealService.setOfflineMode(_isOffline);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isOffline) _buildOfflineBanner(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildWishlistContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadWishlist,
        heroTag: 'wishlist_refresh_fab',
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.blue[100],
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You\'re offline. Viewing cached deals.',
              style: TextStyle(
                color: Colors.blue[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistContent() {
    if (_wishlistDeals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No saved deals yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Save deals to view them here',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWishlist,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _wishlistDeals.length,
        itemBuilder: (context, index) {
          final deal = _wishlistDeals[index];
          return _buildWishlistDealCard(deal);
        },
      ),
    );
  }

  Widget _buildWishlistDealCard(Deal deal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDealDetails(deal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal.displayTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${deal.category ?? 'Unknown category'} • ${deal.storeName ?? 'Unknown store'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          deal.pastedText ??
                              deal.description ??
                              'No description available',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ends in ${deal.daysLeft} days',
                          style: TextStyle(
                            color: deal.isExpiringSoon
                                ? Colors.red[600]
                                : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () => _showRemoveDialog(deal),
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToDealDetails(deal),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('View Deal'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.blue[600]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _removeFromWishlist(deal),
                      icon: const Icon(
                        Icons.favorite,
                        size: 16,
                        color: Colors.red,
                      ),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRemoveDialog(Deal deal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Deal'),
          content: Text(
            'Are you sure you want to remove "${deal.displayTitle}" from your wishlist?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeFromWishlist(deal);
              },
              child: Text('Remove', style: TextStyle(color: Colors.red[600])),
            ),
          ],
        );
      },
    );
  }

  void _navigateToDealDetails(Deal deal) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DealDetailsScreen(deal: deal)),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
