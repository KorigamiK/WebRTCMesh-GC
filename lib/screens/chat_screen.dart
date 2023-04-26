// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lmnop/models/chat_client.dart';
import 'package:lmnop/utils/message.dart';

class ChatScreen extends StatefulWidget {
  final ChatClient client;

  const ChatScreen({Key? key, required this.client}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<Message> _messages = [];
  RawDatagramSocket? _socket;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();

    _initSocket();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _socket?.close();
    super.dispose();
  }

  void _initSocket() async {
    print('Init socket: ${widget.client.host}:${widget.client.port}');

    _socket = await RawDatagramSocket.bind(
      widget.client.address,
      widget.client.port,
      reuseAddress: true,
      reusePort: true,
    );

    _socket?.listen((event) {
      print('Event: $event');
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        final message = String.fromCharCodes(datagram!.data).trim();
        final sender = datagram.address;

        setState(() {
          print('Received: $message from $sender');
          _messages.add(Message(
            sender: sender.toString(),
            text: message,
            isMe: false,
          ));
        });
      }
    });

    _socket?.send(
      utf8.encode('Connected to ${widget.client.host}:${widget.client.port}'),
      widget.client.address,
      widget.client.port,
    );

    _subscription = StreamController<Message>.broadcast().stream.listen(
      (message) {
        setState(() {
          _messages.add(message);
        });
      },
    );
  }

  void _sendMessage() {
    final messageText = _textController.text.trim();

    if (messageText.isNotEmpty) {
      final message = Message(
        sender: InternetAddress.anyIPv4.toString(),
        text: messageText,
        isMe: true,
      );
      final encodedMessage = utf8.encode(messageText);
      print('Sending: $messageText');

      var x = _socket?.send(
          encodedMessage, widget.client.address, widget.client.port);
      print('x: $x');
      _textController.clear();

      setState(() {
        _messages.add(message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UDP Chat App'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // show the current connected client
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  const Text(
                    'Connected to: ',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.client.host}:${widget.client.port}',
                    style: const TextStyle(
                      fontSize: 16.0,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final message = _messages[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: message.isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: message.isMe
                                ? Colors.green[100]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: message.isMe
                                  ? Colors.green[800]
                                  : Colors.grey[800],
                              fontSize: 16.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Type a message',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
