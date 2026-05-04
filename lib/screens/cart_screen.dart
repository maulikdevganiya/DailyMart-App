import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../widgets/cart_checkout_bar.dart';
import '../widgets/quantity_selector.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, this.isTabPage = false});

  final bool isTabPage;

  @override
  Widget build(BuildContext context) {
    final CartProvider cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isTabPage,
        title: const Text('Your Cart'),
      ),
      body: cart.totalItems == 0
          ? const _EmptyCartView()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              itemBuilder: (context, index) {
                final Product product = cart.cartProducts[index];
                final int quantity = cart.quantityFor(product.id);

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            cacheHeight: 150,
                            cacheWidth: 150,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.green.shade100,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.local_grocery_store,
                                    color: Colors.green,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(product.unit),
                            const SizedBox(height: 8),
                            Text(
                              'Rs ${(product.price * quantity).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      QuantitySelector(
                        compact: true,
                        quantity: quantity,
                        onIncrease: () => cart.increase(product),
                        onDecrease: () => cart.decrease(product),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemCount: cart.cartProducts.length,
            ),
      bottomNavigationBar: cart.totalItems == 0
          ? null
          : CartCheckoutBar(
              buttonLabel: 'Proceed to Checkout',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                );
              },
            ),
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_checkout_outlined,
              size: 76,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your cart is empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Add products from home and categories to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
