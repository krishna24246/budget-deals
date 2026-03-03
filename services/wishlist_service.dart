import 'dart:convert';
import '../models/deal.dart';
import 'cross_platform_auth_service.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WishlistService {
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  final CrossPlatformAuthService _authService = CrossPlatformAuthService();
  List<Deal> _cachedWishlist = [];
  bool _isOffline = false;
  static const int _maxWishlistSize = 100; // Spark plan optimization

  Future<List<Deal>> getWishlist() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        // Load from local storage
        return await _loadWishlistFromLocal();
      }

      // Check offline mode first
      if (_isOffline || !FirebaseService.isInitialized) {
        return _cachedWishlist.isNotEmpty
            ? _cachedWishlist
            : await _loadWishlistFromLocal();
      }

      // Get wishlist from Firestore
      final firestore = FirebaseService.firestore;
      final query = firestore
          .collection('wishlists')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(_maxWishlistSize);

      final snapshot = await query.get();

      final wishlistDeals = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dealData = data['deal'] as Map<String, dynamic>;
        final deal = Deal.fromJson(dealData);
        // Add the document ID for tracking
        return deal;
      }).toList();

      // Cache the results for offline use
      _cachedWishlist = wishlistDeals;
      // Save to local storage
      await _saveWishlistToLocal(wishlistDeals);
      return wishlistDeals;
    } catch (e) {
      print('Error fetching wishlist from Firestore: $e');
      // Return cached or local data on error
      return _cachedWishlist.isNotEmpty
          ? _cachedWishlist
          : await _loadWishlistFromLocal();
    }
  }

  Future<void> addToWishlist(Deal deal) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to save deals');
      }

      // Check if deal is already in wishlist
      if (await isDealInWishlist(deal.id)) {
        print('Deal ${deal.id} is already in wishlist');
        return;
      }

      // Add to Firestore (if online)
      if (!_isOffline && FirebaseService.isInitialized) {
        try {
          final firestore = FirebaseService.firestore;
          final wishlistDoc = firestore.collection('wishlists').doc();

          await wishlistDoc.set({
            'userId': user.uid,
            'dealId': deal.id,
            'deal': deal.toJson(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('✅ Deal ${deal.id} added to Firestore wishlist');
        } catch (firestoreError) {
          print('Error adding to Firestore wishlist: $firestoreError');
          // Continue to add to cache even if Firestore fails
        }
      }

      // Always add to local cache for immediate UI update
      if (!_cachedWishlist.any((item) => item.id == deal.id)) {
        _cachedWishlist.add(deal);
        await _saveWishlistToLocal(_cachedWishlist);
        print('✅ Deal ${deal.id} added to wishlist cache');
      }
    } catch (e) {
      print('Error adding deal to wishlist: $e');
      throw Exception('Failed to add deal to wishlist: $e');
    }
  }

  Future<void> removeFromWishlist(String dealId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to remove deals');
      }

      // Remove from Firestore (if online)
      if (!_isOffline && FirebaseService.isInitialized) {
        try {
          final firestore = FirebaseService.firestore;
          final query = firestore
              .collection('wishlists')
              .where('userId', isEqualTo: user.uid)
              .where('dealId', isEqualTo: dealId);

          final snapshot = await query.get();

          // Delete all matching documents
          final batch = firestore.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }

          if (snapshot.docs.isNotEmpty) {
            await batch.commit();
            print('✅ Deal $dealId removed from Firestore wishlist');
          }
        } catch (firestoreError) {
          print('Error removing from Firestore wishlist: $firestoreError');
          // Continue to remove from cache even if Firestore fails
        }
      }

      // Always remove from local cache
      _cachedWishlist.removeWhere((deal) => deal.id == dealId);
      await _saveWishlistToLocal(_cachedWishlist);
      print('✅ Deal $dealId removed from wishlist cache');
    } catch (e) {
      print('Error removing deal from wishlist: $e');
      throw Exception('Failed to remove deal from wishlist: $e');
    }
  }

  Future<bool> isDealInWishlist(String dealId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        return false;
      }

      // Check cache first for immediate response
      if (_cachedWishlist.any((deal) => deal.id == dealId)) {
        return true;
      }

      // If offline or no Firebase, return cache result
      if (_isOffline || !FirebaseService.isInitialized) {
        return false;
      }

      // Check Firestore for definitive answer
      final firestore = FirebaseService.firestore;
      final query = firestore
          .collection('wishlists')
          .where('userId', isEqualTo: user.uid)
          .where('dealId', isEqualTo: dealId)
          .limit(1);

      final snapshot = await query.get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if deal is in wishlist: $e');
      // Return cache result on error
      return _cachedWishlist.any((deal) => deal.id == dealId);
    }
  }

  Future<int> getWishlistCount() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        return 0;
      }

      // Return cached count for immediate response
      final cachedCount = _cachedWishlist.length;

      // If offline, return cached count
      if (_isOffline || !FirebaseService.isInitialized) {
        return cachedCount;
      }

      // Get actual count from Firestore
      final firestore = FirebaseService.firestore;
      final query = firestore
          .collection('wishlists')
          .where('userId', isEqualTo: user.uid);

      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting wishlist count: $e');
      // Return cached count on error
      return _cachedWishlist.length;
    }
  }

  // Stream wishlist changes for real-time updates
  Stream<List<Deal>> watchWishlist() {
    final user = _authService.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    final firestore = FirebaseService.firestore;
    final query = firestore
        .collection('wishlists')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(_maxWishlistSize);

    return query.snapshots().map((snapshot) {
      final wishlistDeals = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dealData = data['deal'] as Map<String, dynamic>;
        return Deal.fromJson(dealData);
      }).toList();

      // Update cache with real-time data
      _cachedWishlist = wishlistDeals;
      return wishlistDeals;
    });
  }

  void setOfflineMode(bool offline) {
    _isOffline = offline;
    if (offline) {
      print('📱 WishlistService: Switched to offline mode - using cached data');
    } else {
      print(
        '🌐 WishlistService: Switched to online mode - syncing with Firestore',
      );
    }
  }

  bool get isOffline => _isOffline;

  Future<void> _saveWishlistToLocal(List<Deal> deals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _authService.currentUser;
      if (user != null) {
        final key = 'wishlist_${user.uid}';
        final dealsJson = deals.map((deal) => deal.toJson()).toList();
        await prefs.setString(key, json.encode(dealsJson));
      }
    } catch (e) {
      print('Error saving wishlist to local: $e');
    }
  }

  Future<List<Deal>> _loadWishlistFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _authService.currentUser;
      if (user != null) {
        final key = 'wishlist_${user.uid}';
        final dealsString = prefs.getString(key);
        if (dealsString != null) {
          final dealsJson = json.decode(dealsString) as List;
          return dealsJson.map((e) => Deal.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      print('Error loading wishlist from local: $e');
    }
    return [];
  }

  // Clear wishlist (for logout)
  Future<void> clearWishlist() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        _cachedWishlist.clear();
        return;
      }

      // Clear from Firestore (if online)
      if (!_isOffline && FirebaseService.isInitialized) {
        try {
          final firestore = FirebaseService.firestore;
          final query = firestore
              .collection('wishlists')
              .where('userId', isEqualTo: user.uid);

          final snapshot = await query.get();

          // Delete all documents in batch
          final batch = firestore.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }

          if (snapshot.docs.isNotEmpty) {
            await batch.commit();
            print('✅ Wishlist cleared from Firestore');
          }
        } catch (firestoreError) {
          print('Error clearing Firestore wishlist: $firestoreError');
          // Continue to clear cache even if Firestore fails
        }
      }

      // Always clear cache
      _cachedWishlist.clear();
      print('✅ Wishlist cleared from cache');
    } catch (e) {
      print('Error clearing wishlist: $e');
      // Clear cache anyway
      _cachedWishlist.clear();
    }
  }

  // Sync wishlist with Firestore (for offline support)
  Future<void> syncWithFirestore() async {
    try {
      final user = _authService.currentUser;
      if (user == null || _isOffline || !FirebaseService.isInitialized) {
        return;
      }

      print('🔄 Syncing wishlist with Firestore...');

      // Get fresh data from Firestore
      final freshWishlist = await getWishlist();

      // Update cache
      _cachedWishlist = freshWishlist;

      print('✅ Wishlist synced with Firestore (${freshWishlist.length} items)');
    } catch (e) {
      print('Error syncing wishlist with Firestore: $e');
    }
  }

  // Export wishlist data (for user backup)
  Future<Map<String, dynamic>> exportWishlistData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to export wishlist');
      }

      final wishlist = await getWishlist();

      return {
        'userId': user.uid,
        'exportDate': DateTime.now().toIso8601String(),
        'itemCount': wishlist.length,
        'items': wishlist.map((deal) => deal.toJson()).toList(),
      };
    } catch (e) {
      print('Error exporting wishlist data: $e');
      rethrow;
    }
  }

  // Import wishlist data (for user restore)
  Future<void> importWishlistData(Map<String, dynamic> data) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to import wishlist');
      }

      final items = data['items'] as List;

      // Import deals one by one
      for (final item in items) {
        try {
          final deal = Deal.fromJson(item as Map<String, dynamic>);
          await addToWishlist(deal);
        } catch (dealError) {
          print('Error importing deal: $dealError');
          // Continue with other deals
        }
      }

      print('✅ Wishlist data imported successfully');
    } catch (e) {
      print('Error importing wishlist data: $e');
      rethrow;
    }
  }
}
