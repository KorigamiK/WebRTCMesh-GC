import 'package:flutter/material.dart';
import 'package:lmnop/screens/chat_screen.dart';
import 'package:lmnop/services/webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LobbyScreen extends StatefulWidget {
  final String roomId;
  final WebRTCService webRTCService;

  const LobbyScreen(
      {super.key, required this.roomId, required this.webRTCService});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('users')
        .snapshots();
  }

  @override
  void dispose() {
    widget.webRTCService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lobby ${widget.roomId}'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          } else {
            final users = snapshot.data!.docs.map((doc) => doc.id).toList();
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(users[index]));
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await widget.webRTCService.joinRoom(widget.roomId);
          if (!mounted) return;
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) =>
                  ChatScreen(webRTCService: widget.webRTCService)));
        },
        child: const Icon(Icons.waves),
      ),
    );
  }
}
