import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Cross-platform AppUser model
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isAdmin;
  final String platform; // android, web, ios

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.isAdmin = false,
    this.platform = 'unknown',
  });

  // Create AppUser from Firebase Auth User
  factory AppUser.fromFirebaseUser(
    User firebaseUser, {
    bool isAdmin = false,
    String platform = 'unknown',
  }) {
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? 'User',
      photoUrl:
          firebaseUser.photoURL ??
          'https://lh3.googleusercontent.com/a/default-user=s64',
      isAdmin: isAdmin,
      platform: platform,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isAdmin': isAdmin,
      'platform': platform,
      'lastLogin': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create AppUser from Firestore document
  factory AppUser.fromFirestore(Map<String, dynamic> doc) {
    return AppUser(
      uid: doc['uid'],
      email: doc['email'],
      displayName: doc['displayName'],
      photoUrl: doc['photoUrl'],
      isAdmin: doc['isAdmin'] ?? false,
      platform: doc['platform'] ?? 'unknown',
    );
  }
}

/// Platform detection utility
class PlatformUtils {
  static bool get isWeb => kIsWeb;
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isMobile => !kIsWeb && (isAndroid || isIOS);

  static String get currentPlatform {
    if (kIsWeb) return 'web';
    if (isAndroid) return 'android';
    if (isIOS) return 'ios';
    return 'unknown';
  }
}

/// Cross-platform Authentication Service
class CrossPlatformAuthService {
  static final CrossPlatformAuthService _instance =
      CrossPlatformAuthService._internal();
  factory CrossPlatformAuthService() => _instance;
  CrossPlatformAuthService._internal();

  AppUser? _currentUser;
  bool _isLoggedIn = false;

  // Platform-specific Google Sign-In instances
  GoogleSignIn? _androidSignIn;
  GoogleSignIn? _iOSSignIn;

  // Firebase Auth for Web
  FirebaseAuth? _firebaseAuth;

  Stream<User?> get authStateChanges => FirebaseService.auth.authStateChanges();

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String get currentPlatform => PlatformUtils.currentPlatform;

  /// Initialize authentication service
  Future<void> initialize() async {
    try {
      if (!FirebaseService.isInitialized) {
        throw Exception('Firebase not initialized');
      }

      // Initialize platform-specific instances
      if (PlatformUtils.isMobile) {
        _initializeMobileSignIn();
      } else if (PlatformUtils.isWeb) {
        _initializeWebAuth();
      }

      // Start listening to auth state changes
      _initializeAuthListener();

      print(
        '✅ CrossPlatformAuthService initialized for platform: $currentPlatform',
      );
    } catch (e) {
      print('❌ Error initializing CrossPlatformAuthService: $e');
      rethrow;
    }
  }

  /// Initialize mobile Google Sign-In (Android & iOS)
  void _initializeMobileSignIn() {
    if (PlatformUtils.isAndroid) {
      _androidSignIn = GoogleSignIn(scopes: ['email', 'profile', 'openid']);
    } else if (PlatformUtils.isIOS) {
      _iOSSignIn = GoogleSignIn(scopes: ['email', 'profile', 'openid']);
    }
  }

  /// Initialize Web Firebase Auth
  void _initializeWebAuth() {
    _firebaseAuth = FirebaseService.auth;
  }

  /// Initialize auth state listener
  void _initializeAuthListener() {
    FirebaseService.auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        final user = await _getUserFromFirestore(firebaseUser.uid);
        if (user != null) {
          _currentUser = user;
          _isLoggedIn = true;
          print(
            '🔄 Auth state changed: User logged in - ${user.displayName} ($currentPlatform)',
          );
        }
      } else {
        _currentUser = null;
        _isLoggedIn = false;
        print('🔄 Auth state changed: User logged out');
      }
    });
  }

  /// Sign in with Google (cross-platform)
  Future<AppUser?> signInWithGoogle() async {
    try {
      if (!FirebaseService.isInitialized) {
        throw Exception('Firebase not initialized');
      }

      print('🔄 Starting Google Sign-In process for $currentPlatform...');

      UserCredential? result;

      if (PlatformUtils.isWeb) {
        // Web: Use Firebase Auth with Google provider
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');

        result = await FirebaseService.auth.signInWithPopup(provider);
      } else if (PlatformUtils.isAndroid && _androidSignIn != null) {
        // Android: Use Google Sign-In
        print('📱 Attempting Google Sign-In on Android...');
        final googleUser = await _androidSignIn!.signIn();
        print('👤 Google user result: ${googleUser?.email ?? 'null'}');

        if (googleUser != null) {
          print('🔑 Getting authentication tokens...');
          final googleAuth = await googleUser.authentication;
          print(
            '✅ Tokens obtained: access=${googleAuth.accessToken != null}, id=${googleAuth.idToken != null}',
          );

          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          print('🔐 Creating Firebase credential...');
          result = await FirebaseService.auth.signInWithCredential(credential);
          print('🎉 Firebase sign-in result: ${result?.user?.email ?? 'null'}');
        } else {
          print('❌ Google Sign-In returned null user');
          return null; // User cancelled
        }
      } else if (PlatformUtils.isIOS && _iOSSignIn != null) {
        // iOS: Use Google Sign-In
        final googleUser = await _iOSSignIn!.signIn();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          result = await FirebaseService.auth.signInWithCredential(credential);
        }
      } else {
        throw Exception('Platform not supported: $currentPlatform');
      }

      if (result != null && result.user != null) {
        final firebaseUser = result.user!;
        print('✅ Google authentication successful: ${firebaseUser.email}');

        final user = AppUser.fromFirebaseUser(
          firebaseUser,
          isAdmin: false,
          platform: currentPlatform,
        );

        final isAdmin = await _checkAdminStatus(firebaseUser.uid);
        final userWithAdminStatus = AppUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
          isAdmin: isAdmin,
          platform: currentPlatform,
        );

        await _createOrUpdateUserDocument(userWithAdminStatus);

        _currentUser = userWithAdminStatus;
        _isLoggedIn = true;

        print(
          '✅ User signed in successfully: ${user.displayName} on $currentPlatform',
        );
        return userWithAdminStatus;
      }

      print('❌ Firebase sign-in result was null');
      return null;
    } catch (e, stackTrace) {
      print('❌ Error signing in with Google: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow; // Re-throw so the UI can show the actual error
    }
  }

  /// Sign out (cross-platform)
  Future<void> signOut() async {
    try {
      if (PlatformUtils.isWeb) {
        await FirebaseService.auth.signOut();
      } else if (PlatformUtils.isAndroid && _androidSignIn != null) {
        await _androidSignIn!.signOut();
        await FirebaseService.auth.signOut();
      } else if (PlatformUtils.isIOS && _iOSSignIn != null) {
        await _iOSSignIn!.signOut();
        await FirebaseService.auth.signOut();
      }

      _currentUser = null;
      _isLoggedIn = false;

      print('✅ User signed out successfully from $currentPlatform');
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    try {
      final firebaseUser = FirebaseService.auth.currentUser;
      if (firebaseUser != null) {
        final user = await _getUserFromFirestore(firebaseUser.uid);
        _currentUser = user;
        _isLoggedIn = true;
        return true;
      }

      _currentUser = null;
      _isLoggedIn = false;
      return false;
    } catch (e) {
      print('Error checking login status: $e');
      _currentUser = null;
      _isLoggedIn = false;
      return false;
    }
  }

  /// Create or update user document in Firestore
  Future<void> _createOrUpdateUserDocument(AppUser user) async {
    try {
      final usersCollection = FirebaseService.firestore.collection('users');
      final userDoc = usersCollection.doc(user.uid);

      await userDoc.set(user.toFirestore(), SetOptions(merge: true));

      print(
        '✅ User document created/updated in Firestore for $currentPlatform',
      );
    } catch (e) {
      print('Error creating user document: $e');
    }
  }

  /// Get user from Firestore
  Future<AppUser?> _getUserFromFirestore(String uid) async {
    try {
      final userDoc = await FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final user = AppUser.fromFirestore(userData);

        // Update last login timestamp
        await _updateLastLogin(uid);

        return user;
      }

      return null;
    } catch (e) {
      print('Error fetching user from Firestore: $e');
      return null;
    }
  }

  /// Update last login timestamp
  Future<void> _updateLastLogin(String uid) async {
    try {
      await FirebaseService.firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  /// Check admin status
  Future<bool> _checkAdminStatus(String uid) async {
    try {
      final adminDoc = await FirebaseService.firestore
          .collection('admins')
          .doc(uid)
          .get();
      if (adminDoc.exists) {
        return true;
      }

      final userDoc = await FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return userData['isAdmin'] ?? false;
      }

      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// Get platform-specific authentication info
  Map<String, dynamic> getAuthInfo() {
    return {
      'platform': currentPlatform,
      'isLoggedIn': _isLoggedIn,
      'user': _currentUser?.toFirestore(),
      'firebaseInitialized': FirebaseService.isInitialized,
      'googleSignInAvailable': PlatformUtils.isMobile,
      'webAuthAvailable': PlatformUtils.isWeb,
    };
  }

  /// Refresh current user data from Firestore
  Future<void> refreshCurrentUser() async {
    if (_currentUser != null) {
      final updatedUser = await _getUserFromFirestore(_currentUser!.uid);
      if (updatedUser != null) {
        _currentUser = updatedUser;
      }
    }
  }

  /// Get supported authentication providers
  List<String> getSupportedProviders() {
    final providers = ['google'];
    if (PlatformUtils.isWeb) {
      providers.add('email');
      providers.add('phone');
    }
    return providers;
  }
}
