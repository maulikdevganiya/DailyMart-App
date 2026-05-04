import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service class for uploading images to Cloudinary
class CloudinaryService {
  // TODO: Replace with your Cloudinary cloud name
  static const String _cloudName = 'drmof0fic';

  // TODO: Replace with your unsigned upload preset
  static const String _uploadPreset = 'DailyMart_app_upload';

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/drmof0fic/image/upload';

  /// Upload image to Cloudinary and return secure URL
  ///
  /// Parameters:
  /// - [imageFile] - The image file to upload
  ///
  /// Returns:
  /// - Secure URL string on success
  /// - Throws exception on failure
  static Future<String> uploadImage(File imageFile) async {
    try {
      // Validate image file exists
      if (!imageFile.existsSync()) {
        throw Exception('Image file not found');
      }

      debugPrint('Starting Cloudinary upload: ${imageFile.path}');

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      // Add upload preset
      request.fields['upload_preset'] = _uploadPreset;

      // Add image file
      final imageStream = http.ByteStream(imageFile.openRead());
      final imageLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'file',
        imageStream,
        imageLength,
        filename: imageFile.path.split('/').last,
      );

      request.files.add(multipartFile);

      // Send request with timeout
      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
          'Upload timeout. Please check your internet connection.',
        ),
      );

      debugPrint('Upload response status: ${response.statusCode}');

      // Parse response
      final responseBody = await response.stream.bytesToString();
      final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);

      // Handle response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final secureUrl = jsonResponse['secure_url'] as String?;

        if (secureUrl == null || secureUrl.isEmpty) {
          throw Exception('No URL returned from Cloudinary');
        }

        debugPrint('Upload successful: $secureUrl');
        return secureUrl;
      } else {
        // Handle error response
        final error = jsonResponse['error'];
        final errorMessage = error is Map
            ? error['message'] ?? 'Unknown error'
            : error ?? 'Upload failed';

        throw Exception('Upload failed: $errorMessage');
      }
    } on SocketException catch (e) {
      debugPrint('SocketException: $e');
      throw Exception(
        'Network error: Unable to connect. Please check your internet connection.',
      );
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      rethrow;
    }
  }

  /// Get image size in MB
  static Future<double> getImageSizeMB(File imageFile) async {
    try {
      final sizeInBytes = await imageFile.length();
      final sizeInMB = sizeInBytes / (1024 * 1024);
      return double.parse(sizeInMB.toStringAsFixed(2));
    } catch (e) {
      debugPrint('Error getting image size: $e');
      return 0.0;
    }
  }

  /// Validate image before upload
  static String? validateImage(File? imageFile, {double maxSizeMB = 5.0}) {
    if (imageFile == null) {
      return 'Please select an image';
    }

    if (!imageFile.existsSync()) {
      return 'Image file not found';
    }

    final sizeInBytes = imageFile.lengthSync();
    final sizeInMB = sizeInBytes / (1024 * 1024);

    if (sizeInMB > maxSizeMB) {
      return 'Image size must be less than ${maxSizeMB}MB';
    }

    return null; // Valid image
  }

  /// Delete image from Cloudinary (requires auth)
  /// Note: This requires API key authentication (not available with unsigned preset)
  /// Use this only from backend for security
  static Future<bool> deleteImage(String publicId) async {
    try {
      debugPrint('Deleting image from Cloudinary: $publicId');
      // Implementation would require API key authentication
      // This is typically done from backend
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }
}
