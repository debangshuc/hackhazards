import 'package:flutter/material.dart';

void main() {
  runApp(ChatBotApp());
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

class ChatPage extends StatefulWidget {
  
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = []; // {'role': 'user'|'bot', 'text': '...'}
  
  void _showDropdownMenu(BuildContext context) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(0, 50, 100, 0), // Adjust position as needed
      items: [
        PopupMenuItem(
          value: 1,
          child: Text('Option 1'),
        ),
        PopupMenuItem(
          value: 2,
          child: Text('Option 2'),
        ),
        PopupMenuItem(
          value: 3,
          child: Text('Option 3'),
        ),
      ],
    ).then((value) {
      // Handle selection if needed
      if (value != null) {
        return null;
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _controller.clear();
    });

    // Simulate model (bot) reply
    Future.delayed(Duration(milliseconds: 500), () {
      setState(() {
        _messages.add({'role': 'bot', 'text': _generateBotResponse(text)});
      });
    });
  }

  String _generateBotResponse(String userMessage) {
    // Very basic "AI" logic
    return "I have recieved your Message";
  }

  Widget _buildMessage(Map<String, String> message) {
    bool isUser = message['role'] == 'user';
    return Container(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? const Color.fromARGB(255, 120, 212, 204) : const Color.fromARGB(105, 106, 101, 179),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message['text'] ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text('Choose Model'),
              IconButton(
                icon:Icon(Icons.arrow_drop_down),
                onPressed: () => _showDropdownMenu(context),
                
              ),
            ],
          ),
        ),
      
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Send a Message....',
                      hintStyle: TextStyle(
                      color: Colors.grey.withValues(), // Adjust opacity for subtlety
                      shadows: [
                      Shadow(
                      color: Colors.grey, // Shadow color
                      offset: Offset(0, 0), // No offset for a uniform blur effect
                     ),
                     ],
                    ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  // add style here 
                  onPressed: _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}