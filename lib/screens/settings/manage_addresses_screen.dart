import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';
import 'add_address_screen.dart'; // FIX #4: import AddAddressScreen

class ManageAddressesScreen extends StatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  Future<void> _editAddress() async {
    final authProvider = context.read<AuthProvider>();
    final addressProvider = context.read<AddressProvider>();

    // FIX #3: Use StatefulBuilder so we can manage loading state inside sheet
    final TextEditingController addressController = TextEditingController(
      text: authProvider.currentUser?.address ?? '',
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // FIX #1: Use root scaffold messenger to avoid context mismatch crashes
      builder: (sheetContext) {
        bool isSaving = false; // FIX #2: Local loading state inside sheet

        return StatefulBuilder(
          // FIX #2: Needed to rebuild sheet on state change
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Edit Address',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          // FIX #2: Disable button while saving
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!(formKey.currentState?.validate() ??
                                      false))
                                    return;

                                  // FIX #2: Set loading before async call
                                  setSheetState(() => isSaving = true);

                                  final bool saved = await authProvider
                                      .updateCurrentUserProfile(
                                        name:
                                            authProvider.currentUser?.name ??
                                            '',
                                        phone:
                                            authProvider.currentUser?.phone ??
                                            '',
                                        address: addressController.text.trim(),
                                      );

                                  // FIX #2: Reset loading after async call
                                  if (sheetContext.mounted) {
                                    setSheetState(() => isSaving = false);
                                  }

                                  if (!sheetContext.mounted) return;

                                  if (saved) {
                                    // FIX #1: Update AddressProvider with trimmed text
                                    addressProvider.setSelectedAddressText(
                                      addressController.text.trim(),
                                    );

                                    Navigator.pop(sheetContext);

                                    // FIX #1: Use outer context for snackbar AFTER pop
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: Colors.green,
                                          content: Text(
                                            'Address updated successfully',
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    // FIX #1: Show error inside sheet (sheet still open)
                                    ScaffoldMessenger.of(
                                      sheetContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text(
                                          'Failed to update. Check your connection.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          // FIX #2: Show spinner inside button while saving
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Address',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // FIX #3: Safe to dispose here — sheet is fully closed at this point
    addressController.dispose();
  }

  // FIX #4: Separate method for navigating to AddAddressScreen
  Future<void> _addNewAddress() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );
    // Provider auto-updates via notifyListeners() — no manual refresh needed
  }

  @override
  Widget build(BuildContext context) {
    // FIX #5: Watch both providers so screen rebuilds on either change
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Addresses')),
      body: Consumer2<AuthProvider, AddressProvider>(
        builder: (context, authProvider, addressProvider, _) {
          final primaryAddress = authProvider.currentUser?.address;
          final selectedText = addressProvider.selectedAddressText;

          // Show selected address from provider if available,
          // otherwise fall back to profile address
          final displayAddress = selectedText.isNotEmpty
              ? selectedText
              : (primaryAddress ?? '');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: Colors.green.shade700,
                  ),
                  title: const Text(
                    'Primary Address',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    displayAddress.isNotEmpty
                        ? displayAddress
                        : 'No address saved yet',
                  ),
                  trailing: TextButton.icon(
                    onPressed: _editAddress,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // FIX #4: "Add Address" goes to AddAddressScreen,
              //         "Change Address" edits inline via bottom sheet
              OutlinedButton.icon(
                onPressed: displayAddress.isNotEmpty
                    ? _editAddress // Already has address → edit inline
                    : _addNewAddress, // No address → go to full add screen
                icon: Icon(
                  displayAddress.isNotEmpty
                      ? Icons.edit_location_alt_outlined
                      : Icons.add_location_alt_outlined,
                ),
                label: Text(
                  displayAddress.isNotEmpty ? 'Change Address' : 'Add Address',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
