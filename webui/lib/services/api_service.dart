import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../models/model.dart';
import '../models/message.dart';
import 'image_service.dart';

class ApiService {
  static const String API_KEY_PREF = 'api_key';
  
  // API endpoints for different providers
  static const Map<String, String> apiEndpoints = {
    'groq': 'https://api.groq.com/openai/v1/chat/completions',
    'openai': 'https://api.openai.com/v1/chat/completions',
    'anthropic': 'https://api.anthropic.com/v1/messages',
    'grok': 'https://api.grok.ai/v1/chat/completions', // Example endpoint
  };

  // Get API key from shared preferences
  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(API_KEY_PREF) ?? '';
  }

  // Save API key to shared preferences
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(API_KEY_PREF, apiKey);
  }

  // Get API endpoint based on model ID
  static String getApiEndpoint(String modelId) {
    if (modelId.contains('llama') || modelId.contains('mixtral')) {
      return apiEndpoints['groq']!;
    } else if (modelId.contains('gpt')) {
      return apiEndpoints['openai']!;
    } else if (modelId.contains('claude')) {
      return apiEndpoints['anthropic']!;
    } else if (modelId.contains('grok')) {
      return apiEndpoints['grok']!;
    } else {
      // Default to Groq API
      return apiEndpoints['groq']!;
    }
  }

  // Check if the model has vision capabilities
  static bool hasVisionCapabilities(String modelId) {
    // Models with vision capabilities
    return modelId.contains('llama-4-scout') || 
           modelId.contains('llama-4-maverick') ||
           modelId.contains('llama-3.3-70b-versatile') ||
           modelId.contains('gpt-4-vision') ||
           modelId.contains('gpt-4o') ||
           modelId.contains('claude-3-opus') ||
           modelId.contains('claude-3-sonnet');
  }

  // Get API headers based on model ID
  static Future<Map<String, String>> getHeaders(String modelId) async {
    final apiKey = await getApiKey();
    
    if (modelId.contains('claude')) {
      // Anthropic headers
      return {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      };
    } else {
      // OpenAI-compatible headers (Groq, OpenAI, Grok)
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };
    }
  }

  // Fetch available models from API
  static Future<List<Model>> fetchModels() async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      return [];
    }

    List<Model> allModels = [];

    // Try fetching from Groq
    try {
      final response = await http.get(
        Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> modelData = data['data'];
        allModels.addAll(modelData.map((model) => Model.fromJson(model, 'groq')));
      }
    } catch (e) {
      print('Error fetching Groq models: $e');
    }

    // Add some default models if API call fails
    if (allModels.isEmpty) {
      allModels = [
        Model(
          id: 'llama-3.1-8b-instant',
          ownedBy: 'Groq',
          contextWindow: 128000,
          provider: 'groq',
        ),
        Model(
          id: 'llama-3.3-70b-versatile',
          ownedBy: 'Groq',
          contextWindow: 128000,
          provider: 'groq',
        ),
        Model(
          id: 'meta-llama/llama-4-scout-17b-16e-instruct',
          ownedBy: 'Meta/Groq',
          contextWindow: 128000,
          provider: 'groq',
        ),
        Model(
          id: 'claude-3.5-sonnet',
          ownedBy: 'Anthropic',
          contextWindow: 200000,
          provider: 'anthropic',
        ),
        Model(
          id: 'gpt-4o',
          ownedBy: 'OpenAI',
          contextWindow: 128000,
          provider: 'openai',
        ),
        Model(
          id: 'grok-2',
          ownedBy: 'xAI',
          contextWindow: 128000,
          provider: 'grok',
        ),
      ];
    }

    return allModels;
  }

  // Send a chat message
  static Future<String> sendChatMessage(
    String modelId, 
    List<ChatMessage> messages,
    {bool withImages = false}
  ) async {
    try {
      final apiEndpoint = getApiEndpoint(modelId);
      final headers = await getHeaders(modelId);
      final bool supportsVision = hasVisionCapabilities(modelId);
      
      if (modelId.contains('claude')) {
        // Anthropic API format
        final Map<String, dynamic> requestBody = {
          'model': modelId,
          'max_tokens': 1024,
          'messages': await _formatMessagesForAnthropicAPI(messages, withImages && supportsVision),
        };

        final response = await http.post(
          Uri.parse(apiEndpoint),
          headers: headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['content'][0]['text'] ?? "No response from the model.";
        } else {
          return "Error: ${response.statusCode} - ${response.body}";
        }
      } else {
        // OpenAI-compatible API format (Groq, OpenAI, Grok)
        final Map<String, dynamic> requestBody = {
          'model': modelId,
          'messages': await _formatMessagesForOpenAIAPI(messages, withImages && supportsVision),
        };

        final response = await http.post(
          Uri.parse(apiEndpoint),
          headers: headers,
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['choices'] != null && data['choices'].isNotEmpty) {
            return data['choices'][0]['message']['content'] ?? "No response from the model.";
          } else {
            return "Invalid response format.";
          }
        } else {
          return "Error: ${response.statusCode} - ${response.body}";
        }
      }
    } catch (e) {
      return "Exception occurred: $e";
    }
  }

  // Format messages for OpenAI compatible API (Groq, OpenAI, Grok)
  static Future<List<Map<String, dynamic>>> _formatMessagesForOpenAIAPI(
    List<ChatMessage> messages, 
    bool withImages
  ) async {
    List<Map<String, dynamic>> formattedMessages = [];

    for (var message in messages) {
      if (message.role == 'user' && withImages && message.attachments.isNotEmpty && message.attachments.any((a) => _isImageAttachment(a))) {
        // Create a list to hold multiple content parts
        List<Map<String, dynamic>> contentList = [];
        
        // Add text part if message has text
        if (message.text.isNotEmpty) {
          contentList.add({
            'type': 'text',
            'text': message.text,
          });
        }
        
        // Add image parts for each image attachment
        for (var attachment in message.attachments) {
          if (_isImageAttachment(attachment)) {
            try {
              final base64Image = await ImageService.fileToBase64(attachment['path']);
              final extension = attachment['extension']?.toLowerCase() ?? 'jpeg';
              
              contentList.add({
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/$extension;base64,$base64Image',
                },
              });
            } catch (e) {
              print('Error encoding image: $e');
            }
          }
        }
        
        formattedMessages.add({
          'role': message.role == 'bot' ? 'assistant' : 'user',
          'content': contentList,
        });
      } else {
        formattedMessages.add({
          'role': message.role == 'bot' ? 'assistant' : 'user',
          'content': message.text,
        });
      }
    }
    
    return formattedMessages;
  }
  
  // Format messages for Anthropic API
  static Future<List<Map<String, dynamic>>> _formatMessagesForAnthropicAPI(
    List<ChatMessage> messages, 
    bool withImages
  ) async {
    List<Map<String, dynamic>> formattedMessages = [];

    for (var message in messages) {
      if (message.role == 'user' && withImages && message.attachments.isNotEmpty && message.attachments.any((a) => _isImageAttachment(a))) {
        // Create a list to hold multiple content parts
        List<Map<String, dynamic>> contentList = [];
        
        // Add text part if message has text
        if (message.text.isNotEmpty) {
          contentList.add({
            'type': 'text',
            'text': message.text,
          });
        }
        
        // Add image parts for each image attachment
        for (var attachment in message.attachments) {
          if (_isImageAttachment(attachment)) {
            try {
              final base64Image = await ImageService.fileToBase64(attachment['path']);
              final mediaType = 'image/${attachment['extension']?.toLowerCase() ?? 'jpeg'}';
              
              contentList.add({
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': mediaType,
                  'data': base64Image,
                },
              });
            } catch (e) {
              print('Error encoding image: $e');
            }
          }
        }
        
        formattedMessages.add({
          'role': message.role == 'bot' ? 'assistant' : 'user',
          'content': contentList,
        });
      } else {
        formattedMessages.add({
          'role': message.role == 'bot' ? 'assistant' : 'user',
          'content': message.text,
        });
      }
    }
    
    return formattedMessages;
  }
  
  // Check if an attachment is an image
  static bool _isImageAttachment(Map<String, dynamic> attachment) {
    final extension = attachment['extension']?.toString().toLowerCase() ?? '';
    return extension == 'jpg' || extension == 'jpeg' || extension == 'png';
  }
} 