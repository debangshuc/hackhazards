import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme.dart';
import 'chat_page.dart';

void main() async {
  // Ensure Flutter binding is initialized before anything else
  WidgetsFlutterBinding.ensureInitialized();
  
  // Run app
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const ChatBotApp(),
    ),
  );
}

class ChatBotApp extends StatelessWidget {
  const ChatBotApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'WebUI Chat',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode,
      home: const ChatPage(),
    );
  }
}
