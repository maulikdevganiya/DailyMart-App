import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/address_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/orders_provider.dart';
import '../providers/address_provider.dart';
import 'order_success_screen.dart';
import 'payment_processing_screen.dart';
import 'settings/manage_addresses_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPayment = 'UPI';
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isCustomer) {
        context.read<AddressProvider>().fetchAddresses(auth.currentUid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CartProvider cart = context.watch<CartProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final AddressProvider addressProvider = context.watch<AddressProvider>();
    final Address? selectedAddress = addressProvider.selectedAddress;
    final bool hasProfileAddress = auth.currentUser?.address.isNotEmpty == true;

    // Determine effective address for checkout
    final bool hasEffectiveAddress =
        hasProfileAddress || selectedAddress != null;
    final String deliveryAddress = hasProfileAddress
        ? auth.currentUser!.address
        : (selectedAddress?.fullAddress ?? '');
    final String deliveryLabel = hasProfileAddress
        ? 'Saved Address'
        : (selectedAddress?.label ?? 'Home');

    final double itemTotal = cart.totalPrice;
    const double deliveryFee = 25;
    const double handlingFee = 8;
    final double grandTotal = itemTotal + deliveryFee + handlingFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _SectionCard(
            title: 'Delivery Address',
            icon: Icons.location_on_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deliveryLabel,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  deliveryAddress,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _showAddressPicker(context),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Payment Method',
            icon: Icons.payments_outlined,
            child: Column(
              children: [
                _PaymentTile(
                  label: 'UPI',
                  icon: Icons.account_balance,
                  selected: _selectedPayment == 'UPI',
                  onTap: () => setState(() => _selectedPayment = 'UPI'),
                ),
                _PaymentTile(
                  label: 'Credit / Debit Card',
                  icon: Icons.credit_card,
                  selected: _selectedPayment == 'Credit / Debit Card',
                  onTap: () =>
                      setState(() => _selectedPayment = 'Credit / Debit Card'),
                ),
                _PaymentTile(
                  label: 'Cash on Delivery',
                  icon: Icons.money,
                  selected: _selectedPayment == 'Cash on Delivery',
                  onTap: () =>
                      setState(() => _selectedPayment = 'Cash on Delivery'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Order Summary',
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: [
                for (final Product product in cart.cartProducts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Image.network(
                              product.imageUrl,
                              fit: BoxFit.cover,
                              cacheHeight: 80,
                              cacheWidth: 80,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.green.shade100,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.local_grocery_store,
                                      size: 18,
                                      color: Colors.green,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(product.name)),
                        Text('x${cart.quantityFor(product.id)}'),
                        const SizedBox(width: 10),
                        Text(
                          'Rs ${(product.price * cart.quantityFor(product.id)).toStringAsFixed(0)}',
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                _PriceRow(label: 'Item Total', value: itemTotal),
                const _PriceRow(label: 'Delivery Fee', value: deliveryFee),
                const _PriceRow(label: 'Handling Fee', value: handlingFee),
                const SizedBox(height: 6),
                _PriceRow(
                  label: 'Grand Total',
                  value: grandTotal,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
              onPressed:
                  (cart.totalItems == 0 ||
                      _isPlacingOrder ||
                      !hasEffectiveAddress)
                  ? null
                  : () async {
                      // Build complete address for order
                      final String addressStr;
                      if (selectedAddress != null) {
                        // Use selected address from address list
                        addressStr =
                            '${selectedAddress.fullAddress}, ${selectedAddress.city} - ${selectedAddress.pincode}';
                      } else if (hasProfileAddress) {
                        // Use profile address from user account
                        addressStr = deliveryAddress;
                      } else {
                        // Should not reach here due to button disable logic,
                        // but fallback to default
                        addressStr = 'No address provided';
                      }

                      if (_selectedPayment == 'Cash on Delivery') {
                        setState(() => _isPlacingOrder = true);
                        try {
                          // Ensure we have complete order data
                          if (cart.totalItems == 0) {
                            throw Exception('Cart is empty');
                          }

                          final String orderId = await context
                              .read<OrdersProvider>()
                              .placeOrder(
                                userId: auth.currentUid,
                                customer: auth.currentEmail,
                                products: cart.cartProducts,
                                quantities: cart.items,
                                amount: grandTotal,
                                paymentMethod: 'Cash on Delivery',
                                paymentStatus: 'Pending',
                                deliveryAddress: addressStr,
                              );

                          // Clear cart after successful order
                          cart.clear();

                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderSuccessScreen(
                                orderId: orderId,
                                paymentMethod: 'Cash on Delivery',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to place order: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isPlacingOrder = false);
                        }
                      } else {
                        // Other payment methods
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentProcessingScreen(
                              paymentMethod: _selectedPayment,
                              totalAmount: grandTotal,
                              deliveryAddress: addressStr,
                            ),
                          ),
                        );
                      }
                    },
              child: _isPlacingOrder
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      !hasEffectiveAddress
                          ? 'Add Address to Continue'
                          : 'Place Order  •  Rs ${grandTotal.toStringAsFixed(0)}',
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddressPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<AddressProvider>(
          builder: (context, provider, _) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Delivery Address',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: provider.addresses.length,
                      itemBuilder: (context, index) {
                        final address = provider.addresses[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            address.label == 'Home'
                                ? Icons.home_outlined
                                : Icons.location_on_outlined,
                            color: Colors.green.shade700,
                          ),
                          title: Text(
                            address.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(address.fullAddress),
                          trailing: provider.selectedAddress?.id == address.id
                              ? Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade700,
                                )
                              : null,
                          onTap: () {
                            provider.selectAddress(address);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManageAddressesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Manage Addresses'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final double value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
      fontSize: isBold ? 16 : 14,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('Rs ${value.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.label,
    required this.icon,
    this.selected = false,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? Colors.green.shade50 : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.green.shade300 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Colors.green.shade700 : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
          ],
        ),
      ),
    );
  }
}
