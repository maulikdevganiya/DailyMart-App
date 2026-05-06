import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../../models/category_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_catalog_provider.dart';
import '../../services/cloudinary_service.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  Future<void> _openProductDialog({CatalogProduct? existing}) async {
    final bool isEdit = existing != null;
    final TextEditingController nameController = TextEditingController(
      text: existing?.product.name ?? '',
    );
    final TextEditingController priceController = TextEditingController(
      text: existing == null ? '' : existing.product.price.toStringAsFixed(0),
    );
    final TextEditingController ratingController = TextEditingController(
      text: existing == null ? '' : existing.product.rating.toStringAsFixed(1),
    );
    final TextEditingController unitController = TextEditingController(
      text: existing?.product.unit ?? '',
    );
    final TextEditingController descriptionController = TextEditingController(
      text: existing?.product.description ?? '',
    );
    final TextEditingController deliveryMinutesController =
        TextEditingController(
          text: existing == null
              ? '10'
              : existing.product.deliveryMinutes.toString(),
        );
    final TextEditingController imageUrlController = TextEditingController(
      text: existing?.product.imageUrl ?? '',
    );

    // Category dropdown state
    final List<GroceryCategory> categories = context
        .read<CategoryProvider>()
        .categories;
    String? selectedCategoryId = existing?.product.categoryId;
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    String? previewImageUrl = existing?.product.imageUrl;
    bool isSaving = false;

    // If editing, verify selected category still exists
    if (selectedCategoryId != null &&
        !categories.any((c) => c.name.toLowerCase() == selectedCategoryId)) {
      selectedCategoryId = null;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Product' : 'Add Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat.name.toLowerCase(),
                          child: Row(
                            children: [
                              Icon(
                                cat.iconData,
                                size: 18,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(cat.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategoryId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price (Rs)',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ratingController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Rating (0.0 - 5.0)',
                        prefixIcon: Icon(Icons.star_outline),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit (eg: 1 kg, 500 g, 6 pcs)',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deliveryMinutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Time (minutes)',
                        prefixIcon: Icon(Icons.delivery_dining),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final FilePickerResult? result = await FilePicker
                            .platform
                            .pickFiles(type: FileType.image, withData: true);

                        final PlatformFile? file = result?.files.single;
                        if (file == null || file.bytes == null) {
                          return;
                        }

                        setDialogState(() {
                          selectedImageBytes = file.bytes;
                          selectedImageName = file.name;
                          previewImageUrl = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade300),
                          color: Colors.grey.shade50,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.green.shade50,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: selectedImageBytes != null
                                        ? Image.memory(
                                            selectedImageBytes!,
                                            fit: BoxFit.cover,
                                          )
                                        : (previewImageUrl != null &&
                                              previewImageUrl!.isNotEmpty)
                                        ? Image.network(
                                            previewImageUrl!,
                                            fit: BoxFit.cover,
                                            cacheHeight: 150,
                                            cacheWidth: 150,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons.image_outlined,
                                                      color: Colors.green,
                                                    ),
                                          )
                                        : const Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: Colors.green,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedImageName ??
                                            (isEdit
                                                ? 'Tap to replace product image'
                                                : 'Tap to choose product image'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Choose an image from your device and upload it to Firebase Storage.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedImageBytes == null &&
                                      (previewImageUrl == null ||
                                          previewImageUrl!.isEmpty)
                                  ? 'No image selected'
                                  : 'Image ready',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        '— OR —',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: imageUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Direct Image URL (Optional)',
                        hintText: 'https://example.com/image.jpg',
                        prefixIcon: Icon(Icons.link),
                        helperText: 'Paste a link to an image from the web.',
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          if (val.trim().isNotEmpty) {
                            previewImageUrl = val.trim();
                            selectedImageBytes = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: const Text('Cancel'),
                ),
                isSaving
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : FilledButton(
                        onPressed: () async {
                          final ScaffoldMessengerState messenger =
                              ScaffoldMessenger.of(context);
                          final NavigatorState navigator = Navigator.of(
                            context,
                          );
                          final ProductCatalogProvider catalogProvider = context
                              .read<ProductCatalogProvider>();
                          final AuthProvider authProvider = context
                              .read<AuthProvider>();
                          final String name = nameController.text.trim();
                          final String category = selectedCategoryId ?? '';
                          final double? price = double.tryParse(
                            priceController.text,
                          );
                          final double? rating = double.tryParse(
                            ratingController.text,
                          );
                          final String unit = unitController.text.trim();
                          final String description = descriptionController.text
                              .trim();
                          final int? deliveryMins = int.tryParse(
                            deliveryMinutesController.text,
                          );

                          if (name.isEmpty ||
                              category.isEmpty ||
                              price == null ||
                              rating == null ||
                              unit.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill all required fields.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (rating < 0 || rating > 5) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Rating must be between 0 and 5.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (!mounted) return;
                          setDialogState(() {
                            isSaving = true;
                          });

                          String finalImageUrl = imageUrlController.text.trim();

                          // If we have selected new image bytes (even if imageUrlController is not empty), priority to upload
                          if (selectedImageBytes != null) {
                            try {
                              // Create temporary file for Cloudinary upload
                              final tempDir = Directory.systemTemp;
                              final tempFile = File(
                                '${tempDir.path}/${selectedImageName ?? '$name.jpg'}',
                              );
                              await tempFile.writeAsBytes(selectedImageBytes!);

                              // Upload to Cloudinary
                              finalImageUrl =
                                  await CloudinaryService.uploadImage(tempFile);

                              // Clean up temp file
                              if (tempFile.existsSync()) {
                                await tempFile.delete();
                              }
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Image upload failed: $e. Using default placeholder.',
                                  ),
                                  backgroundColor: Colors.orange.shade800,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                              finalImageUrl =
                                  ''; // Will fall back to default below
                            }
                          }

                          if (finalImageUrl.isEmpty) {
                            finalImageUrl =
                                existing?.product.imageUrl ??
                                'https://images.unsplash.com/photo-1542838132-92c53300491e?w=600';
                          }

                          try {
                            if (isEdit) {
                              await catalogProvider.updateProduct(
                                productId: existing.product.id,
                                name: name,
                                categoryId: category,
                                price: price,
                                rating: rating,
                                unit: unit,
                                imageUrl: finalImageUrl,
                                description: description,
                                deliveryMinutes: deliveryMins ?? 10,
                                actor: authProvider.currentEmail,
                              );
                            } else {
                              await catalogProvider.addProduct(
                                name: name,
                                categoryId: category,
                                price: price,
                                rating: rating,
                                unit: unit,
                                imageUrl: finalImageUrl,
                                description: description,
                                deliveryMinutes: deliveryMins ?? 10,
                                actor: authProvider.currentEmail,
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() {
                              isSaving = false;
                            });
                            showDialog(
                              // ignore: use_build_context_synchronously
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Error'),
                                content: Text(e.toString()),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          if (!mounted) return;
                          setDialogState(() {
                            isSaving = false;
                          });

                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit
                                    ? 'Product updated successfully!'
                                    : 'Product added successfully!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: Text(isEdit ? 'Save' : 'Add'),
                      ),
              ],
            );
          },
        );
      },
    );

    // Dispose controllers created for the dialog to avoid memory leaks
    nameController.dispose();
    priceController.dispose();
    ratingController.dispose();
    unitController.dispose();
    descriptionController.dispose();
    deliveryMinutesController.dispose();
    imageUrlController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProductCatalogProvider catalog = context
        .watch<ProductCatalogProvider>();
    final List<CatalogProduct> products = catalog.allProducts;

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final CatalogProduct item = products[index];
          final bool inStock = item.inStock;
          final product = item.product;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: Image + Name/Price/Rating ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
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
                                    size: 28,
                                    color: Colors.green,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Rs ${product.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    product.unit,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${product.rating.toStringAsFixed(1)} rating',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Info chips: Category, Delivery, Section ──
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _infoChip(
                        icon: Icons.category_outlined,
                        label: product.categoryId,
                        color: Colors.blue,
                      ),
                      _infoChip(
                        icon: Icons.bolt,
                        label: '${product.deliveryMinutes} min delivery',
                        color: Colors.green,
                      ),
                      _infoChip(
                        icon: Icons.view_module_outlined,
                        label: product.section,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Description ──
                  if (product.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ),

                  // ── Action row: Stock toggle + Edit + Delete ──
                  Row(
                    children: [
                      // Stock toggle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: inStock
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: inStock
                                    ? Colors.green.shade200
                                    : Colors.red.shade200,
                              ),
                            ),
                            child: Text(
                              inStock ? 'In Stock' : 'Out of Stock',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: inStock
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                          ),
                          Switch(
                            value: inStock,
                            onChanged: (value) {
                              context
                                  .read<ProductCatalogProvider>()
                                  .toggleStock(
                                    product.id,
                                    value,
                                    actor: context
                                        .read<AuthProvider>()
                                        .currentEmail,
                                  );
                            },
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Edit product',
                        onPressed: () {
                          _openProductDialog(existing: item);
                        },
                        icon: Icon(
                          Icons.edit_outlined,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete product',
                        onPressed: () async {
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Product'),
                              content: Text(
                                'Are you sure you want to delete "${product.name}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && mounted) {
                            try {
                              await context
                                  .read<ProductCatalogProvider>()
                                  .removeProduct(product.id);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Product deleted successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to delete product: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }

                              // (controllers disposed after dialog completes)
                            }
                          }
                        },
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openProductDialog();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
