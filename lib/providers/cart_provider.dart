import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

/// Represents one item in the shopping cart
/// Shows the product and how many user wants
class _CartLine {
  const _CartLine({required this.product, required this.quantity});

  final Product product; // The product
  final int quantity; // How many user wants

  // Create a copy with some changes
  _CartLine copyWith({Product? product, int? quantity}) {
    return _CartLine(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Manages the shopping cart
/// - Keeps track of items and quantities
/// - Can save/load cart from Firebase so cart is not lost
/// - Tells UI when cart changes
class CartProvider extends ChangeNotifier {
  // Storage for all items in cart (uses productId as key for fast lookup)
  final Map<String, _CartLine> _items = <String, _CartLine>{};

  // Connection to Firebase database
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Current user ID for Firebase operations
  String? _currentUserId;

  // Returns all cart items as a simple map (productId -> quantity)
  Map<String, int> get items => Map<String, int>.fromEntries(
    _items.entries.map(
      (entry) => MapEntry<String, int>(entry.key, entry.value.quantity),
    ),
  );

  // Set the current user for Firebase operations
  void setCurrentUser(String userId) {
    _currentUserId = userId;
  }

  // Get quantity of a specific product in cart
  int quantityFor(String productId) {
    return _items[productId]?.quantity ?? 0;
  }

  // Add product to cart, or increase quantity if already there
  void addProduct(Product product) {
    final _CartLine? existing = _items[product.id];
    if (existing == null) {
      // First time - add with quantity 1
      _items[product.id] = _CartLine(product: product, quantity: 1);
    } else {
      // Already in cart - just increase quantity
      _items[product.id] = existing.copyWith(quantity: existing.quantity + 1);
    }
    notifyListeners(); // Tell UI to update
    _autoSaveCart(); // Auto-save to Firebase
  }

  // Increase quantity of a product
  void increase(Product product) {
    addProduct(product);
  }

  // Decrease quantity, or remove completely if quantity becomes 0
  void decrease(Product product) {
    final int currentQty = _items[product.id]?.quantity ?? 0;
    if (currentQty <= 1) {
      // Remove item completely
      _items.remove(product.id);
    } else {
      // Just decrease quantity
      _items[product.id] = _items[product.id]!.copyWith(
        quantity: currentQty - 1,
      );
    }
    notifyListeners(); // Tell UI to update
    _autoSaveCart(); // Auto-save to Firebase
  }

  // Auto-save cart to Firebase if user is set
  Future<void> _autoSaveCart() async {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      await saveCartToFirestore(_currentUserId!);
    }
  }

  // Remove all items from cart
  void clear() {
    _items.clear();
    notifyListeners(); // Tell UI to update
  }

  // Total count of items (if you have 2 apples and 3 oranges, this is 5)
  int get totalItems {
    // ignore: avoid_types_as_parameter_names
    return _items.values.fold<int>(0, (sum, line) => sum + line.quantity);
  }

  // Total price of all items combined
  double get totalPrice {
    return _items.values.fold<double>(
      0,
      // ignore: avoid_types_as_parameter_names
      (sum, line) => sum + (line.product.price * line.quantity),
    );
  }

  // Get all products in cart as a list
  List<Product> get cartProducts {
    return _items.values.map((line) => line.product).toList(growable: false);
  }

  /// Save cart to Firebase for user (using userId not email)
  /// This way, when user logs in again, their cart is restored
  /// Returns true if saved successfully, false if failed
  Future<bool> saveCartToFirestore(String userId) async {
    if (userId.isEmpty) return false;

    try {
      // Convert cart items to Firebase format with all product data
      final Map<String, dynamic> cartDataForFirebase = {};
      for (final entry in _items.entries) {
        final line = entry.value;
        cartDataForFirebase[entry.key] = {
          'productId': line.product.id,
          'name': line.product.name,
          'price': line.product.price,
          'quantity': line.quantity,
          'imageUrl': line.product.imageUrl,
          'categoryId': line.product.categoryId,
          'unit': line.product.unit,
        };
      }

      // Save to Firebase under user's cart folder
      await _db
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc('items')
          .set({
            'items': cartDataForFirebase,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (error) {
      debugPrint('Error saving cart to Firestore: $error');
      return false;
    }
  }

  /// Load saved cart from Firebase for user (using userId not email)
  /// Restores what was in their cart before they logged out
  /// Returns true if found saved cart, false if not found or failed
  Future<bool> restoreCartFromFirestore(String userId) async {
    if (userId.isEmpty) return false;

    try {
      // Get the saved cart from Firebase
      final DocumentSnapshot savedCartDoc = await _db
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc('items')
          .get();

      // Check if saved cart exists
      if (savedCartDoc.exists) {
        final Map<String, dynamic> cartData =
            savedCartDoc.data() as Map<String, dynamic>;
        final Map<String, dynamic> savedItems = cartData['items'] ?? {};

        // Clear current cart and load saved items
        _items.clear();
        for (final itemEntry in savedItems.entries) {
          try {
            final itemData = itemEntry.value as Map<String, dynamic>;
            final product = Product(
              id: itemData['productId']?.toString() ?? '',
              name: itemData['name']?.toString() ?? '',
              categoryId: itemData['categoryId']?.toString() ?? '',
              rating: 0,
              price: (itemData['price'] as num?)?.toDouble() ?? 0,
              unit: itemData['unit']?.toString() ?? '1 unit',
              imageUrl: itemData['imageUrl']?.toString() ?? '',
              description: '',
              deliveryMinutes: 0,
              section: '',
            );
            final quantity = (itemData['quantity'] as num?)?.toInt() ?? 1;

            _items[itemEntry.key] = _CartLine(
              product: product,
              quantity: quantity,
            );
            debugPrint('Restored item: ${product.name} - Qty: $quantity');
          } catch (e) {
            debugPrint('Error restoring cart item ${itemEntry.key}: $e');
          }
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (error) {
      debugPrint('Error restoring cart from Firestore: $error');
      return false;
    }
  }

  /// Delete saved cart from Firebase for user
  /// Called when user logs out or clears cart permanently
  /// Returns true if deleted successfully, false if failed
  Future<bool> clearCartFromFirestore(String userId) async {
    if (userId.isEmpty) return false;

    try {
      // Delete the saved cart from Firebase
      await _db
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc('items')
          .delete();
      return true;
    } catch (error) {
      debugPrint('Error clearing cart from Firestore: $error');
      return false;
    }
  }
}
