import 'dart:io';

class ChatClient {
  final String host;
  final int port;
  final InternetAddress address;

  ChatClient({required this.host, required this.port, required this.address});
}
