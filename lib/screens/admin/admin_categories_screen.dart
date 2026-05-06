import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../providers/category_provider.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  /// Predefined color palette for the color picker
  static const List<Map<String, String>> _colorOptions = [
    {'label': 'Yellow Cream', 'hex': '#FFF4D6'},
    {'label': 'Light Blue', 'hex': '#DFF4FF'},
    {'label': 'Peach', 'hex': '#FFE6E1'},
    {'label': 'Light Orange', 'hex': '#FFF0DF'},
    {'label': 'Mint Green', 'hex': '#E4F7EA'},
    {'label': 'Lavender', 'hex': '#EDEBFF'},
    {'label': 'Light Pink', 'hex': '#FFE0F0'},
    {'label': 'Sky Blue', 'hex': '#D6EEFF'},
    {'label': 'Lime', 'hex': '#E8F5E9'},
    {'label': 'Sand', 'hex': '#FFF8E1'},
  ];

  Future<void> _openCategoryDialog({GroceryCategory? existing}) async {
    final bool isEdit = existing != null;
    final TextEditingController nameController = TextEditingController(
      text: existing?.name ?? '',
    );

    String selectedIcon = existing?.iconName ?? 'category';
    String selectedColorHex = existing?.colorHex ?? '#E4F7EA';
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(isEdit ? 'Edit Category' : 'Add Category'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'General Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Category Name',
                          hintText: 'e.g. Fruits, Beverages',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Select Category Icon',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemCount: GroceryCategory.availableIcons.length,
                          itemBuilder: (context, index) {
                            final entry = GroceryCategory.availableIcons.entries
                                .elementAt(index);
                            final bool isSelected = entry.key == selectedIcon;
                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedIcon = entry.key;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.green.shade100
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.green.shade700
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  entry.value,
                                  size: 24,
                                  color: isSelected
                                      ? Colors.green.shade800
                                      : Colors.grey.shade600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Background Color',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _colorOptions.map((option) {
                          final String hex = option['hex']!;
                          final bool isSelected = hex == selectedColorHex;
                          final Color color = _hexToColor(hex);
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColorHex = hex;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.green.shade700
                                      : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.3),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 20,
                                      color: Colors.green.shade900,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
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
                          final String name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a category name.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          final CategoryProvider provider = context
                              .read<CategoryProvider>();
                          bool success = false;

                          if (isEdit) {
                            success = await provider.updateCategory(
                              categoryId: existing.id,
                              name: name,
                              iconName: selectedIcon,
                              colorHex: selectedColorHex,
                            );
                          } else {
                            success = await provider.addCategory(
                              name: name,
                              iconName: selectedIcon,
                              colorHex: selectedColorHex,
                            );
                          }

                          if (context.mounted) {
                            setDialogState(() {
                              isSaving = false;
                            });

                            if (success) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit
                                        ? 'Category updated successfully!'
                                        : 'Category added successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Operation failed. Please try again.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }

                            // Dispose controllers created for the dialog to avoid memory leaks
                            nameController.dispose();
                          }
                        },
                        child: Text(isEdit ? 'Update' : 'Create'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  Color _hexToColor(String hex) {
    final String clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFFE8F5E9);
  }

  @override
  Widget build(BuildContext context) {
    final CategoryProvider categoryProvider = context.watch<CategoryProvider>();
    final List<GroceryCategory> categories = categoryProvider.categories;

    return Scaffold(
      body: categories.isEmpty
          ? const Center(
              child: Text(
                'No categories yet.\nTap + to add one.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final GroceryCategory category = categories[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: category.colorValue,
                      child: Icon(
                        category.iconData,
                        color: Colors.green.shade700,
                      ),
                    ),
                    title: Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Icon: ${category.iconName} • Color: ${category.colorHex}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit category',
                          onPressed: () {
                            _openCategoryDialog(existing: category);
                          },
                          icon: Icon(
                            Icons.edit_outlined,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete category',
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Category'),
                                content: Text(
                                  'Are you sure you want to delete "${category.name}"?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () async {
                                      final bool success = await context
                                          .read<CategoryProvider>()
                                          .deleteCategory(category.id);
                                      if (context.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              success
                                                  ? 'Category deleted successfully!'
                                                  : 'Failed to delete category.',
                                            ),
                                            backgroundColor: success
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCategoryDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }
}
