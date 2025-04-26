import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import 'theme.dart';
import 'models/model.dart';
import 'models/message.dart';
import 'services/api_service.dart';
import 'services/chat_storage.dart';
import 'services/image_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final List<PlatformFile> _attachments = [];
  final FilePicker _filePicker = FilePicker.platform;
  
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  List<Model> _models = [];
  bool _isLoadingModels = false;
  String _selectedModelId = "llama-3.1-70b-instant"; // Default model
  bool _isInitialized = false;
  bool _enableImageSupport = false;

  Model? get _selectedModel {
    try {
      return _models.firstWhere(
        (model) => model.id == _selectedModelId,
        orElse: () => Model(
          id: _selectedModelId,
          ownedBy: 'Unknown',
          contextWindow: 0,
          provider: 'groq',
        ),
      );
    } catch (e) {
      return Model(
        id: _selectedModelId,
        ownedBy: 'Unknown',
        contextWindow: 0,
        provider: 'groq',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Load models and chat history
    _loadApiKey().then((_) => _fetchModels());
    _loadSavedChat();
    
    // Set up listeners
    _textFieldFocusNode.addListener(_handleFocusChange);
    RawKeyboard.instance.addListener(_handleKeyEvent);
    _controller.addListener(() {
      setState(() {}); // Rebuild UI when text changes
    });
  }

  Future<void> _loadApiKey() async {
    final apiKey = await ApiService.getApiKey();
    print('API key loaded: ${apiKey.isNotEmpty ? 'Yes' : 'No'}');
  }

  Future<void> _pickFiles() async {
    try {
      final result = await _filePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'txt', 'doc', 'docx'],
      );

      if (result != null) {
        // Filter out files that are too large
        final validFiles =
            result.files.where((f) => f.size < 5 * 1024 * 1024).toList();
        final rejectedFiles =
            result.files.where((f) => f.size >= 5 * 1024 * 1024).toList();

        setState(() {
          _attachments.addAll(validFiles);
        });

        // Show error for large files
        if (rejectedFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${rejectedFiles.length} file(s) exceeded 5MB limit',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }

        // Show confirmation for added files
        if (validFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${validFiles.length} file(s)'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    if (index >= 0 && index < _attachments.length) {
      final fileName = _attachments[index].name;
      setState(() {
        _attachments.removeAt(index);
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed: $fileName'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showSettingsDialog(BuildContext context) {
    // Create a controller for the API key text field
    final TextEditingController apiKeyController = TextEditingController();
    bool obscureText = true; // State to toggle API key visibility

    // Load the current API key
    ApiService.getApiKey().then((apiKey) {
      apiKeyController.text = apiKey;
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Settings'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'API Key',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: apiKeyController,
                      obscureText: obscureText,
                      decoration: InputDecoration(
                        hintText: 'Enter your API key',
                        filled: true,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureText
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureText = !obscureText;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Your API key is stored locally and used only for API requests.',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 16),
                    
                    // Image support toggle
                    SwitchListTile(
                      title: Text('Enable Image Support'),
                      subtitle: Text('Send images to vision-capable models'),
                      value: _enableImageSupport,
                      onChanged: (value) {
                        setState(() {
                          _enableImageSupport = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Save'),
                  onPressed: () async {
                    // Update the API key
                    final newApiKey = apiKeyController.text.trim();
                    await ApiService.saveApiKey(newApiKey);
                    
                    // Update state
                    this.setState(() {
                      this._enableImageSupport = _enableImageSupport;
                    });

                    // Show confirmation
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Settings updated'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Close dialog
                    Navigator.of(context).pop();

                    // Refresh models with new API key
                    _fetchModels();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadSavedChat() async {
    final savedMessages = await ChatStorage.loadMessages();

    if (savedMessages.isNotEmpty) {
      setState(() {
        _messages = savedMessages;
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
      final models = await ApiService.fetchModels();
      
      setState(() {
        _models = models;
        _isLoadingModels = false;
      });
    } catch (e) {
      print("Exception occurred while fetching models: $e");
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  void _resetChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Chat'),
        content: Text(
          'Are you sure you want to clear the entire chat history?',
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loading models...')),
      );
      return;
    }

    if (_models.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No models available. Try again later.')),
      );
      return;
    }

    // Group models by provider
    Map<String, List<Model>> modelsByProvider = {};
    for (var model in _models) {
      if (!modelsByProvider.containsKey(model.provider)) {
        modelsByProvider[model.provider] = [];
      }
      modelsByProvider[model.provider]!.add(model);
    }

    // Show a custom dialog with scrollable content
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Model'),
          content: Container(
            width: double.maxFinite,
            height: 400, // Fixed height for scrollable area
            child: SingleChildScrollView(
              child: Column(
                children: modelsByProvider.entries.map((entry) {
                  final provider = entry.key;
                  final providerModels = entry.value;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          provider.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      ...providerModels.map((model) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: model.avatarColor,
                          child: model.id.length > 0 
                              ? Text(model.id[0].toUpperCase())
                              : Icon(Icons.smart_toy),
                        ),
                        title: Text(
                          model.id,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'by ${model.ownedBy} | Context: ${model.contextWindow}',
                        ),
                        selected: model.id == _selectedModelId,
                        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                        onTap: () {
                          setState(() {
                            _selectedModelId = model.id;
                          });
                          Navigator.of(context).pop();
                        },
                      )).toList(),
                      Divider(),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
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

  Future<void> _openFile(String? path) async {
    if (path == null) return;

    try {
      await OpenFile.open(path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open file: ${e.toString()}')),
      );
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    // Create attachments list
    List<Map<String, dynamic>> attachmentsList = _attachments
        .map(
          (f) => {
            'name': f.name,
            'path': f.path,
            'extension': f.extension,
          },
        )
        .toList();

    // Create user message
    final userMessage = ChatMessage(
      role: 'user',
      text: text,
      attachments: attachmentsList,
      avatarUrl: 'https://via.placeholder.com/150/2196f3',
    );

    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _attachments.clear(); // Clear attachments after sending
      _isLoading = true;
    });

    // Save messages after adding user message
    await ChatStorage.saveMessages(_messages);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Get response from the API
    final botResponse = await ApiService.sendChatMessage(
      _selectedModelId,
      _messages,
      withImages: _enableImageSupport,
    );

    // Create bot message
    final botMessage = ChatMessage(
      role: 'bot',
      text: botResponse,
      avatarUrl: _selectedModel?.avatarFallbackUrl ?? 'https://via.placeholder.com/150/6a65b3',
    );

    setState(() {
      _messages.add(botMessage);
      _isLoading = false;
    });

    // Save messages after adding bot response
    await ChatStorage.saveMessages(_messages);

    // Scroll to show the latest message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Widget _buildMessage(ChatMessage message) {
    bool isUser = message.role == 'user';
    List<Map<String, dynamic>> attachments = message.attachments;
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(message.avatarUrl),
          SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser 
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                    children: [
                      if (message.text.isNotEmpty)
                        SelectableText(
                          message.text,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      if (attachments.isNotEmpty)
                        Column(
                          children: [
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: attachments.map<Widget>((file) {
                                return GestureDetector(
                                  onTap: () => _openFile(file['path']),
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: themeProvider.isDarkMode
                                          ? Color(0xFF3A3A3A)
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ImageService.getFileIcon(
                                          file['extension'],
                                          color: Theme.of(context).iconTheme.color!,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          file['name'],
                                          style: TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  message.formattedTime,
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          if (isUser) _buildAvatar(message.avatarUrl),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url) {
    return CircleAvatar(
      backgroundImage: CachedNetworkImageProvider(url),
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
          _buildAvatar(
            _selectedModel?.avatarFallbackUrl ?? 'https://via.placeholder.com/150/6a65b3',
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Typing"),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2),
              Text(
                "Just now",
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).textTheme.bodySmall?.color,
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
    final bool isButtonDisabled =
        _isLoading ||
        (_controller.text.isEmpty && _attachments.isEmpty) ||
        _controller.text.length > 4000;
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: _selectedModel?.avatarColor ?? Colors.blue,
              child: Text(
                _selectedModel?.displayName.substring(0, 1).toUpperCase() ?? 'M',
                style: TextStyle(color: Colors.white),
              ),
              radius: 15,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedModel?.displayName ?? 'Model',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isLoadingModels)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            IconButton(
              icon: Icon(Icons.arrow_drop_down),
              onPressed:
                  _isLoadingModels ? null : () => _showModelDropdown(context),
            ),
            // Theme toggle
            IconButton(
              icon: Icon(themeProvider.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
              tooltip: 'Toggle Theme',
              onPressed: () => themeProvider.toggleTheme(),
            ),
            // Settings button
            IconButton(
              icon: Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => _showSettingsDialog(context),
            ),
            // Reset button
            IconButton(
              icon: Icon(Icons.delete_outline),
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
                    itemCount:
                        _isLoading ? _messages.length + 1 : _messages.length,
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
              child: SafeArea(
                bottom: true,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // File previews
                      if (_attachments.isNotEmpty)
                        Container(
                          height: 80,
                          padding: EdgeInsets.only(bottom: 8),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _attachments.length,
                            itemBuilder: (context, index) {
                              final file = _attachments[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey[800]
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: file.extension?.toLowerCase() == 'png' ||
                                              file.extension?.toLowerCase() == 'jpg' ||
                                              file.extension?.toLowerCase() == 'jpeg'
                                          ? Image.file(
                                              File(file.path!),
                                              fit: BoxFit.cover,
                                            )
                                          : Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                ImageService.getFileIcon(
                                                  file.extension,
                                                  color: Theme.of(context).iconTheme.color!,
                                                ),
                                                Text(
                                                  file.extension ?? 'file',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          size: 16,
                                        ),
                                        onPressed: () => _removeAttachment(index),
                                        padding: EdgeInsets.all(4),
                                        constraints: BoxConstraints(),
                                        splashRadius: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      // Input row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // File pick button
                          IconButton(
                            icon: Icon(Icons.attach_file),
                            onPressed: _pickFiles,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _textFieldFocusNode,
                              maxLines: null,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: 'Type your message...',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          // Send button
                          Container(
                            decoration: BoxDecoration(
                              color: isButtonDisabled
                                  ? Theme.of(context).disabledColor
                                  : Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.send_rounded,
                                color: isButtonDisabled
                                    ? Theme.of(context).disabledColor.withOpacity(0.5)
                                    : Colors.white,
                              ),
                              onPressed: isButtonDisabled ? null : _sendMessage,
                            ),
                          ),
                        ],
                      ),
                      // Character counter
                      if (_controller.text.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '${_controller.text.length}/4000',
                              style: TextStyle(
                                color: _controller.text.length > 3500
                                    ? (_controller.text.length >= 4000
                                        ? Colors.red
                                        : Colors.amber)
                                    : Colors.grey,
                                fontSize: 12,
                              ),
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