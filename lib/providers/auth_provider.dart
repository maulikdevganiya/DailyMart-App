import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

enum AppRole { guest, customer, admin }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppRole _role = AppRole.guest;
  User? _firebaseUser;
  AppUser? _currentUser;

  AppRole get role => _role;
  bool get isAdmin => _role == AppRole.admin;
  bool get isCustomer => _role == AppRole.customer;
  bool get isGuest => _role == AppRole.guest;
  bool get isAuthenticated => _firebaseUser != null;
  String get currentEmail => _firebaseUser?.email ?? 'guest@local';
  String get currentUid => _firebaseUser?.uid ?? '';
  AppUser? get currentUser => _currentUser;

  /// Restore the persisted Firebase session after app launch.
  Future<void> restoreSession() async {
    final User? savedUser = _auth.currentUser;
    if (savedUser == null) {
      _firebaseUser = null;
      _currentUser = null;
      _role = AppRole.guest;
      notifyListeners();
      return;
    }

    _firebaseUser = savedUser;
    _currentUser = null;

    try {
      final DocumentSnapshot userDoc = await _db
          .collection('users')
          .doc(savedUser.uid)
          .get();
      if (userDoc.exists) {
        final Map<String, dynamic> data =
            userDoc.data() as Map<String, dynamic>;
        _currentUser = AppUser.fromMap(userDoc.id, data);
        _role = data['isAdmin'] == true ? AppRole.admin : AppRole.customer;
      } else {
        _role = AppRole.customer;
      }
    } catch (_) {
      _role = AppRole.customer;
    }

    notifyListeners();
  }

  /// Check Firebase Auth state for persisting login sessions
  Future<void> checkAuthState() async {
    _firebaseUser = _auth.currentUser;
    if (_firebaseUser != null) {
      try {
        final DocumentSnapshot userDoc = await _db
            .collection('users')
            .doc(_firebaseUser!.uid)
            .get()
            .timeout(const Duration(seconds: 5));

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          if (data != null) {
            // Load the AppUser so profile screen has data
            _currentUser = AppUser.fromMap(_firebaseUser!.uid, data);
            _role = data['isAdmin'] == true ? AppRole.admin : AppRole.customer;
          } else {
            _role = AppRole.customer;
          }
        } else {
          _role = AppRole.customer;
        }
      } catch (_) {
        _role = AppRole.customer;
      }
    } else {
      _role = AppRole.guest;
    }
    notifyListeners();
  }

  /// Login existing customer with Firebase Auth
  Future<bool> loginCustomer({
    required String email,
    required String password,
  }) async {
    try {
      // If already signed in (e.g. from a prior loginAdmin attempt that
      // found the user is not an admin), reuse the active session.
      if (_firebaseUser != null) {
        _role = AppRole.customer;
        await _fetchCurrentUser();
        notifyListeners();
        return true;
      }

      // Sign in with a timeout to avoid indefinite waits
      final UserCredential credential = await _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          )
          .timeout(const Duration(seconds: 10));
      _firebaseUser = credential.user;
      _role = AppRole.customer;
      await _fetchCurrentUser();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('loginCustomer FirebaseAuthException: ${e.code}');
      return false;
    } on Exception catch (e) {
      // Handle timeout or other exceptions from signIn
      debugPrint('loginCustomer error/timeout: $e');
      return false;
    } catch (e) {
      debugPrint('loginCustomer error: $e');
      return false;
    }
  }

  /// Login as admin — checks Firestore 'users' doc for isAdmin flag
  Future<bool> loginAdmin({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with a timeout so admin login doesn't hang indefinitely
      final UserCredential credential = await _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          )
          .timeout(const Duration(seconds: 10));
      _firebaseUser = credential.user;

      // Check if user has admin role in Firestore
      final DocumentSnapshot userDoc = await _db
          .collection('users')
          .doc(credential.user!.uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data['isAdmin'] == true) {
          _role = AppRole.admin;
          await _fetchCurrentUser();
          notifyListeners();
          return true;
        }
      }

      // Not an admin — keep the Firebase session alive so loginCustomer
      // can reuse it without a redundant sign-in call.
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint('loginAdmin FirebaseAuthException: ${e.code}');
      _firebaseUser = null;
      return false;
    } catch (e) {
      debugPrint('loginAdmin error: $e');
      _firebaseUser = null;
      return false;
    }
  }

  /// Register new customer with Firebase Auth + save profile to Firestore
  Future<bool> registerCustomer({
    required String name,
    required String email,
    required String password,
    String phone = '',
    String address = '',
  }) async {
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      // Save user profile to Firestore 'users' collection
      await _db.collection('users').doc(credential.user!.uid).set({
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'address': address.trim(),
        'isBlocked': false,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _firebaseUser = credential.user;
      _role = AppRole.customer;
      await _fetchCurrentUser();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'registerCustomer FirebaseAuthException: ${e.code} - ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('registerCustomer error: $e');
      return false;
    }
  }

  /// Fetch current user data from Firestore
  Future<void> _fetchCurrentUser() async {
    if (_firebaseUser == null) return;
    try {
      final DocumentSnapshot userDoc = await _db
          .collection('users')
          .doc(_firebaseUser!.uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (userDoc.exists) {
        _currentUser = AppUser.fromMap(
          userDoc.id,
          userDoc.data() as Map<String, dynamic>,
        );
      }
    } on Exception catch (e) {
      // Timeout or other error - don't block the login flow
      debugPrint('[_fetchCurrentUser] failed: $e');
      _currentUser = null;
    }
  }

  /// Fetch current user data from Firestore (public method)
  Future<void> fetchCurrentUser() async {
    await _fetchCurrentUser();
    notifyListeners();
  }

  Future<bool> updateCurrentUserProfile({
    required String name,
    required String phone,
    required String address,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) return false;

    try {
      final Map<String, dynamic> updates = {
        'name': name.trim(),
        'phone': phone.trim(),
        'address': address.trim(),
      };

      await _db.collection('users').doc(user.uid).update(updates);

      _currentUser =
          (_currentUser ??
                  AppUser(id: user.uid, name: '', email: user.email ?? ''))
              .copyWith(
                name: name.trim(),
                phone: phone.trim(),
                address: address.trim(),
              );
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void continueAsGuest() {
    _role = AppRole.guest;
    _firebaseUser = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.signOut();
    _firebaseUser = null;
    _currentUser = null;
    _role = AppRole.guest;
    notifyListeners();
  }
}
