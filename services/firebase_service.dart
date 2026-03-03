import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_initialization_service.dart';

/// Firebase service that uses the centralized initialization system
/// This ensures Firebase is initialized exactly once and coordinates all Firebase operations
class FirebaseService {
  static FirebaseFirestore? _firestore;
  static FirebaseAuth? _auth;

  /// Initialize Firebase service - delegates to AppInitializationService
  static Future<void> initialize() async {
    await AppInitializationService.initializeFirebase();
    print('✅ FirebaseService ready to use');
  }

  /// Check if Firebase is initialized
  static bool get isInitialized => AppInitializationService.isFirebaseInitialized;

  /// Firestore instance with initialization check
  static FirebaseFirestore get firestore {
    if (!AppInitializationService.isFirebaseInitialized) {
      throw Exception('Firebase not initialized. Call FirebaseService.initialize() first.');
    }
    if (_firestore == null) {
      _firestore = FirebaseFirestore.instance;
    }
    return _firestore!;
  }

  /// Auth instance with initialization check
  static FirebaseAuth get auth {
    if (!AppInitializationService.isFirebaseInitialized) {
      throw Exception('Firebase not initialized. Call FirebaseService.initialize() first.');
    }
    if (_auth == null) {
      _auth = FirebaseAuth.instance;
    }
    return _auth!;
  }

  /// Get comprehensive Firebase service status
  static Map<String, dynamic> getServiceStatus() {
    return {
      'firebaseInitialized': AppInitializationService.isFirebaseInitialized,
      'isInitializing': AppInitializationService.isInitializing,
      'hasError': AppInitializationService.initializationError != null,
      'error': AppInitializationService.initializationError,
      'initializationTime': AppInitializationService.initializationTime?.toIso8601String(),
      'firestoreAvailable': _firestore != null,
      'authAvailable': _auth != null,
    };
  }

  /// Get Firebase app instance
  static FirebaseApp get firebaseApp {
    return AppInitializationService.firebaseApp;
  }

  /// Wait for Firebase initialization to complete
  static Future<void> waitForInitialization() async {
    await AppInitializationService.waitForInitialization();
  }

  /// Reset Firebase service state (for testing purposes)
  static void reset() {
    _firestore = null;
    _auth = null;
    AppInitializationService.reset();
    print('🔄 FirebaseService state reset');
  }

  /// Get Firebase configuration info (without sensitive data)
  static Map<String, dynamic> getFirebaseConfig() {
    return {
      'platform': firebaseApp.options.projectId,
      'firebaseProjectId': firebaseApp.options.projectId,
      'firebaseOptions': {
        'apiKey': '***', // Hidden for security
        'projectId': firebaseApp.options.projectId,
        'appId': firebaseApp.options.appId,
        'databaseURL': firebaseApp.options.databaseURL?.isNotEmpty == true ? 'configured' : 'not configured',
        'storageBucket': firebaseApp.options.storageBucket?.isNotEmpty == true ? 'configured' : 'not configured',
      },
    };
  }
}
