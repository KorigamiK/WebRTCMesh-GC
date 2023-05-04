// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lmnop/screens/chat_screen.dart';

String generateRoomID() {
  return DateTime.now().millisecondsSinceEpoch.toString();
}

class LobbyScreen extends StatelessWidget {
  late final String roomId;
  final bool createRoom; // create room if it doesn't exist
  late final int _createdAt;

  Future<void> _getRoom() async {
    DocumentSnapshot<Map<String, dynamic>> room;
    try {
      room = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .get();
    } catch (e) {
      throw Exception('Bad roomID $roomId');
    }
    if (room.exists) {
      _createdAt = room.data()!['created'];
    } else {
      if (createRoom) {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId)
            .set({'created': DateTime.now().millisecondsSinceEpoch});
        _createdAt = DateTime.now().millisecondsSinceEpoch;
      } else {
        throw Exception('Room $roomId does not exist');
      }
    }
  }

  LobbyScreen({Key? key, String? roomId, this.createRoom = false})
      : super(key: key) {
    if (createRoom) {
      this.roomId = roomId = generateRoomID();
      print('Creating room $roomId');
    } else {
      print('Joining room $roomId');
      this.roomId = roomId ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rooms'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Room ID: $roomId'),
            const SizedBox(height: 20.0),
            roomOptions(),
          ],
        ),
      ),
    );
  }

  Widget roomOptions() {
    return FutureBuilder(
      future: _getRoom(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Created At: $_createdAt'),
              const SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        roomId: roomId,
                      ),
                    ),
                  );
                },
                child: const Text('Enter Room'),
              )
            ],
          );
        } else if (snapshot.hasError) {
          return Text(snapshot.error.toString());
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }
}
