import 'package:flutter/material.dart';
import 'package:lmnop/services/webrtc.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final WebRTCMesh webRTCMesh;

  ChatScreen({Key? key, required this.roomId})
      : webRTCMesh = WebRTCMesh(roomID: roomId),
        super(key: key);

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
            Text('Local Peer ID: ${widget.webRTCMesh.localPeerID}'),
            ElevatedButton(
                onPressed: () {
                  widget.webRTCMesh.sendToAllPeers('Hello World');
                },
                child: const Text('Send Message')),
            ElevatedButton(
                onPressed: () {
                  widget.webRTCMesh.printPeers();
                },
                child: const Text('Print Peers')),
          ],
        ),
      ),
    );
  }
}
