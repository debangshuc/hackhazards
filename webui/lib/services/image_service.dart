import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class ImageService {
  // Convert file to base64
  static Future<String> fileToBase64(String filePath) async {
    try {
      File file = File(filePath);
      if (await file.exists()) {
        Uint8List bytes = await file.readAsBytes();
        return base64Encode(bytes);
      } else {
        throw Exception('File does not exist');
      }
    } catch (e) {
      print('Error converting file to base64: $e');
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