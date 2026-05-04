import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/main_shell_screen.dart';

class GoogleSignInButton extends StatefulWidget {
  final VoidCallback? onSigningIn;
  final VoidCallback? onError;

  const GoogleSignInButton({super.key, this.onSigningIn, this.onError});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    widget.onSigningIn?.call();

    setState(() => _isLoading = true);

    try {
      final AuthProvider auth = context.read<AuthProvider>();
      final bool success = await auth.signInWithGoogle();

      if (!mounted) return;

      if (success) {
        // Initialize cart for the logged-in user
        final cartProvider = context.read<CartProvider>();
        cartProvider.setCurrentUser(auth.currentUid);
        await cartProvider.restoreCartFromFirestore(auth.currentUid);

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainShellScreen()),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          final String errorMessage =
              auth.lastError ?? 'Google Sign-In failed. Please try again.';

          // Show error dialog with details
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sign-In Failed'),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );

          debugPrint('Google Sign-In failed: $errorMessage');
        }
        widget.onError?.call();
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('An unexpected error occurred: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      widget.onError?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        icon: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey.shade700,
                ),
              )
            : Image.asset(
                'assets/google_icon.png',
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.account_circle),
              ),
        label: Text(
          _isLoading ? 'Signing in...' : 'Sign in with Google',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
