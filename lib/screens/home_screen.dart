import 'package:flutter/material.dart';

import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _roomIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebRTC Chat'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: TextField(
                controller: _roomIdController,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), hintText: 'Enter Room ID'),
              ),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LobbyScreen(
                      roomId: _roomIdController.text,
                    ),
                  ),
                );
              },
              child: const Text('Join Room'),
            ),
            const SizedBox(height: 10.0),
            ElevatedButton(
              onPressed: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LobbyScreen(
                      createRoom: true,
                    ),
                  ),
                );
              },
              child: const Text('Create Room'),
            ),
          ],
        ),
      ),
    );
  }
}
