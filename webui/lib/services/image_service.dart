import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class ImageService {
  // Convert file to base64
  static Future<String> fileToBase64(String filePath) async {
    try {
      print('Attempting to convert file to base64: $filePath');
      File file = File(filePath);
      if (await file.exists()) {
        print('File exists, reading as bytes...');
        Uint8List bytes = await file.readAsBytes();
        print('Successfully read ${bytes.length} bytes from file');
        return base64Encode(bytes);
      } else {
        print('File does not exist: $filePath');
        throw Exception('File does not exist: $filePath');
      }
    } catch (e) {
      print('Error converting file to base64: $e');
      if (e is FileSystemException) {
        print('FileSystemException details: ${e.message}, path: ${e.path}, osError: ${e.osError}');
      }
      rethrow;
    }
  }
  
  // Get appropriate media type for file
  static String getMediaType(String filePath) {
    final extension = path.extension(filePath).toLowerCase().replaceFirst('.', '');
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
  
  // Check if file is an image
  static bool isImageFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return extension == '.jpg' || extension == '.jpeg' || extension == '.png' || extension == '.gif';
  }
  
  // Get max image size (in bytes) for API request
  static int getMaxImageSizeForProvider(String provider) {
    switch (provider) {
      case 'groq':
        return 4 * 1024 * 1024; // 4MB for Groq
      case 'openai':
        return 20 * 1024 * 1024; // 20MB for OpenAI
      case 'anthropic':
        return 5 * 1024 * 1024; // 5MB for Anthropic
      default:
        return 4 * 1024 * 1024; // Default to 4MB
    }
  }
  
  // Compress image if needed to meet size requirements
  static Future<File> compressImageIfNeeded(File imageFile, String provider) async {
    try {
      final stats = await imageFile.stat();
      final maxSize = getMaxImageSizeForProvider(provider);
      
      if (stats.size <= maxSize) {
        return imageFile; // No compression needed
      }
      
      // TODO: Implement image compression
      // For now, just return the original file with a warning
      print('Warning: Image ${imageFile.path} exceeds size limit for $provider (${stats.size} > $maxSize bytes)');
      return imageFile;
    } catch (e) {
      print('Error checking image size: $e');
      return imageFile;
    }
  }
  
  // Get file icon for attachment
  static Widget getFileIcon(String? extension, {double size = 16.0, required Color color}) {
    switch (extension?.toLowerCase()) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return Icon(Icons.image, color: color, size: size);
      case 'pdf':
        return Icon(Icons.picture_as_pdf, color: color, size: size);
      case 'txt':
        return Icon(Icons.text_snippet, color: color, size: size);
      case 'doc':
      case 'docx':
        return Icon(Icons.description, color: color, size: size);
      default:
        return Icon(Icons.insert_drive_file, color: color, size: size);
    }
  }
  
  // Get image widget for display
  static Widget getImageWidget(String path, {double width = 60, double height = 60}) {
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: width,
              height: height,
              color: Colors.grey[800],
              child: Icon(Icons.broken_image, color: Colors.white),
            );
          },
        ),
      );
    } catch (e) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[800],
        child: Icon(Icons.broken_image, color: Colors.white),
      );
    }
  }
} 