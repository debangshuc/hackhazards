import 'package:flutter/material.dart';

class Model {
  final String id;
  final String ownedBy;
  final int contextWindow;
  final String provider;
  
  Model({
    required this.id,
    required this.ownedBy,
    required this.contextWindow, 
    required this.provider,
  });

  factory Model.fromJson(Map<String, dynamic> json, String defaultProvider) {
    return Model(
      id: json['id'],
      ownedBy: json['owned_by'] ?? 'Unknown',
      contextWindow: json['context_window'] ?? 0,
      provider: defaultProvider,
    );
  }

  // Get model avatar image based on provider and model name
  String get avatarAsset {
    if (id.contains('llama') || id.contains('mixtral')) {
      return 'assets/images/llama.png';
    } else if (id.contains('claude')) {
      return 'assets/images/claude.png';
    } else if (id.contains('gpt')) {
      return 'assets/images/gpt.png';
    } else if (id.contains('grok')) {
      return 'assets/images/grok.png';
    } else {
      return 'assets/images/llama.png'; // Default image
    }
  }

  // Get avatar color
  Color get avatarColor {
    if (id.contains('llama') || id.contains('mixtral')) {
      return Color(0xFF6A65B3); // Purple
    } else if (id.contains('claude')) {
      return Color(0xFF9C27B0); // Deep purple
    } else if (id.contains('gpt')) {
      return Color(0xFF4CAF50); // Green
    } else if (id.contains('grok')) {
      return Color(0xFFE91E63); // Pink
    } else {
      return Color(0xFF6A65B3); // Default purple
    }
  }

  // Get avatar fallback url for when local assets fail
  String get avatarFallbackUrl {
    if (id.contains('llama') || id.contains('mixtral')) {
      return 'https://via.placeholder.com/150/6a65b3';
    } else if (id.contains('claude')) {
      return 'https://via.placeholder.com/150/9C27B0';
    } else if (id.contains('gpt')) {
      return 'https://via.placeholder.com/150/4CAF50';
    } else if (id.contains('grok')) {
      return 'https://via.placeholder.com/150/E91E63';
    } else {
      return 'https://via.placeholder.com/150';
    }
  }

  // Helper to get a display name from id
  String get displayName {
    List<String> parts = id.split('-');
    if (parts.isNotEmpty) {
      // Capitalize first part
      return parts[0][0].toUpperCase() + parts[0].substring(1);
    }
    return id;
  }
} 