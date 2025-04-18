import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const ChatBotApp());
}

class ChatBotApp extends StatelessWidget {
  const ChatBotApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebUI',
      debugShowCheckedModeBanner: false,
      home: ChatPage(),
    );
  }
}

class Model {
  final String id;
  final String ownedBy;
  final int contextWindow;
  final String avatarUrl;

  Model({
    required this.id,
    required this.ownedBy,
    required this.contextWindow,
    required this.avatarUrl,
  });

  factory Model.fromJson(Map<String, dynamic> json) {
    String avatarUrl = 'https://via.placeholder.com/150';

    // Assign different colors based on model name
    if (json['id'].toString().contains('llama')) {
      avatarUrl = 'https://via.placeholder.com/150/6a65b3';
    } else if (json['id'].toString().contains('claude')) {
      avatarUrl = 'https://via.placeholder.com/150/9C27B0';
    } else if (json['id'].toString().contains('gpt')) {
      avatarUrl = 'https://via.placeholder.com/150/4CAF50';
    }

    return Model(
      id: json['id'],
      ownedBy: json['owned_by'],
      contextWindow: json['context_window'],
      avatarUrl: avatarUrl,
    );
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

String _formatTimestamp(String timestamp) {
  try {
    DateTime dateTime = DateTime.parse(timestamp);
    return DateFormat('h:mm a').format(dateTime); // Format as "3:45 PM"
  } catch (e) {
    return "";
  }
}

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
  static Future<void> saveMessages(List<Map<String, dynamic>> messages) async {
    try {
      final chatDir = await _getChatDirectory();
      final file = File('${chatDir.path}/$_currentChatFile');
      
      // Prepare data for saving
      final data = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'messages': messages,
      };
      
      // Write to file
      await file.writeAsString(jsonEncode(data));
      print('Chat saved successfully to ${file.path}');
    } catch (e) {
      print('Error saving chat: $e');
    }
  }

  // Load chat messages
  static Future<List<Map<String, dynamic>>> loadMessages() async {
    try {
      final chatDir = await _getChatDirectory();
      final file = File('${chatDir.path}/$_currentChatFile');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        final List<dynamic> messagesJson = data['messages'];
        
        // Convert to the correct type
        return messagesJson.map((msg) => Map<String, dynamic>.from(msg)).toList();
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
}

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final List<Map<String, dynamic>> _messages = []; // {'role': 'user'|'bot', 'text': '...', 'time': '...', 'avatarUrl': '...'}
  final String _apiUrl = "https://api.groq.com/openai/v1/chat/completions";
  final String _apiKey = ""; // Replace with your actual API key
  bool _isLoading = false;
  List<Model> _models = [];
  bool _isLoadingModels = false;
  String _selectedModelId = "llama-3.3-70b-versatile"; // Default model
  bool _isInitialized = false;

  Model? get _selectedModel {
    return _models.firstWhere(
      (model) => model.id == _selectedModelId,
      orElse: () => Model(
        id: _selectedModelId,
        ownedBy: 'Unknown',
        contextWindow: 0,
        avatarUrl: 'https://via.placeholder.com/150/6a65b3',
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchModels(); // Fetch models when the app starts
    _loadSavedChat(); // Load previous chat
    _textFieldFocusNode.addListener(_handleFocusChange);
    RawKeyboard.instance.addListener(_handleKeyEvent);
    _controller.addListener(() {
      setState(() {}); // Rebuild UI when text changes
    });
  }

  Future<void> _loadSavedChat() async {
    final savedMessages = await ChatStorage.loadMessages();
    
    if (savedMessages.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(savedMessages);
        _isInitialized = true;
      });
      
      // Scroll to bottom after loading messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } else {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _handleFocusChange() {
    if (!_textFieldFocusNode.hasFocus) {
      RawKeyboard.instance.removeListener(_handleKeyEvent);
    } else {
      RawKeyboard.instance.addListener(_handleKeyEvent);
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // Check for Enter key without Shift
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          !event.isShiftPressed) {
        if (_textFieldFocusNode.hasFocus) {
          _sendMessage();
          _textFieldFocusNode.unfocus(); // Optional: close keyboard
        }
      }
    }
  }

  Future<void> _fetchModels() async {
    setState(() {
      _isLoadingModels = true;
    });

    try {
      final response = await http.get(
        Uri.parse("https://api.groq.com/openai/v1/models"),
        headers: {"Authorization": "Bearer $_apiKey"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> modelData = data['data'];

        setState(() {
          _models = modelData.map((model) => Model.fromJson(model)).toList();
          _isLoadingModels = false;
        });
      } else {
        print(
          "Error fetching models: ${response.statusCode} - ${response.body}",
        );
        setState(() {
          _isLoadingModels = false;
        });
      }
    } catch (e) {
      print("Exception occurred while fetching models: $e");
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  Future<String> _fetchBotResponse(String userMessage) async {
    try {
      // Convert previous messages to API format
      List<Map<String, String>> apiMessages = [];
      
      // Add context from previous messages (converting _messages to API format)
      for (var message in _messages) {
        String role = message['role'] == 'user' ? 'user' : 'assistant';
        apiMessages.add({
          'role': role,
          'content': message['text'],
        });
      }
      
      // Add current user message
      apiMessages.add({
        'role': 'user',
        'content': userMessage,
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
        },
        body: jsonEncode({
          "model": _selectedModelId,
          "messages": apiMessages, // Send all messages as context
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'] ??
              "I didn't understand that.";
        } else {
          return "No response from the bot.";
        }
      } else {
        return "Error: ${response.statusCode} - ${response.body}";
      }
    } catch (e) {
      return "Exception occurred: $e";
    }
  }

  void _resetChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2E2E2E),
        title: Text('Reset Chat', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to clear the entire chat history?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Reset', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              // Close the dialog
              Navigator.of(context).pop();
              
              // Clear messages in memory
              setState(() {
                _messages.clear();
              });
              
              // Delete the saved chat file
              await ChatStorage.deleteCurrentChat();
              
              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Chat history has been reset'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showModelDropdown(BuildContext context) {
    if (_isLoadingModels) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Loading models...')));
      return;
    }

    if (_models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No models available. Try again later.')),
      );
      return;
    }

    // Show a custom dialog with scrollable content
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2E2E2E),
          title: Text('Select Model', style: TextStyle(color: Colors.white)),
          content: Container(
            width: double.maxFinite,
            height: 300, // Fixed height for scrollable area
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _models.length,
              itemBuilder: (context, index) {
                final model = _models[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(model.avatarUrl),
                    radius: 15,
                  ),
                  title: Text(
                    model.id,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    'by ${model.ownedBy} | Context: ${model.contextWindow}',
                    style: TextStyle(color: Colors.grey),
                  ),
                  selected: model.id == _selectedModelId,
                  selectedTileColor: Colors.black26,
                  onTap: () {
                    setState(() {
                      _selectedModelId = model.id;
                    });
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    _textFieldFocusNode.dispose();
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final timestamp = DateTime.now().toString();

    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
        'avatarUrl': 'https://via.placeholder.com/150/2196f3',
        'time': timestamp,
      });
      _controller.clear();
      _isLoading = true;
    });
    
    // Save messages after adding user message
    await ChatStorage.saveMessages(_messages);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Get actual response from the API
    final botResponse = await _fetchBotResponse(text);
    final botTimestamp = DateTime.now().toString();

    setState(() {
      _messages.add({
        'role': 'bot',
        'text': botResponse,
        'avatarUrl': _selectedModel?.avatarUrl ?? 'https://via.placeholder.com/150/6a65b3',
        'time': botTimestamp,
      });
      _isLoading = false;
    });
    
    // Save messages after adding bot response
    await ChatStorage.saveMessages(_messages);
    
    // Scroll to show the latest message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    bool isUser = message['role'] == 'user';
    String formattedTime = _formatTimestamp(message['time'] ?? "");

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(message['avatarUrl']),
          SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF2E2E2E) : const Color(0xFF2E2E2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message['text'] ?? '',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  formattedTime,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          if (isUser) _buildAvatar(message['avatarUrl']),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url) {
    return CircleAvatar(backgroundImage: NetworkImage(url), radius: 20);
  }

  Widget _buildTypingIndicator() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(
            _selectedModel?.avatarUrl ?? 'https://via.placeholder.com/150/6a65b3',
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(105, 106, 101, 179),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Typing", style: TextStyle(color: Colors.white)),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2),
              Text(
                "Just now",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final inputAreaMaxHeight = screenHeight * 0.3;
    
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Color(0xFF2E2E2E),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(
                _selectedModel?.avatarUrl ?? 'https://via.placeholder.com/150/6a65b3',
              ),
              radius: 15,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedModel?.displayName ?? 'Model',
                style: TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isLoadingModels)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            IconButton(
              icon: Icon(Icons.arrow_drop_down, color: Colors.white),
              onPressed: _isLoadingModels ? null : () => _showModelDropdown(context),
            ),
            // Reset button
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.white70),
              tooltip: 'Reset Chat',
              onPressed: _resetChat,
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty 
            ? Center(
                child: Text(
                  "Start a new conversation",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                itemCount: _isLoading ? _messages.length + 1 : _messages.length,
                itemBuilder: (context, index) {
                  if (_isLoading && index == _messages.length) {
                    return _buildTypingIndicator();
                  }
                  return _buildMessage(_messages[index]);
                },
              ),
          ),
          Container(
            constraints: BoxConstraints(maxHeight: inputAreaMaxHeight),
            child: Material(
              elevation: 8,
              color: Color(0xFF1A1A1A),
              child: SafeArea(
                bottom: true,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          reverse: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_controller.text.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '${_controller.text.length}/500',
                                      style: TextStyle(
                                        color: _controller.text.length > 450
                                            ? (_controller.text.length >= 500 ? Colors.red : Colors.amber)
                                            : Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: inputAreaMaxHeight - 50, // Reserve space for counter
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: 600,
                                    maxHeight: 120,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF2E2E2E),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.3),
                                      width: 1.0,
                                    ),
                                  ),

                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _controller,
                                            focusNode: _textFieldFocusNode,
                                            keyboardType: TextInputType.multiline,
                                            textInputAction: TextInputAction.newline,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                            maxLength: 500, // Set maximum character limit
                                            maxLengthEnforcement: MaxLengthEnforcement.enforced,
                                            // Remove counter since we have our own
                                            buildCounter: (
                                              context, {
                                              required currentLength,
                                              required isFocused,
                                              maxLength,
                                            }) => null,
                                            // Allow text field to grow with content
                                            minLines: 1,
                                            maxLines: null,
                                            decoration: InputDecoration(
                                              hintText: 'Send a Message....',
                                              hintStyle: TextStyle(
                                                color: Colors.grey,
                                              ),

                                              filled: true,
                                              fillColor: Colors.transparent,
                                              contentPadding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(25),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Color(0xFF3E3E3E),
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.send_rounded,
                                              size: 24,
                                              color: (_controller.text.isEmpty || _controller.text.length > 500)
                                                  ? Colors.grey.withOpacity(0.5) // Disabled state
                                                  : Colors.white.withOpacity(0.9),
                                            ),
                                            onPressed: (_isLoading || _controller.text.isEmpty || _controller.text.length > 500)
                                                ? null
                                                : _sendMessage,
                                            padding: EdgeInsets.all(8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
