import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lmnop/models/chat_client.dart';
import 'package:lmnop/screens/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  void _connect() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 0;

    if (host.isNotEmpty && port > 0) {
      final client = ChatClient(
        host: host,
        port: port,
        address: InternetAddress(host),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(client: client),
        ),
      );
    }
  }

  void _host() async {
    final server = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          client: ChatClient(
            host: server.address.address,
            port: server.port,
            address: InternetAddress.anyIPv4,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UDP Chat App'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect to an existing server:',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  hintText: 'Enter the host name or IP address',
                ),
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: 'Enter the port number',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _connect,
                child: const Text('Connect'),
              ),
              const SizedBox(height: 32.0),
              const Text(
                'Host a new server:',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _host,
                child: const Text('Host'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
