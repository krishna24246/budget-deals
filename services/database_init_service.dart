import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import '../models/deal.dart';
import 'auth_service.dart';

class DatabaseInitService {
  static final DatabaseInitService _instance = DatabaseInitService._internal();
  factory DatabaseInitService() => _instance;
  DatabaseInitService._internal();

  static const String _version = '1.0.0';

  Future<void> initializeDatabase() async {
    try {
      print('🚀 Initializing Budget Deals Database...');

      // Ensure Firebase is initialized
      if (!FirebaseService.isInitialized) {
        await FirebaseService.initialize();
      }

      // Check database connection
      await _testFirestoreConnection();

      // Initialize collections
      await _initializeCollections();

      // Seed sample data if needed
      await _seedInitialData();

      // Set up database version
      await _setDatabaseVersion();

      print('✅ Database initialization completed successfully');
    } catch (e) {
      print('❌ Database initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _testFirestoreConnection() async {
    try {
      final firestore = FirebaseService.firestore;

      // Test basic connection
      await firestore.collection('health_check').doc('connection_test').set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': true,
      });

      print('✅ Firestore connection test passed');
    } catch (e) {
      print('❌ Firestore connection test failed: $e');
      throw Exception(
        'Cannot connect to Firestore. Check your internet connection and Firebase configuration.',
      );
    }
  }

  Future<void> _initializeCollections() async {
    final firestore = FirebaseService.firestore;
    final batch = firestore.batch();

    try {
      // Initialize users collection structure
      await _createCollectionStructure(firestore, 'users');

      // Initialize deals collection with indexes
      await _createCollectionStructure(firestore, 'deals');

      // Initialize wishlists collection
      await _createCollectionStructure(firestore, 'wishlists');

      // Initialize categories collection
      await _createCollectionStructure(firestore, 'categories');

      // Initialize analytics collection
      await _createCollectionStructure(firestore, 'analytics');

      // Initialize config collection
      await _createCollectionStructure(firestore, 'config');

      print('✅ All collections initialized');
    } catch (e) {
      print('❌ Failed to initialize collections: $e');
      rethrow;
    }
  }

  Future<void> _createCollectionStructure(
    FirebaseFirestore firestore,
    String collectionName,
  ) async {
    try {
      // Create a timestamp document to establish the collection
      final docRef = firestore.collection(collectionName).doc('_structure');
      await docRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'version': _version,
        'collection': collectionName,
      });

      // Delete the structure document (we just needed to create the collection)
      await docRef.delete();

      print('✅ Collection structure created: $collectionName');
    } catch (e) {
      // Collection might already exist, this is not a critical error
      print('ℹ️ Collection might already exist: $collectionName');
    }
  }

  Future<void> _seedInitialData() async {
    try {
      final firestore = FirebaseService.firestore;

      // Check if we already have sample data
      final existingDeals = await firestore.collection('deals').limit(1).get();
      if (existingDeals.docs.isNotEmpty) {
        print('ℹ️ Sample data already exists, skipping...');
        return;
      }

      // Seed categories
      await _seedCategories(firestore);

      // Seed sample deals
      await _seedSampleDeals(firestore);

      // Seed configuration
      await _seedConfiguration(firestore);

      print('✅ Initial data seeded successfully');
    } catch (e) {
      print('❌ Failed to seed initial data: $e');
      // Don't rethrow - seeding is not critical for basic functionality
    }
  }

  Future<void> _seedCategories(FirebaseFirestore firestore) async {
    final categories = [
      {
        'id': 'electronics',
        'name': 'Electronics',
        'icon': '🔌',
        'isActive': true,
      },
      {'id': 'fashion', 'name': 'Fashion', 'icon': '👕', 'isActive': true},
      {'id': 'home', 'name': 'Home & Garden', 'icon': '🏠', 'isActive': true},
      {'id': 'books', 'name': 'Books', 'icon': '📚', 'isActive': true},
      {
        'id': 'sports',
        'name': 'Sports & Outdoors',
        'icon': '⚽',
        'isActive': true,
      },
      {
        'id': 'beauty',
        'name': 'Beauty & Health',
        'icon': '💄',
        'isActive': true,
      },
      {
        'id': 'food',
        'name': 'Food & Beverages',
        'icon': '🍕',
        'isActive': true,
      },
      {
        'id': 'automotive',
        'name': 'Automotive',
        'icon': '🚗',
        'isActive': true,
      },
    ];

    final batch = firestore.batch();

    for (final category in categories) {
      final docRef = firestore
          .collection('categories')
          .doc(category['id'] as String);
      batch.set(docRef, {
        ...category,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    print('✅ Categories seeded');
  }

  Future<void> _seedSampleDeals(FirebaseFirestore firestore) async {
    final now = DateTime.now();
    final sampleDeals = _generateSampleDeals(now);

    final batch = firestore.batch();

    for (final deal in sampleDeals) {
      final docRef = firestore.collection('deals').doc(deal.id);
      batch.set(docRef, {
        ...deal.toJson(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    print('✅ Sample deals seeded (${sampleDeals.length} deals)');
  }

  Future<void> _seedConfiguration(FirebaseFirestore firestore) async {
    final configs = [
      {
        'id': 'app_settings',
        'data': {
          'appName': 'Budget Deals',
          'version': '1.0.0',
          'maxWishlistSize': 100,
          'maxSearchResults': 50,
          'enableNotifications': true,
          'enableAnalytics': true,
          'supportedLocales': ['en'],
          'defaultCurrency': 'USD',
        },
      },
      {
        'id': 'feature_flags',
        'data': {
          'enableSocialLogin': true,
          'enableOfflineMode': true,
          'enablePushNotifications': true,
          'enableAnalytics': true,
          'enableSharing': true,
        },
      },
    ];

    final batch = firestore.batch();

    for (final config in configs) {
      final docRef = firestore.collection('config').doc(config['id'] as String);
      batch.set(docRef, {
        'id': config['id'],
        'data': config['data'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    print('✅ Configuration seeded');
  }

  Future<void> _setDatabaseVersion() async {
    try {
      final firestore = FirebaseService.firestore;
      await firestore.collection('metadata').doc('database').set({
        'version': _version,
        'initializedAt': FieldValue.serverTimestamp(),
        'isInitialized': true,
      });
      print('✅ Database version set: $_version');
    } catch (e) {
      print('⚠️ Could not set database version: $e');
    }
  }

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final firestore = FirebaseService.firestore;

      // Get database version
      final versionDoc = await firestore
          .collection('metadata')
          .doc('database')
          .get();

      // Get collection counts
      final collections = [
        'deals',
        'users',
        'wishlists',
        'categories',
        'analytics',
      ];
      final collectionInfo = <String, dynamic>{};

      for (final collection in collections) {
        try {
          final count = await firestore.collection(collection).count().get();
          collectionInfo[collection] = count.count;
        } catch (e) {
          collectionInfo[collection] = 'unknown';
        }
      }

      return {
        'version': versionDoc.exists
            ? (versionDoc.data()?['version'] ?? 'unknown')
            : 'unknown',
        'initialized':
            versionDoc.exists && (versionDoc.data()?['isInitialized'] == true),
        'collections': collectionInfo,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting database info: $e');
      return {
        'version': 'error',
        'initialized': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  List<Deal> _generateSampleDeals(DateTime now) {
    final categories = [
      'electronics',
      'fashion',
      'home',
      'books',
      'sports',
      'beauty',
      'food',
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

    return List.generate(25, (index) {
      final category = categories[index % categories.length];
      final store = stores[index % stores.length];
      final imageUrl = imageUrls[index % imageUrls.length];
      final originalPrice = (20.0 + (index * 15)).toDouble();
      final discountPercent = 15 + (index % 35); // 15-50% discount
      final discountPrice = originalPrice * (1 - discountPercent / 100);
      final views = 50 + (index * 30);
      final daysLeft = 2 + (index % 25);
      final expiryDate = now.add(Duration(days: daysLeft));

      final rankingScore = Deal.calculateRankingScore(
        discountPercent: discountPercent,
        views: views,
        daysLeft: daysLeft,
      );
      final isHot = discountPercent > 35 || views > 800;
      final isExpiringSoon = daysLeft <= 3;

      return Deal(
        id: 'sample_deal_$index',
        title: _generateTitle(category, index),
        description:
            'Amazing deal on quality products. Limited time offer with free shipping included. Don\'t miss out on this incredible opportunity!',
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
      'electronics': [
        'Wireless Headphones',
        'Smart Watch',
        'Bluetooth Speaker',
        'Phone Case',
        'Tablet Stand',
        'USB Cable',
        'Power Bank',
        'Laptop Sleeve',
      ],
      'fashion': [
        'Designer Jacket',
        'Running Shoes',
        'Denim Jeans',
        'Summer Dress',
        'Leather Belt',
        'Sunglasses',
        'Watch',
        'Handbag',
      ],
      'home': [
        'Coffee Maker',
        'Air Fryer',
        'Vacuum Cleaner',
        'Plant Pot',
        'Throw Pillow',
        'Wall Clock',
        'LED Lamp',
        'Storage Box',
      ],
      'books': [
        'Fiction Novel',
        'Cookbook',
        'Self-Help Book',
        'Tech Manual',
        'Art Book',
        'Biography',
        'Children\'s Book',
        'Travel Guide',
      ],
      'sports': [
        'Yoga Mat',
        'Fitness Tracker',
        'Resistance Bands',
        'Water Bottle',
        'Sports Bag',
        'Jump Rope',
        'Foam Roller',
        'Exercise Ball',
      ],
      'beauty': [
        'Skincare Set',
        'Makeup Palette',
        'Hair Dryer',
        'Face Mask',
        'Perfume',
        'Lipstick',
        'Nail Polish',
        'Body Lotion',
      ],
      'food': [
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
        titles[category] ?? ['Amazing Product', 'Premium Item', 'Best Seller'];
    final suffix = [
      'Premium',
      'Best Quality',
      'Top Choice',
      'Special Edition',
      'Limited Offer',
    ];

    return '${categoryTitles[index % categoryTitles.length]} - ${suffix[index % suffix.length]}';
  }

  Future<void> resetDatabase() async {
    try {
      print('⚠️ Resetting database...');

      final firestore = FirebaseService.firestore;
      final collections = [
        'deals',
        'wishlists',
        'categories',
        'analytics',
        'config',
      ];

      final batch = firestore.batch();

      for (final collection in collections) {
        final snapshot = await firestore.collection(collection).get();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
      print('✅ Database reset completed');

      // Reinitialize after reset
      await initializeDatabase();
    } catch (e) {
      print('❌ Database reset failed: $e');
      rethrow;
    }
  }
}
