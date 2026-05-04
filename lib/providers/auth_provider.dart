import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';

enum AppRole { guest, customer, admin }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AppRole _role = AppRole.guest;
  User? _firebaseUser;
  AppUser? _currentUser;
  String? _lastError; // Track last error message

  AppRole get role => _role;
  bool get isAdmin => _role == AppRole.admin;
  bool get isCustomer => _role == AppRole.customer;
  bool get isGuest => _role == AppRole.guest;
  bool get isAuthenticated => _firebaseUser != null;
  String get currentEmail => _firebaseUser?.email ?? 'guest@local';
  String get currentUid => _firebaseUser?.uid ?? '';
  AppUser? get currentUser => _currentUser;
  String? get lastError => _lastError; // Expose last error

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

  /// Login with Google Sign-In
  Future<bool> signInWithGoogle() async {
    try {
      _lastError = null; // Clear previous error
      debugPrint('Starting Google Sign-In...');

      // Attempt to get the currently signed-in account
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _lastError = 'Google Sign-In cancelled by user';
        debugPrint(_lastError);
        notifyListeners();
        return false;
      }

      debugPrint('Google Sign-In successful: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null) {
        _lastError =
            'Failed to obtain Google authentication token. Please try again.';
        debugPrint(_lastError);
        notifyListeners();
        return false;
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth
          .signInWithCredential(credential)
          .timeout(const Duration(seconds: 10));

      _firebaseUser = userCredential.user;
      if (_firebaseUser == null) {
        _lastError = 'Firebase user creation failed. Please try again.';
        debugPrint(_lastError);
        notifyListeners();
        return false;
      }

      // Save or update user in Firestore
      await _saveGoogleUserToFirestore(
        uid: _firebaseUser!.uid,
        email: _firebaseUser!.email ?? '',
        name: _firebaseUser!.displayName ?? 'User',
        photoUrl: _firebaseUser!.photoURL,
      );

      _role = AppRole.customer;
      await _fetchCurrentUser();
      _lastError = null; // Clear error on success
      notifyListeners();

      debugPrint('Google Sign-In completed successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      _lastError = _getFirebaseErrorMessage(e.code, e.message);
      debugPrint(
        'signInWithGoogle FirebaseAuthException: ${e.code} - ${e.message}',
      );
      _firebaseUser = null;
      notifyListeners();
      return false;
    } on Exception catch (e) {
      String err = e.toString();
      if (err.contains('sign_in_failed') || err.contains('7')) {
        _lastError =
            'Google Sign-In failed (Error 7). This usually means your digital signature (SHA-1) is not registered in Firebase Console.';
      } else if (err.contains('network_error')) {
        _lastError = 'Network error. Please check your internet connection.';
      } else {
        _lastError = _getGenericErrorMessage(err);
      }
      debugPrint('signInWithGoogle Exception: $e');
      _firebaseUser = null;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = _getGenericErrorMessage(e.toString());
      debugPrint('signInWithGoogle error: $e');
      _firebaseUser = null;
      notifyListeners();
      return false;
    }
  }

  /// Get user-friendly Firebase error message
  String _getFirebaseErrorMessage(String code, String? message) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This email is already registered with a different login method.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled. Please contact support.';
      case 'user-disabled':
        return 'Your account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'User not found.';
      case 'wrong-password':
        return 'Wrong password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return message ?? 'Sign-in failed. Please try again.';
    }
  }

  /// Get user-friendly error message from generic exception
  String _getGenericErrorMessage(String errorString) {
    if (errorString.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorString.contains('timeout')) {
      return 'Connection timed out. Please try again.';
    } else if (errorString.contains('cancelled') ||
        errorString.contains('CANCELLED')) {
      return 'Sign-in cancelled.';
    } else if (errorString.contains('sign_in_cancelled')) {
      return 'Sign-in cancelled by user.';
    }
    return 'An error occurred during sign-in. Please try again.';
  }

  /// Save Google user data to Firestore
  Future<void> _saveGoogleUserToFirestore({
    required String uid,
    required String email,
    required String name,
    String? photoUrl,
  }) async {
    try {
      final DocumentSnapshot userDoc = await _db
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (userDoc.exists) {
        // User already exists, update last login
        await _db.collection('users').doc(uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        // New user, create document
        await _db.collection('users').doc(uid).set({
          'name': name.trim(),
          'email': email.toLowerCase().trim(),
          'photoUrl': photoUrl ?? '',
          'phone': '',
          'address': '',
          'isAdmin': false,
          'isBlocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('User data saved to Firestore: $email');
    } catch (e) {
      debugPrint('Error saving Google user to Firestore: $e');
      rethrow;
    }
  }

  /// Sign out from Google and Firebase
  Future<void> signOutGoogle() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _firebaseUser = null;
      _currentUser = null;
      _role = AppRole.guest;
      notifyListeners();
      debugPrint('Google Sign-Out completed');
    } catch (e) {
      debugPrint('Error signing out from Google: $e');
    }
  }

  /// Check if user is signed in with Google
  bool get isSignedInWithGoogle {
    return _firebaseUser != null && _firebaseUser!.isAnonymous == false;
  }

  /// Register with Google Sign-In
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
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _firebaseUser = null;
      _currentUser = null;
      _role = AppRole.guest;
      notifyListeners();
      debugPrint('Logout completed');
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }
}
