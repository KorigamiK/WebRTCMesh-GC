// ignore_for_file: avoid_print

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:lmnop/services/signalling.dart';

enum PeerConnectionState {
  new_,
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

class PeerConnection {
  PeerConnectionState state;
  RTCPeerConnection? conn;
  RTCDataChannel? dataChannel;

  PeerConnection({this.state = PeerConnectionState.new_, this.conn});

  Future<void> dispose() async {
    await conn?.dispose();
  }
}

class WebRTCMesh {
  final Map<String, dynamic> configuration = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'}
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> offerOptions = {
    'offerToReceiveAudio': 0,
    'offerToReceiveVideo': 0,
  };

  final Map<String, PeerConnection> _peerConnections = {};
  final List<String> _connectingQueue = [];

  final String roomID;
  late final String localPeerID;
  late final Signalling _signalling;

  WebRTCMesh(this.roomID, String? peerID) {
    localPeerID = peerID ?? const Uuid().v4();
    _signalling = Signalling(roomID, localPeerID);
    _signalling.onMessage = onMessage;
    _signalling.joinRoom();
  }

  void _addPeer(String peerID) {
    if (_peerConnections.containsKey(peerID)) return;
    _peerConnections[peerID] = PeerConnection(); // new peer
    if (!_connectingQueue.contains(peerID)) {
      _connectingQueue.add(peerID);
    }
  }

  Future<void> _removePeer(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    await _peerConnections[peerID]!.dispose();
    _peerConnections[peerID]!.state = PeerConnectionState.closed;
    _peerConnections.remove(peerID);
  }

  Future<void> _closePeerConnection(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    _removePeer(peerID);
    await _signalling.sendMessage('leave', {}, announce: true);
  }

  Future<void> connect() async {
    while (_connectingQueue.isNotEmpty) {
      final peerID = _connectingQueue.removeAt(0);
      await _createPeer(peerID); // connecting
      await _connectPeer(peerID); // connected
    }
  }

  Future<void> _connectPeer(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    final pc = _peerConnections[peerID]!;
    final offer = await pc.conn!.createOffer(offerOptions);
    await pc.conn!.setLocalDescription(offer);
    await _signalling.sendMessage('offer', {
      'sdp': offer.sdp,
      'type': offer.type,
      'to': peerID,
    });
  }

  Future<void> _createPeer(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    final pc = _peerConnections[peerID]!;
    pc.conn = await createPeerConnection(configuration);
    pc.state = PeerConnectionState.connecting;
    pc.conn!.onIceCandidate = (candidate) async {
      if (candidate.candidate == null) return;
      await _signalling.sendMessage('candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'to': peerID,
      });
    };
    pc.conn!.onTrack = (event) {
      print('onTrack: ${event.track.id}');
    };
  }

  Future<void> onMessage(QuerySnapshot<Object?> event) async {
    for (final doc in event.docChanges) {
      final data = doc.doc.data() as Map<String, dynamic>;
      final peerID = data['peerID'] as String;
      if (peerID == localPeerID) {
        continue;
      }
      final type = data['type'] as String;
      final message = data['message'] as Map<String, dynamic>;
      switch (type) {
        case 'join':
          await _addPeer(peerID);
          break;
        case 'offer':
          if (message['to'] == localPeerID) {
            await _setRemoteDescription(
                peerID,
                RTCSessionDescription(
                  message['sdp'],
                  message['type'],
                ));
            await _createAnswer(peerID);
          }
          break;
        case 'answer':
          if (message['to'] == localPeerID) {
            await _setRemoteDescription(
                peerID,
                RTCSessionDescription(
                  message['sdp'],
                  message['type'],
                ));
          }
          break;
        case 'candidate':
          if (message['to'] == localPeerID) {
            await _addCandidate(
                peerID,
                RTCIceCandidate(
                  message['candidate'],
                  message['sdpMid'],
                  message['sdpMLineIndex'],
                ));
          }
          break;
        case 'leave':
          await _closePeerConnection(peerID);
          break;
        default:
          print('Unknown message type: $type');
      }
    }
  }
}
