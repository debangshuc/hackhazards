import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

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
    required this.avatarUrl
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

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // {'role': 'user'|'bot', 'text': '...', 'time': '...', 'avatarUrl': '...'}
  final String _apiUrl = "https://api.groq.com/openai/v1/chat/completions";
  final String _apiKey = "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"; // Replace with your actual API key
  bool _isLoading = false;
  List<Model> _models = [];
  bool _isLoadingModels = false;
  String _selectedModelId = "llama-3.3-70b-versatile"; // Default model
  
  Model? get _selectedModel {
    return _models.firstWhere(
      (model) => model.id == _selectedModelId,
      orElse: () => Model(
        id: _selectedModelId, 
        ownedBy: 'Unknown', 
        contextWindow: 0,
        avatarUrl: 'https://via.placeholder.com/150/6a65b3'
      )
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchModels(); // Fetch models when the app starts
  }

  Future<void> _fetchModels() async {
    setState(() {
      _isLoadingModels = true;
    });

    try {
      final response = await http.get(
        Uri.parse("https://api.groq.com/openai/v1/models"),
        headers: {
          "Authorization": "Bearer $_apiKey",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> modelData = data['data'];
        
        setState(() {
          _models = modelData.map((model) => Model.fromJson(model)).toList();
          _isLoadingModels = false;
        });
      } else {
        print("Error fetching models: ${response.statusCode} - ${response.body}");
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
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_apiKey",
        },
        body: jsonEncode({
          "model": _selectedModelId,
          "messages": [
            {
              "role": "user",
              "content": userMessage,
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'] ?? "I didn't understand that.";
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

  void _showModelDropdown(BuildContext context) {
    if (_isLoadingModels) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loading models...'))
      );
      return;
    }
    
    if (_models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No models available. Try again later.'))
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
                  title: Text(model.id, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text('by ${model.ownedBy} | Context: ${model.contextWindow}', style: TextStyle(color: Colors.grey)),
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

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final timestamp = DateTime.now().toString();

    setState(() {
      _messages.add({
        'role': 'user', 
        'text': text,
        'avatarUrl': 'https://via.placeholder.com/150/2196f3',
        'time': timestamp
      });
      _controller.clear();
      _isLoading = true;
    });

    // Get actual response from the API
    final botResponse = await _fetchBotResponse(text);
    final botTimestamp = DateTime.now().toString();
    
    setState(() {
      _messages.add({
        'role': 'bot', 
        'text': botResponse,
        'avatarUrl': _selectedModel?.avatarUrl ?? 'https://via.placeholder.com/150/6a65b3',
        'time': botTimestamp
      });
      _isLoading = false;
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
                  )
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
    return CircleAvatar(
      backgroundImage: NetworkImage(url),
      radius: 20,
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(_selectedModel?.avatarUrl ?? 'https://via.placeholder.com/150/6a65b3'),
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
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Color(0xFF2E2E2E),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(_selectedModel?.avatarUrl ?? 'https://via.placeholder.com/150/6a65b3'),
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
              )
            else
              IconButton(
                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                onPressed: () => _showModelDropdown(context),
              ),
          ],
        ),
      ),
      
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _isLoading ? _messages.length + 1 : _messages.length,
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Divider(height: 1.5, color: Colors.grey.shade800),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Send a Message....',
                      hintStyle: TextStyle(
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: Color(0xFF2E2E2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.white),
                  onPressed: _isLoading ? null : _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
