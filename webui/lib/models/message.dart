import 'package:intl/intl.dart';

class ChatMessage {
  final String role; // 'user' or 'bot'
  final String text;
  final List<Map<String, dynamic>> attachments;
  final String time;
  final String avatarUrl;
  
  ChatMessage({
    required this.role,
    required this.text,
    this.attachments = const [],
    String? time,
    required this.avatarUrl,
  }) : time = time ?? DateTime.now().toIso8601String();
  
  // Convert from JSON (for storage/retrieval)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'],
      text: json['text'],
      attachments: (json['attachments'] as List?)
        ?.map((item) => Map<String, dynamic>.from(item))
        .toList() ?? [],
      time: json['time'],
      avatarUrl: json['avatarUrl'],
    );
  }
  
  // Convert to JSON (for storage)
  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'text': text,
      'attachments': attachments,
      'time': time,
      'avatarUrl': avatarUrl,
    };
  }
  
  // Format timestamp for display
  String get formattedTime {
    try {
      DateTime dateTime = DateTime.parse(time);
      return DateFormat('h:mm a').format(dateTime); // Format as "3:45 PM"
    } catch (e) {
      return "";
    }
  }
} 