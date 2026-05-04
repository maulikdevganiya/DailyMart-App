import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_order.dart';
import '../models/product.dart';

class OrdersProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<AdminOrder> _orders = [];

  static const List<String> statuses = <String>[
    'Placed',
    'Packed',
    'Out for Delivery',
    'Delivered',
    'Cancelled',
  ];

  List<AdminOrder> get orders => List<AdminOrder>.unmodifiable(_orders);

  int get ordersToday => _orders.length;

  double get revenueToday => _orders
      .where((order) => order.status != 'Cancelled')
      .fold<double>(0, (s, order) => s + order.amount);

  /// Fetch orders by userId (not email) from Firestore
  Future<List<AdminOrder>> fetchUserOrders(String userId) async {
    if (userId.isEmpty) return [];

    try {
      final QuerySnapshot snapshot = await _db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) =>
                AdminOrder.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching user orders: $e');
      return [];
    }
  }

  /// Listen to real-time order updates for a user
  Stream<List<AdminOrder>> streamUserOrders(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AdminOrder.fromMap(doc.id, doc.data()))
              .toList();
        })
        .handleError((error) {
          debugPrint('Error in streamUserOrders: $error');
          return <AdminOrder>[];
        });
  }

  /// Fetch all orders from Firestore
  Future<void> fetchOrders() async {
    final QuerySnapshot snapshot = await _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .get();

    _orders = snapshot.docs
        .map(
          (doc) =>
              AdminOrder.fromMap(doc.id, doc.data() as Map<String, dynamic>),
        )
        .toList();
    notifyListeners();
  }

  /// Update order status in Firestore
  Future<void> updateStatus(String orderId, String status) async {
    await _db.collection('orders').doc(orderId).update({'status': status});
    final int index = _orders.indexWhere((order) => order.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(status: status);
      notifyListeners();
    }
  }

  /// Delete an order from Firestore (admin)
  Future<void> deleteOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).delete();
    _orders.removeWhere((order) => order.id == orderId);
    notifyListeners();
  }

  /// Place a new order and save to Firestore
  Future<String> placeOrder({
    required String userId,
    required String customer,
    required List<Product> products,
    required Map<String, int> quantities,
    required double amount,
    required String paymentMethod,
    required String paymentStatus,
    required String deliveryAddress,
  }) async {
    final List<Map<String, dynamic>> linesMaps = products
        .map(
          (product) => OrderLine(
            productId: product.id,
            productName: product.name,
            quantity: quantities[product.id] ?? 0,
            unitPrice: product.price,
            imageUrl: product.imageUrl, // Include product image
            unit: product.unit, // Include product unit
          ),
        )
        .where((line) => line.quantity > 0)
        .map((line) => line.toMap())
        .toList();

    final Map<String, dynamic> data = {
      'userId': userId,
      'customer': customer,
      'amount': amount,
      'status': 'Placed',
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'deliveryAddress': deliveryAddress,
      'createdAt': Timestamp.now(),
      'lines': linesMaps,
    };

    final DocumentReference ref = await _db.collection('orders').add(data);

    _orders.insert(0, AdminOrder.fromMap(ref.id, data));
    notifyListeners();

    return ref.id;
  }
}
