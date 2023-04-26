import 'package:flutter/material.dart';
import 'package:lmnop/screens/chat_screen.dart';
import 'package:lmnop/screens/home_screen.dart';
import 'package:lmnop/models/chat_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UDP Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/chat': (context) => ChatScreen(
              client: ModalRoute.of(context)!.settings.arguments as ChatClient,
            ),
      },
    );
  }
}
