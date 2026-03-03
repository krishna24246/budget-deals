import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../firebase_options.dart';
import 'notification_service.dart';

/// Centralized application initialization service
/// This service ensures Firebase is initialized exactly once and coordinates all initialization
class AppInitializationService {
  static final AppInitializationService _instance =
      AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  static bool _isFirebaseInitialized = false;
  static bool _isInitializing = false;
  static String? _initializationError;
  static DateTime? _initializationTime;

  /// Get initialization status
  static bool get isFirebaseInitialized => _isFirebaseInitialized;
  static bool get isInitializing => _isInitializing;
  static String? get initializationError => _initializationError;
  static DateTime? get initializationTime => _initializationTime;

  /// Initialize Firebase - this should be called exactly once in the app
  static Future<void> initializeFirebase() async {
    if (_isFirebaseInitialized) {
      print('ℹ️ Firebase already initialized, skipping...');
      return;
    }

    if (_isInitializing) {
      print('🔄 Firebase initialization already in progress, waiting...');
      // Wait for ongoing initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    print('🚀 Starting Firebase initialization...');
    _isInitializing = true;
    _initializationError = null;

    try {
      // Check if Firebase app already exists
      try {
        Firebase.app();
        print('⚠️ Firebase app already exists, using existing instance');
        _isFirebaseInitialized = true;
        _initializationTime = DateTime.now();
      } catch (e) {
        // Firebase app doesn't exist, initialize it
        print(
          '🔄 No existing Firebase app found, initializing new instance...',
        );

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        _isFirebaseInitialized = true;
        _initializationTime = DateTime.now();
        print(
          '✅ Firebase initialized successfully for ${kIsWeb ? 'web' : Platform.operatingSystem}',
        );

        // Initialize notification service
        try {
          await NotificationService().initialize();
          print('✅ Notification service initialized successfully');
        } catch (e) {
          print('⚠️ Notification service initialization failed: $e');
          // Don't fail the whole initialization for notification issues
        }
      }
    } catch (e) {
      _initializationError = e.toString();
      print('❌ Firebase initialization failed: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Get Firebase app instance (ensures Firebase is initialized)
  static FirebaseApp get firebaseApp {
    if (!_isFirebaseInitialized) {
      throw Exception(
        'Firebase not initialized. Call AppInitializationService.initializeFirebase() first.',
      );
    }
    return Firebase.app();
  }

  /// Get comprehensive initialization status
  static Map<String, dynamic> getInitializationStatus() {
    return {
      'firebaseInitialized': _isFirebaseInitialized,
      'isInitializing': _isInitializing,
      'hasError': _initializationError != null,
      'error': _initializationError,
      'initializationTime': _initializationTime?.toIso8601String(),
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    };
  }

  /// Reset initialization state (for testing purposes)
  static void reset() {
    _isFirebaseInitialized = false;
    _isInitializing = false;
    _initializationError = null;
    _initializationTime = null;
    print('🔄 AppInitializationService state reset');
  }

  /// Wait for Firebase initialization to complete
  static Future<void> waitForInitialization() async {
    if (_isFirebaseInitialized) return;

    print('⏳ Waiting for Firebase initialization to complete...');
    while (_isInitializing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!_isFirebaseInitialized) {
      throw Exception('Firebase initialization failed: $_initializationError');
    }
    print('✅ Firebase initialization completed');
  }
}
