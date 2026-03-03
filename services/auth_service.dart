import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool isAdmin;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.isAdmin = false,
  });

  // Create AppUser from Firebase Auth User
  factory AppUser.fromFirebaseUser(User firebaseUser, {bool isAdmin = false}) {
    return AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? 'User',
      photoUrl: firebaseUser.photoURL,
      isAdmin: isAdmin,
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
      'lastLogin': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Create AppUser from Firestore document
  factory AppUser.fromFirestore(Map<String, dynamic> doc) {
    return AppUser(
      uid: doc['uid'] ?? '',
      email: doc['email'] ?? '',
      displayName: doc['displayName'] ?? 'User',
      photoUrl: doc['photoUrl'],
      isAdmin: doc['isAdmin'] ?? false,
    );
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AppUser? _currentUser;
  bool _isLoggedIn = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
  );

  Stream<User?> get authStateChanges => FirebaseService.auth.authStateChanges();

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;

  Future<bool> isUserLoggedIn() async {
    try {
      // Check Firebase Auth current user
      final firebaseUser = FirebaseService.auth.currentUser;
      if (firebaseUser != null) {
        // Get user data from Firestore
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

  Future<AppUser?> signInWithGoogle() async {
    try {
      // Check if Firebase is initialized
      if (!FirebaseService.isInitialized) {
        throw Exception('Firebase not initialized');
      }

      print('🔄 Starting Google Sign-In process...');

      // Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        print('❌ User cancelled Google Sign-In');
        return null;
      }

      print('✅ Google account selected: ${googleUser.email}');

      // Get Google Sign-In authentication
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Check if we have the required tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('❌ Missing authentication tokens');
        throw Exception('Failed to obtain authentication tokens');
      }

      print('✅ Authentication tokens obtained');

      // Create Firebase credentials
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      final UserCredential result = await FirebaseService.auth
          .signInWithCredential(credential);
      final User? firebaseUser = result.user;

      if (firebaseUser != null) {
        print('✅ Firebase authentication successful: ${firebaseUser.email}');

        // Create our AppUser model
        final user = AppUser.fromFirebaseUser(firebaseUser);

        // Check if user is admin (you can customize this logic)
        final isAdmin = await _checkAdminStatus(firebaseUser.uid);
        final userWithAdminStatus = AppUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
          isAdmin: isAdmin,
        );

        // Create or update user document in Firestore
        await _createOrUpdateUserDocument(userWithAdminStatus);

        _currentUser = userWithAdminStatus;
        _isLoggedIn = true;

        print('✅ User signed in successfully: ${user.displayName}');
        return userWithAdminStatus;
      }

      print('❌ Firebase user is null');
      return null;
    } catch (e) {
      print('❌ Error signing in with Google: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      // Sign out from Google Sign-In
      await _googleSignIn.signOut();

      // Sign out from Firebase Auth
      await FirebaseService.auth.signOut();

      // Clear local user state
      _currentUser = null;
      _isLoggedIn = false;

      print('✅ User signed out successfully');
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final firebaseUser = FirebaseService.auth.currentUser;
      if (firebaseUser != null) {
        // Delete user account from Firebase Auth
        await firebaseUser.delete();

        // Delete user document from Firestore
        await FirebaseService.firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .delete();

        // Sign out
        await signOut();

        print('✅ User account deleted successfully');
      }
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }

  Future<void> _createOrUpdateUserDocument(AppUser user) async {
    try {
      final usersCollection = FirebaseService.firestore.collection('users');
      final userDoc = usersCollection.doc(user.uid);

      await userDoc.set(user.toFirestore(), SetOptions(merge: true));

      print('✅ User document created/updated in Firestore');
    } catch (e) {
      print('Error creating user document: $e');
      // Don't throw - user document creation is not critical
    }
  }

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

  Future<void> _updateLastLogin(String uid) async {
    try {
      await FirebaseService.firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login: $e');
      // Don't throw - this is not critical
    }
  }

  Future<bool> _checkAdminStatus(String uid) async {
    try {
      // Check if user is in admin collection or has admin flag
      final adminDoc = await FirebaseService.firestore
          .collection('admins')
          .doc(uid)
          .get();
      if (adminDoc.exists) {
        return true;
      }

      // Check user's document for admin flag
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

  Future<void> makeUserAdmin(String uid) async {
    try {
      // Add user to admin collection
      await FirebaseService.firestore.collection('admins').doc(uid).set({
        'uid': uid,
        'grantedAt': FieldValue.serverTimestamp(),
        'grantedBy': 'system', // You might want to track who granted admin
      });

      // Update user's admin flag
      await FirebaseService.firestore.collection('users').doc(uid).update({
        'isAdmin': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ User $uid granted admin access');
    } catch (e) {
      print('Error granting admin access: $e');
      rethrow;
    }
  }

  Future<void> revokeAdminAccess(String uid) async {
    try {
      // Remove from admin collection
      await FirebaseService.firestore.collection('admins').doc(uid).delete();

      // Update user's admin flag
      await FirebaseService.firestore.collection('users').doc(uid).update({
        'isAdmin': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Admin access revoked for user $uid');
    } catch (e) {
      print('Error revoking admin access: $e');
      rethrow;
    }
  }

  // Initialize auth state listener
  void initializeAuthListener() {
    FirebaseService.auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        // Get our AppUser model from Firestore
        final user = await _getUserFromFirestore(firebaseUser.uid);
        if (user != null) {
          _currentUser = user;
          _isLoggedIn = true;
          print('🔄 Auth state changed: User logged in - ${user.displayName}');
        }
      } else {
        _currentUser = null;
        _isLoggedIn = false;
        print('🔄 Auth state changed: User logged out');
      }
    });
  }
}
