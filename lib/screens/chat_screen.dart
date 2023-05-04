import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;

  const ChatScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Room ID: ${widget.roomId}'),
          ],
        ),
      ),
    );
  }
}
