import 'package:flutter/material.dart';

import '../models/admin_order.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.order});

  final AdminOrder order;

  Color _statusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.orange;
      case 'Packed':
        return Colors.blue;
      case 'Out for Delivery':
        return Colors.purple;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Placed':
        return Icons.receipt_long;
      case 'Packed':
        return Icons.inventory_2;
      case 'Out for Delivery':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayId =
        'DM-${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length).toUpperCase()}';
    final Color sColor = _statusColor(order.status);

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  sColor.withValues(alpha: 0.15),
                  sColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _statusIcon(order.status),
                    color: sColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.status,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: sColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #$displayId',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Order Info
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.calendar_today,
                label: 'Order Date',
                value:
                    '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}  ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
              ),
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Delivery Address',
                value: order.deliveryAddress,
              ),
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.payments_outlined,
                label: 'Payment Method',
                value: order.paymentMethod,
              ),
              const Divider(height: 20),
              _InfoRow(
                icon: Icons.check_circle_outline,
                label: 'Payment Status',
                value: order.paymentStatus,
                valueColor: order.paymentStatus == 'Paid'
                    ? Colors.green
                    : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items
          const Text(
            'Items Ordered',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 8),
          ...order.lines.map((line) => _buildItemTile(line)),
          const SizedBox(height: 16),

          // Price Breakdown
          _InfoCard(
            children: [
              _PriceRow(
                label: 'Item Total',
                value: order.lines.fold<double>(
                  0,
                  (sum, l) => sum + l.lineTotal,
                ),
              ),
              const _PriceRow(label: 'Delivery Fee', value: 25),
              const _PriceRow(label: 'Handling Fee', value: 8),
              const Divider(height: 20),
              _PriceRow(
                label: 'Grand Total',
                value: order.amount,
                isBold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(OrderLine line) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: line.imageUrl.isNotEmpty
                    ? Image.network(
                        line.imageUrl,
                        fit: BoxFit.cover,
                        cacheHeight: 120,
                        cacheWidth: 120,
                        errorBuilder: (c, e, s) => _placeholderIcon(),
                      )
                    : _placeholderIcon(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line.unit,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'x${line.quantity}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rs ${line.lineTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      color: Colors.green.shade100,
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_grocery_store,
        color: Colors.green,
        size: 24,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
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
    final style = TextStyle(
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
