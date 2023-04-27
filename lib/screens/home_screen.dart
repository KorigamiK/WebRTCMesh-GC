import 'package:flutter/material.dart';
import 'package:lmnop/screens/lobby_screen.dart';
import 'package:lmnop/services/webrtc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _roomIdController = TextEditingController();
  final webRTCService = WebRTCService();

  Future<void> createRoom() async {
    final roomId = await webRTCService.createRoom();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>
            LobbyScreen(roomId: roomId, webRTCService: webRTCService)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create or Join a Room'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _roomIdController,
              decoration: const InputDecoration(
                hintText: 'Enter Room ID',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final roomId = _roomIdController.text.trim();
                if (roomId.isNotEmpty) {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => LobbyScreen(
                            roomId: roomId,
                            webRTCService: webRTCService,
                          )));
                }
              },
              child: const Text('Join Room'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: createRoom,
              child: const Text('Create Room'),
            ),
          ],
        ),
      ),
    );
  }
}
