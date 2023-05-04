// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

class Signalling {
  final String roomID;
  final String localPeerID;

  late final CollectionReference _roomCollection;

  Function(QuerySnapshot<Object?>)? onMessage;

  Signalling(this.roomID, this.localPeerID) {
    print('Signalling: $roomID, $localPeerID');
    _roomCollection = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomID)
        .collection('messages');
    _roomCollection.snapshots().listen((event) {
      onMessage?.call(event);
    });
  }

  Future<void> sendMessage(String type, dynamic message,
      {bool announce = false}) async {
    await _roomCollection.add({
      'from': localPeerID,
      'message': message,
      'type': type,
      'announce': announce,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> joinRoom() async {
    await sendMessage('join', {}, announce: true);
  }
}
