// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'}
    ]
  };
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  Function(String)? onDataChannelMessage;

  Future<String> createRoom() async {
    final roomId = FirebaseFirestore.instance.collection('rooms').doc().id;
    final offer = await _createOffer();
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .set({'offer': offer.sdp});
    return roomId;
  }

  Future<void> joinRoom(String roomId) async {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    final roomSnapshot = await roomRef.get();
    final offerSdp = roomSnapshot.get('offer');
    final offer = RTCSessionDescription(offerSdp, 'offer');
    await _createAnswer(offer, roomId);
    await roomRef.delete();
  }

  Future<void> _createAnswer(RTCSessionDescription offer, String roomID) async {
    final mediaConstraints = {'audio': false, 'video': false};
    _peerConnection =
        await createPeerConnection(_configuration, mediaConstraints);
    _peerConnection?.onIceCandidate = (candidate) {
      _sendCandidate(candidate);
    };

    _peerConnection?.onDataChannel = (channel) {
      _dataChannel = channel;
      _dataChannel?.onMessage = (message) {
        final object = jsonDecode(utf8.decode(message.binary));
        onDataChannelMessage?.call(object['message']);
        print("object: $object");
      };
    };

    await _peerConnection?.setRemoteDescription(offer);
    final answer = await _peerConnection?.createAnswer(mediaConstraints);
    await _peerConnection?.setLocalDescription(answer!);

    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomID);
    await roomRef.set({'answer': answer?.sdp});

    final offerCandidates = await _waitForCandidates(roomID);
    final answerCandidates = await _waitForCandidates(roomID);
    await roomRef.set({
      'offerCandidates': jsonEncode(offerCandidates),
      'answerCandidates': jsonEncode(answerCandidates)
    });
  }

  Future<void> _sendCandidate(RTCIceCandidate candidate) async {
    final roomId = FirebaseFirestore.instance.collection('rooms').doc().id;
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .set({'candidate': candidate.toMap()});
  }

  Future<RTCSessionDescription> _createOffer() async {
    _peerConnection = await createPeerConnection(_configuration, {});
    _peerConnection?.onIceCandidate = (candidate) {
      _sendCandidate(candidate);
    };

    _dataChannel = await _peerConnection?.createDataChannel(
        'data_channel', RTCDataChannelInit());
    _dataChannel?.onMessage = (message) {
      final object = jsonDecode(utf8.decode(message.binary));
      // Handle received object
      onDataChannelMessage?.call(object['message']);
      print("object: $object");
    };

    final offer = await _peerConnection?.createOffer({});
    await _peerConnection?.setLocalDescription(offer!);

    return offer!;
  }

  /// Wait for candidates to be added to the room.
  Future<List<RTCIceCandidate>> _waitForCandidates(String roomID) async {
    final candidates = <RTCIceCandidate>[];
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomID);
    final stream = await roomRef.snapshots().first;
    if (stream.exists) {
      final data = stream.data()!;
      if (data.containsKey('candidate')) {
        final candidateMap = data['candidate'];
        final candidate = RTCIceCandidate(candidateMap['candidate'],
            candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
        candidates.add(candidate);
      } else if (data.containsKey('offerCandidates')) {
        final offerCandidates = jsonDecode(data['offerCandidates']);
        for (final candidateMap in offerCandidates) {
          final candidate = RTCIceCandidate(candidateMap['candidate'],
              candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
          candidates.add(candidate);
        }
      } else if (data.containsKey('answerCandidates')) {
        final answerCandidates = jsonDecode(data['answerCandidates']);
        for (final candidateMap in answerCandidates) {
          final candidate = RTCIceCandidate(candidateMap['candidate'],
              candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);
          candidates.add(candidate);
        }
      }
    }
    return candidates;
  }

  Future<void> sendObject(String message) async {
    final obj = jsonEncode({'message': message});
    final data = RTCDataChannelMessage(obj);
    await _dataChannel?.send(data);
  }

  Future<void> dispose() async {
    await _dataChannel?.close();
    await _peerConnection?.close();
  }
}
