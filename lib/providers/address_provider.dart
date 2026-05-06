import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/address_model.dart';
import '../models/app_user.dart';

class AddressProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<Address> _addresses = [];
  Address? _selectedAddress;
  String _selectedAddressText = '';
  String _selectedLabel = 'Home';
  String? _syncedUserId;
  bool _isLoading = false; // FIX #5: Added loading state
  String? _error; // FIX #4: Added error state

  List<Address> get addresses => List.unmodifiable(_addresses);
  Address? get selectedAddress => _selectedAddress;
  String get selectedAddressText => _selectedAddressText;
  String get selectedLabel => _selectedLabel;
  bool get hasSelectedAddressText => _selectedAddressText.trim().isNotEmpty;
  bool get isLoading => _isLoading; // FIX #5: Expose loading state
  String? get error => _error; // FIX #4: Expose error state

  // ─────────────────────────────────────────────
  // FETCH
  // ─────────────────────────────────────────────

  Future<void> fetchAddresses(String userId) async {
    if (userId.isEmpty) return;

    // FIX #5: Set loading true before async work
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .get();

      _addresses = snapshot.docs
          .map((doc) => Address.fromMap(doc.id, doc.data()))
          .toList();

      // FIX #6: Keep _syncedUserId in sync when fetching
      _syncedUserId = userId;

      if (_addresses.isNotEmpty) {
        _selectedAddress = _addresses.firstWhere(
          (address) => address.isDefault,
          orElse: () => _addresses.first,
        );
        _selectedAddressText = _selectedAddress!.fullAddress;
        _selectedLabel = _selectedAddress!.label;
      } else {
        _selectedAddress = null;
        _selectedAddressText = '';
        _selectedLabel = 'Home';
      }
    } catch (e) {
      // FIX #4: Catch and expose Firestore errors instead of silent failure
      _error = 'Failed to fetch addresses: ${e.toString()}';
      debugPrint(_error);
    } finally {
      // FIX #5: Always reset loading state
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // ADD
  // ─────────────────────────────────────────────

  Future<void> addAddress(String userId, Address address) async {
    if (userId.isEmpty) {
      throw Exception('User not authenticated');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final docRef = await _db
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .add(address.toMap());

      final newAddress = address.copyWith(id: docRef.id);
      _addresses.add(newAddress);

      // FIX #1 + #2: Replaced broken reference equality check.
      // Now correctly selects the new address if:
      //   - No address was selected yet (first address), OR
      //   - The new address is explicitly marked as default
      if (_selectedAddress == null || newAddress.isDefault) {
        _selectedAddress = newAddress;
        _selectedAddressText = newAddress.fullAddress;
        _selectedLabel = newAddress.label;
      }
    } catch (e) {
      // FIX #4: Surface Firestore write errors
      _error = 'Failed to add address: ${e.toString()}';
      debugPrint(_error);
      rethrow; // Re-throw so the UI can react if needed
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────

  Future<void> deleteAddress(String userId, String addressId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .doc(addressId)
          .delete();

      _addresses.removeWhere((address) => address.id == addressId);

      if (_selectedAddress?.id == addressId) {
        // FIX: Prefer default address when selected one is deleted
        _selectedAddress = _addresses.isNotEmpty
            ? _addresses.firstWhere(
                (a) => a.isDefault,
                orElse: () => _addresses.first,
              )
            : null;
        _selectedAddressText = _selectedAddress?.fullAddress ?? '';
        _selectedLabel = _selectedAddress?.label ?? 'Home';
      }
    } catch (e) {
      // FIX #4: Surface Firestore delete errors
      _error = 'Failed to delete address: ${e.toString()}';
      debugPrint(_error);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // SELECT
  // ─────────────────────────────────────────────

  void selectAddress(Address address) {
    _selectedAddress = address;
    _selectedAddressText = address.fullAddress;
    _selectedLabel = address.label;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // SYNC FROM USER
  // ─────────────────────────────────────────────

  void syncFromUser(AppUser? user) {
    if (user == null) {
      clear();
      return;
    }

    // FIX #3: Guard now also protects a manually selected address.
    // Only sync from AppUser if:
    //   - This is a different user, OR
    //   - We have no address at all yet (both text and list are empty)
    final bool isNewUser = _syncedUserId != user.id;
    final bool hasNoAddressData =
        _selectedAddressText.trim().isEmpty && _addresses.isEmpty;

    if (!isNewUser && !hasNoAddressData) {
      return;
    }

    _syncedUserId = user.id;

    // Only overwrite the text if we have no Firestore addresses loaded yet.
    // Once fetchAddresses() runs, it will set proper address data.
    if (_addresses.isEmpty) {
      _selectedAddressText = user.address.trim();
      _selectedLabel = _selectedAddressText.isEmpty ? 'Home' : 'Saved Address';
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  void setSelectedAddressText(String address, {String? label}) {
    _selectedAddressText = address.trim();
    _selectedLabel =
        label ?? (_selectedAddressText.isEmpty ? 'Home' : 'Saved Address');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clear() {
    _addresses = [];
    _selectedAddress = null;
    _selectedAddressText = '';
    _selectedLabel = 'Home';
    _syncedUserId = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
