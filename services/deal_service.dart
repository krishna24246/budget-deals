import '../models/deal.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DealService {
  static final DealService _instance = DealService._internal();
  factory DealService() => _instance;
  DealService._internal();

  List<String> _generateKeywords(String title) {
    final words = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .split(' ')
        .where((word) => word.isNotEmpty) // Filter empty strings
        .toList();

    final keywords = <String>{};

    for (int i = 0; i < words.length; i++) {
      keywords.add(words[i]); // Single words

      if (i < words.length - 1) {
        keywords.add("${words[i]} ${words[i + 1]}"); // Two-word combinations
      }
    }

    return keywords.toList();
  }

  List<Deal> _cachedDeals = [];
  bool _isOffline = false;
  static const int _maxResultsPerQuery = 20; // Spark plan optimization

  Future<List<Deal>> getDeals({int limit = 20}) async {
    try {
      // Check if we should use cached data
      if (_isOffline || !FirebaseService.isInitialized) {
        return _cachedDeals.take(limit).toList();
      }

      // Use Firestore for real data - order by createdAt descending to show new deals first
      final firestore = FirebaseService.firestore;
      final query = firestore
          .collection('deals')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      final snapshot = await query.get();

      final deals = snapshot.docs
          .map(
            (doc) =>
                Deal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      // Cache the results for offline use
      _cachedDeals = deals;
      return deals;
    } catch (e) {
      print('Error fetching deals from Firestore: $e');
      // Return cached data on error
      return _cachedDeals.take(limit).toList();
    }
  }

  Future<List<Deal>> getTrendingDeals({int limit = 12}) async {
    try {
      // First check local cache for trending deals
      final cachedTrendingDeals = _cachedDeals
          .where((deal) => deal.isTrending)
          .take(limit)
          .toList();

      if (cachedTrendingDeals.isNotEmpty && _isOffline) {
        return cachedTrendingDeals;
      }

      // Use Firestore for real-time trending deals
      if (!FirebaseService.isInitialized) {
        return cachedTrendingDeals;
      }

      final firestore = FirebaseService.firestore;
      final query = firestore
          .collection('deals')
          .where('isActive', isEqualTo: true)
          .limit(limit * 2); // Get more to sort

      final snapshot = await query.get();

      final trendingDeals = snapshot.docs
          .map(
            (doc) =>
                Deal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      // Sort by createdAt descending (newest first)
      trendingDeals.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      return trendingDeals.take(limit).toList();
    } catch (e) {
      print('Error fetching trending deals: $e');
      // Return cached trending deals on error
      return _cachedDeals.where((deal) => deal.isTrending).take(limit).toList();
    }
  }

  Future<List<Deal>> getHotDeals({int limit = 10}) async {
    try {
      // First check local cache for hot deals
      final cachedHotDeals = _cachedDeals
          .where((deal) => deal.isHot)
          .take(limit)
          .toList();

      if (cachedHotDeals.isNotEmpty && _isOffline) {
        return cachedHotDeals;
      }

      // Use Firestore for real-time hot deals
      if (!FirebaseService.isInitialized) {
        return cachedHotDeals;
      }

      final firestore = FirebaseService.firestore;
      final query = firestore
          .collection('deals')
          .where('isActive', isEqualTo: true)
          .where('isHot', isEqualTo: true)
          .limit(limit * 2); // Get more to sort

      final snapshot = await query.get();

      final hotDeals = snapshot.docs
          .map(
            (doc) =>
                Deal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      // Sort by rankingScore descending
      hotDeals.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));

      return hotDeals.take(limit).toList();
    } catch (e) {
      print('Error fetching hot deals: $e');
      // Return cached hot deals on error
      return _cachedDeals.where((deal) => deal.isHot).take(limit).toList();
    }
  }

  Future<List<Deal>> getDealsByCategory(
    String category, {
    int limit = 20,
  }) async {
    try {
      // Check cache first
      final cachedByCategory = _cachedDeals
          .where((deal) => deal.category == category)
          .take(limit)
          .toList();

      if (cachedByCategory.isNotEmpty && _isOffline) {
        return cachedByCategory;
      }

      // Use Firestore for real data
      if (!FirebaseService.isInitialized) {
        return cachedByCategory;
      }

      final firestore = FirebaseService.firestore;
      final query = firestore
          .collection('deals')
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category)
          .limit(limit * 2); // Get more to sort

      final snapshot = await query.get();

      final dealsByCategory = snapshot.docs
          .map(
            (doc) =>
                Deal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      // Sort by rankingScore descending
      dealsByCategory.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));

      return dealsByCategory.take(limit).toList();
    } catch (e) {
      print('Error fetching deals by category: $e');
      // Return cached data on error
      return _cachedDeals
          .where((deal) => deal.category == category)
          .take(limit)
          .toList();
    }
  }

  Future<List<String>> getCategories() async {
    try {
      // Check cache first
      if (_cachedDeals.isNotEmpty && _isOffline) {
        return _cachedDeals
            .map((deal) => deal.category)
            .where((category) => category != null)
            .cast<String>()
            .toSet()
            .toList();
      }

      // Use Firestore for real data
      if (!FirebaseService.isInitialized) {
        return _cachedDeals
            .map((deal) => deal.category)
            .where((category) => category != null)
            .cast<String>()
            .toSet()
            .toList();
      }

      final firestore = FirebaseService.firestore;
      final query = firestore
          .collection('deals')
          .where('isActive', isEqualTo: true)
          .limit(_maxResultsPerQuery);

      final snapshot = await query.get();

      final categories = snapshot.docs
          .map(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['category'] as String?,
          )
          .where((category) => category != null)
          .cast<String>()
          .toSet()
          .toList();

      return categories;
    } catch (e) {
      print('Error fetching categories: $e');
      // Return cached categories on error
      return _cachedDeals
          .map((deal) => deal.category)
          .where((category) => category != null)
          .cast<String>()
          .toSet()
          .toList();
    }
  }

  Future<List<Deal>> searchDeals(String query, {int limit = 20}) async {
    final searchQuery = query.toLowerCase().trim();

    if (searchQuery.isEmpty) {
      return await getDeals(limit: limit);
    }

    // Client-side search for immediate results
    final clientResults = _cachedDeals
        .where(
          (deal) =>
              (deal.title?.toLowerCase().contains(searchQuery) ?? false) ||
              (deal.description?.toLowerCase().contains(searchQuery) ??
                  false) ||
              (deal.pastedText?.toLowerCase().contains(searchQuery) ?? false) ||
              (deal.category?.toLowerCase().contains(searchQuery) ?? false) ||
              (deal.storeName?.toLowerCase().contains(searchQuery) ?? false),
        )
        .toList();

    clientResults.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));

    final results = clientResults.take(limit).toList();

    // Also try Firestore search asynchronously for potential additional results
    if (FirebaseService.isInitialized) {
      try {
        final firestore = FirebaseService.firestore;
        final querySnapshot = firestore
            .collection('deals')
            .where('isActive', isEqualTo: true)
            .where('keywords', arrayContains: searchQuery)
            .orderBy('rankingScore', descending: true)
            .limit(limit);

        final snapshot = await querySnapshot.get();

        final firestoreResults = snapshot.docs
            .map(
              (doc) => Deal.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();

        // Merge results, preferring client results but adding any missing from Firestore
        final allResults = {...results, ...firestoreResults};
        final mergedResults = allResults.toList();
        mergedResults.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));
        return mergedResults.take(limit).toList();
      } catch (e) {
        print('Firestore search failed, using client results: $e');
      }
    }

    return results;
  }

  Future<void> incrementDealViews(String dealId) async {
    try {
      // Always update cache immediately for UI responsiveness
      final dealIndex = _cachedDeals.indexWhere((deal) => deal.id == dealId);
      if (dealIndex != -1) {
        final deal = _cachedDeals[dealIndex];
        final updatedDeal = Deal(
          id: deal.id,
          title: deal.title,
          description: deal.description,
          imageUrl: deal.imageUrl,
          originalPrice: deal.originalPrice,
          discountPrice: deal.discountPrice,
          discountPercent: deal.discountPercent,
          storeName: deal.storeName,
          category: deal.category,
          expiryDate: deal.expiryDate,
          views: deal.views + 1,
          rankingScore: Deal.calculateRankingScore(
            discountPercent: deal.discountPercent ?? 0,
            views: deal.views + 1,
            daysLeft: deal.daysLeft,
          ),
          isHot: deal.isHot,
          isExpiringSoon: deal.isExpiringSoon,
          externalUrl: deal.externalUrl,
          disclaimer: deal.disclaimer,
        );
        _cachedDeals[dealIndex] = updatedDeal;
      }

      // Update Firestore asynchronously (don't block UI)
      if (FirebaseService.isInitialized) {
        final firestore = FirebaseService.firestore;
        final docRef = firestore.collection('deals').doc(dealId);

        // Use transaction for consistency
        firestore
            .runTransaction((transaction) async {
              final snapshot = await transaction.get(docRef);
              if (snapshot.exists) {
                final currentViews =
                    (snapshot.data() as Map<String, dynamic>)['views'] ?? 0;
                final newViews = currentViews + 1;
                transaction.update(docRef, {'views': newViews});
              }
            })
            .catchError((error) {
              print('Error updating deal views: $error');
              // Silently fail for views update
            });
      }
    } catch (e) {
      print('Error incrementing deal views: $e');
      // Don't throw - views update is not critical
    }
  }

  Future<void> incrementDealLikes(String dealId, String userId) async {
    try {
      // Check if user already liked this deal
      final dealIndex = _cachedDeals.indexWhere((deal) => deal.id == dealId);
      if (dealIndex != -1) {
        final deal = _cachedDeals[dealIndex];
        if (deal.likedBy.contains(userId)) {
          // User already liked, don't increment again
          return;
        }
        // Update cache
        final updatedLikedBy = [...deal.likedBy, userId];
        final updatedDeal = deal.copyWith(
          likes: deal.likes + 1,
          likedBy: updatedLikedBy,
        );
        _cachedDeals[dealIndex] = updatedDeal;
      }

      // Update Firestore asynchronously (don't block UI)
      if (FirebaseService.isInitialized) {
        final firestore = FirebaseService.firestore;
        final docRef = firestore.collection('deals').doc(dealId);

        // Use transaction for consistency
        firestore
            .runTransaction((transaction) async {
              final snapshot = await transaction.get(docRef);
              if (snapshot.exists) {
                final data = snapshot.data() as Map<String, dynamic>;
                final currentLikedBy = List<String>.from(data['likedBy'] ?? []);
                if (currentLikedBy.contains(userId)) {
                  // User already liked, don't update
                  return;
                }
                final newLikedBy = [...currentLikedBy, userId];
                final newLikes = (data['likes'] ?? 0) + 1;
                transaction.update(docRef, {
                  'likes': newLikes,
                  'likedBy': newLikedBy,
                });
              }
            })
            .catchError((error) {
              print('Error updating deal likes: $error');
              // Silently fail for likes update
            });
      }
    } catch (e) {
      print('Error incrementing deal likes: $e');
      // Don't throw - likes update is not critical
    }
  }

  Future<void> decrementDealLikes(String dealId, String userId) async {
    try {
      // Check if user liked this deal
      final dealIndex = _cachedDeals.indexWhere((deal) => deal.id == dealId);
      if (dealIndex != -1) {
        final deal = _cachedDeals[dealIndex];
        if (!deal.likedBy.contains(userId)) {
          // User didn't like, don't decrement
          return;
        }
        // Update cache
        final updatedLikedBy = deal.likedBy
            .where((id) => id != userId)
            .toList();
        final updatedDeal = deal.copyWith(
          likes: deal.likes - 1,
          likedBy: updatedLikedBy,
        );
        _cachedDeals[dealIndex] = updatedDeal;
      }

      // Update Firestore asynchronously (don't block UI)
      if (FirebaseService.isInitialized) {
        final firestore = FirebaseService.firestore;
        final docRef = firestore.collection('deals').doc(dealId);

        // Use transaction for consistency
        firestore
            .runTransaction((transaction) async {
              final snapshot = await transaction.get(docRef);
              if (snapshot.exists) {
                final data = snapshot.data() as Map<String, dynamic>;
                final currentLikedBy = List<String>.from(data['likedBy'] ?? []);
                if (!currentLikedBy.contains(userId)) {
                  // User didn't like, don't update
                  return;
                }
                final newLikedBy = currentLikedBy
                    .where((id) => id != userId)
                    .toList();
                final newLikes = (data['likes'] ?? 0) - 1;
                transaction.update(docRef, {
                  'likes': newLikes,
                  'likedBy': newLikedBy,
                });
              }
            })
            .catchError((error) {
              print('Error updating deal likes: $error');
              // Silently fail for likes update
            });
      }
    } catch (e) {
      print('Error decrementing deal likes: $e');
      // Don't throw - likes update is not critical
    }
  }

  Future<void> incrementDealShares(String dealId, String userId) async {
    try {
      // Check if user already shared this deal
      final dealIndex = _cachedDeals.indexWhere((deal) => deal.id == dealId);
      if (dealIndex != -1) {
        final deal = _cachedDeals[dealIndex];
        if (deal.sharedBy.contains(userId)) {
          // User already shared, don't increment again
          return;
        }
        // Update cache
        final updatedSharedBy = [...deal.sharedBy, userId];
        final updatedDeal = deal.copyWith(
          shares: deal.shares + 1,
          sharedBy: updatedSharedBy,
        );
        _cachedDeals[dealIndex] = updatedDeal;
      }

      // Update Firestore asynchronously (don't block UI)
      if (FirebaseService.isInitialized) {
        final firestore = FirebaseService.firestore;
        final docRef = firestore.collection('deals').doc(dealId);

        // Use transaction for consistency
        firestore
            .runTransaction((transaction) async {
              final snapshot = await transaction.get(docRef);
              if (snapshot.exists) {
                final data = snapshot.data() as Map<String, dynamic>;
                final currentSharedBy = List<String>.from(
                  data['sharedBy'] ?? [],
                );
                if (currentSharedBy.contains(userId)) {
                  // User already shared, don't update
                  return;
                }
                final newSharedBy = [...currentSharedBy, userId];
                final newShares = (data['shares'] ?? 0) + 1;
                transaction.update(docRef, {
                  'shares': newShares,
                  'sharedBy': newSharedBy,
                });
              }
            })
            .catchError((error) {
              print('Error updating deal shares: $error');
              // Silently fail for shares update
            });
      }
    } catch (e) {
      print('Error incrementing deal shares: $e');
      // Don't throw - shares update is not critical
    }
  }

  void setOfflineMode(bool offline) {
    _isOffline = offline;
    if (offline) {
      print('📱 DealService: Switched to offline mode - using cached data');
    } else {
      print('🌐 DealService: Switched to online mode - fetching fresh data');
    }
  }

  bool get isOffline => _isOffline;

  // Method to seed Firestore with sample data (for development)
  Future<void> seedSampleData() async {
    try {
      if (!FirebaseService.isInitialized) {
        print('Firebase not initialized, skipping seed data');
        return;
      }

      final firestore = FirebaseService.firestore;
      final batch = firestore.batch();

      final sampleDeals = _generateMockDeals();

      for (final deal in sampleDeals) {
        final docRef = firestore.collection('deals').doc(deal.id);
        batch.set(docRef, {
          ...deal.toJson(),
          'keywords': _generateKeywords(deal.title ?? ''),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ Sample data seeded to Firestore successfully');
    } catch (e) {
      print('Error seeding sample data: $e');
    }
  }

  List<Deal> _generateMockDeals() {
    final now = DateTime.now();
    final categories = [
      'Electronics',
      'Fashion',
      'Home',
      'Books',
      'Sports',
      'Beauty',
      'Food',
    ];
    final stores = [
      'Amazon',
      'Best Buy',
      'Target',
      'Walmart',
      'Nike',
      'Adidas',
      'IKEA',
      'Barnes & Noble',
    ];
    final imageUrls = [
      'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400',
      'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400',
      'https://images.unsplash.com/photo-1543508282-6319a3e2621f?w=400',
      'https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=400',
      'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400',
      'https://images.unsplash.com/photo-1481349518771-20055b2a7b24?w=400',
      'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
      'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=400',
    ];

    return List.generate(20, (index) {
      final category = categories[index % categories.length];
      final store = stores[index % stores.length];
      final imageUrl = imageUrls[index % imageUrls.length];
      final originalPrice = (20.0 + (index * 10)).toDouble();
      final discountPercent = 10 + (index % 40); // 10-50% discount
      final discountPrice = originalPrice * (1 - discountPercent / 100);
      final views = 100 + (index * 50);
      final daysLeft = 1 + (index % 30);
      final expiryDate = now.add(Duration(days: daysLeft));

      final rankingScore = Deal.calculateRankingScore(
        discountPercent: discountPercent,
        views: views,
        daysLeft: daysLeft,
      );
      final isHot = discountPercent > 30 || views > 1000;
      final isExpiringSoon = daysLeft <= 3;

      return Deal(
        id: 'deal_$index',
        title: _generateTitle(category, index),
        description:
            'Amazing deal on quality products. Limited time offer with free shipping included.',
        imageUrl: imageUrl,
        originalPrice: originalPrice,
        discountPrice: discountPrice,
        discountPercent: discountPercent,
        storeName: store,
        category: category,
        expiryDate: expiryDate,
        views: views,
        rankingScore: rankingScore,
        isHot: isHot,
        isExpiringSoon: isExpiringSoon,
        externalUrl: 'https://example.com/deal/$index',
      );
    });
  }

  String _generateTitle(String category, int index) {
    final titles = {
      'Electronics': [
        'Wireless Headphones',
        'Smart Watch',
        'Bluetooth Speaker',
        'Phone Case',
        'Tablet Stand',
        'USB Cable',
        'Power Bank',
        'Laptop Sleeve',
      ],
      'Fashion': [
        'Designer Jacket',
        'Running Shoes',
        'Denim Jeans',
        'Summer Dress',
        'Leather Belt',
        'Sunglasses',
        'Watch',
        'Handbag',
      ],
      'Home': [
        'Coffee Maker',
        'Air Fryer',
        'Vacuum Cleaner',
        'Plant Pot',
        'Throw Pillow',
        'Wall Clock',
        'LED Lamp',
        'Storage Box',
      ],
      'Books': [
        'Fiction Novel',
        'Cookbook',
        'Self-Help Book',
        'Tech Manual',
        'Art Book',
        'Biography',
        'Children\'s Book',
        'Travel Guide',
      ],
      'Sports': [
        'Yoga Mat',
        'Fitness Tracker',
        'Resistance Bands',
        'Water Bottle',
        'Sports Bag',
        'Jump Rope',
        'Foam Roller',
        'Exercise Ball',
      ],
      'Beauty': [
        'Skincare Set',
        'Makeup Palette',
        'Hair Dryer',
        'Face Mask',
        'Perfume',
        'Lipstick',
        'Nail Polish',
        'Body Lotion',
      ],
      'Food': [
        'Gourmet Coffee',
        'Chocolate Box',
        'Olive Oil',
        'Spice Set',
        'Tea Collection',
        'Granola',
        'Honey Jar',
        'Cheese Selection',
      ],
    };

    final categoryTitles =
        titles[category] ??
        ['Amazing Product', 'Premium Item', 'Best Seller', 'Top Rated'];
    return '${categoryTitles[index % categoryTitles.length]} - ${index % 3 == 0
        ? 'Premium'
        : index % 3 == 1
        ? 'Best Quality'
        : 'Top Choice'}';
  }
}
