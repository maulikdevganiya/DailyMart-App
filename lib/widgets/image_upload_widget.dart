import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';

/// Reusable image upload widget with preview and upload indicator
class ImageUploadWidget extends StatefulWidget {
  final Function(String imageUrl) onImageUploaded;
  final Function(String errorMessage)? onError;
  final String? initialImageUrl;
  final double maxWidth;
  final double maxHeight;
  final String buttonLabel;
  final bool showPreview;

  const ImageUploadWidget({
    super.key,
    required this.onImageUploaded,
    this.onError,
    this.initialImageUrl,
    this.maxWidth = 300,
    this.maxHeight = 300,
    this.buttonLabel = 'Pick Image',
    this.showPreview = true,
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _uploadedImageUrl = widget.initialImageUrl;
  }

  Future<void> _pickImage() async {
    try {
      setState(() => _errorMessage = null);

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        debugPrint('User cancelled image picker');
        return;
      }

      final File imageFile = File(pickedFile.path);

      // Validate image
      final validationError = CloudinaryService.validateImage(imageFile);
      if (validationError != null) {
        setState(() => _errorMessage = validationError);
        widget.onError?.call(validationError);
        return;
      }

      setState(() => _selectedImage = imageFile);

      // Get image size
      final sizeMB = await CloudinaryService.getImageSizeMB(imageFile);
      debugPrint('Image selected: ${imageFile.path}, Size: ${sizeMB}MB');

      // Upload image
      await _uploadImage(imageFile);
    } catch (e) {
      final errorMsg = 'Error picking image: $e';
      setState(() => _errorMessage = errorMsg);
      widget.onError?.call(errorMsg);
      debugPrint(errorMsg);
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    setState(() => _isLoading = true);

    try {
      debugPrint('Uploading image to Cloudinary...');

      final imageUrl = await CloudinaryService.uploadImage(imageFile);

      if (mounted) {
        setState(() {
          _uploadedImageUrl = imageUrl;
          _isLoading = false;
          _errorMessage = null;
        });

        // Call callback with uploaded URL
        widget.onImageUploaded(imageUrl);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });

        // Call error callback
        widget.onError?.call(errorMsg);

        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upload Failed'),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      debugPrint('Upload error: $errorMsg');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Preview Section
        if (widget.showPreview)
          Container(
            width: widget.maxWidth,
            height: widget.maxHeight,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: _buildPreview(),
          ),
        const SizedBox(height: 16),

        // Button Section
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickImage,
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.image_search),
                label: Text(_isLoading ? 'Uploading...' : widget.buttonLabel),
              ),
            ),
            if (_uploadedImageUrl != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _selectedImage = null;
                            _uploadedImageUrl = null;
                            _errorMessage = null;
                          });
                        },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ),
            ],
          ],
        ),

        // Error Message
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Success Indicator
        if (_uploadedImageUrl != null && !_isLoading) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Image uploaded successfully',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview() {
    // Show loading indicator
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue.shade600),
            const SizedBox(height: 12),
            const Text('Uploading...'),
          ],
        ),
      );
    }

    // Show uploaded image
    if (_uploadedImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _uploadedImageUrl!,
          fit: BoxFit.cover,
          cacheHeight: 300,
          cacheWidth: 300,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Show selected image before upload
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(_selectedImage!, fit: BoxFit.cover),
      );
    }

    // Show placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'No image selected',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
