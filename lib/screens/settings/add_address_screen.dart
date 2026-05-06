import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/address_model.dart';
import '../../providers/address_provider.dart';
import '../../providers/auth_provider.dart';
import '../login_screen.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController(text: 'Home');
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isDefault = false;

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final addressProvider = context.read<AddressProvider>();

    // FIX #1: Check auth BEFORE showing loading or doing anything
    if (auth.currentUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to save an address.')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    // FIX #2: Use provider's isLoading instead of local _isLoading
    // so the UI reacts to the actual async state in AddressProvider
    final newAddress = Address(
      id: '',
      label: _labelController.text.trim(),
      fullAddress: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      phone: _phoneController.text.trim(),
      isDefault: _isDefault,
    );

    try {
      await addressProvider.addAddress(auth.currentUid, newAddress);

      if (mounted) {
        // FIX #3: Pass back 'true' so the previous screen knows to refresh UI
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving address: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX #2: Watch provider's isLoading — not local setState
    final isLoading = context.watch<AddressProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Add New Address')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  DropdownButtonFormField<String>(
                    value: _labelController.text,
                    decoration: const InputDecoration(
                      labelText: 'Address Label',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Home', 'Work', 'Other']
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _labelController.text = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Full Address (House No, Building, Street)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Please enter address' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _stateController,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pincodeController,
                          decoration: const InputDecoration(
                            labelText: 'Pincode',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          // FIX #4: Added pincode length validation
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Required';
                            if (v.trim().length != 6) return 'Invalid pincode';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Phone',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          // FIX #4: Added phone length validation
                          validator: (v) {
                            if (v!.trim().isEmpty) return 'Required';
                            if (v.trim().length < 10) return 'Invalid phone';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Set as default address'),
                    value: _isDefault,
                    onChanged: (val) => setState(() => _isDefault = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      // FIX #5: Disable button while loading to prevent double submit
                      onPressed: isLoading ? null : _saveAddress,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                      child: const Text('Save Address'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
