import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';

class ChatStorage {
  static const String _chatFolder = 'chats';
  static const String _currentChatFile = 'current_chat.json';

  // Create chat storage directory
  static Future<Directory> _getChatDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final chatDir = Directory('${appDir.path}/$_chatFolder');

    if (!await chatDir.exists()) {
      await chatDir.create(recursive: true);
    }

    return chatDir;
  }

  // Save chat messages
  static Future<void> saveMessages(List<ChatMessage> messages) async {
    try {
      final chatDir = await _getChatDirectory();
      final file = File('${chatDir.path}/$_currentChatFile');

      // Prepare data for saving
      final data = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

      // Write to file
      await file.writeAsString(jsonEncode(data));
      print('Chat saved successfully to ${file.path}');
    } catch (e) {
      print('Error saving chat: $e');
    }
  }

  // Load chat messages
  static Future<List<ChatMessage>> loadMessages() async {
    try {
      final chatDir = await _getChatDirectory();
      final file = File('${chatDir.path}/$_currentChatFile');

      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        final List<dynamic> messagesJson = data['messages'];

        // Convert to ChatMessage objects
        return messagesJson
            .map<ChatMessage>((msg) => ChatMessage.fromJson(msg))
            .toList();
      }
    } catch (e) {
      print('Error loading chat: $e');
    }

    // Return empty list if file doesn't exist or error occurs
    return [];
  }

  // Delete current chat
  static Future<void> deleteCurrentChat() async {
    try {
      final chatDir = await _getChatDirectory();
      final file = File('${chatDir.path}/$_currentChatFile');

      if (await file.exists()) {
        await file.delete();
        print('Chat deleted successfully');
      }
    } catch (e) {
      print('Error deleting chat: $e');
    }
  }
  
  // Save chat with custom name
  static Future<void> saveChatAs(String chatName, List<ChatMessage> messages) async {
    try {
      final chatDir = await _getChatDirectory();
      final sanitizedName = chatName.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final file = File('${chatDir.path}/${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.json');

      // Prepare data for saving
      final data = {
        'name': chatName,
        'lastUpdated': DateTime.now().toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

      // Write to file
      await file.writeAsString(jsonEncode(data));
      print('Chat saved as "${chatName}" to ${file.path}');
    } catch (e) {
      print('Error saving chat: $e');
    }
  }

  // List all saved chats
  static Future<List<Map<String, dynamic>>> listSavedChats() async {
    List<Map<String, dynamic>> chats = [];
    
    try {
      final chatDir = await _getChatDirectory();
      if (!await chatDir.exists()) return chats;
      
      final entities = await chatDir.list().toList();
      
      for (var entity in entities) {
        if (entity is File && entity.path.endsWith('.json') && !entity.path.endsWith(_currentChatFile)) {
          try {
            final content = await entity.readAsString();
            final data = jsonDecode(content);
            
            chats.add({
              'name': data['name'] ?? 'Unnamed Chat',
              'lastUpdated': data['lastUpdated'],
              'path': entity.path,
              'messageCount': (data['messages'] as List).length,
            });
          } catch (e) {
            print('Error reading chat file ${entity.path}: $e');
          }
        }
      }
      
      // Sort by last updated (newest first)
      chats.sort((a, b) => DateTime.parse(b['lastUpdated']).compareTo(DateTime.parse(a['lastUpdated'])));
      
    } catch (e) {
      print('Error listing saved chats: $e');
    }
    
    return chats;
  }
  
  // Load a specific saved chat
  static Future<List<ChatMessage>> loadSavedChat(String path) async {
    try {
      final file = File(path);
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        final List<dynamic> messagesJson = data['messages'];
        
        return messagesJson
            .map<ChatMessage>((msg) => ChatMessage.fromJson(msg))
            .toList();
      }
    } catch (e) {
      print('Error loading saved chat: $e');
    }
    
    return [];
  }
} 