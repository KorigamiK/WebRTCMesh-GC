// ignore_for_file: avoid_print

import 'dart:convert';

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

  @override
  toString() {
    return 'PeerConnection: $state';
  }

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

  void printPeers() {
    print('Peers: $_peerConnections');
    print('Connecting: $_connectingQueue');
  }

  WebRTCMesh({required this.roomID, String? peerID}) {
    localPeerID = peerID ?? const Uuid().v4();
    _signalling = Signalling(roomID, localPeerID);
    _signalling.onMessage = onMessage;
    _signalling.sendMessage('join', {},
        announce: true); // send joining announcement
  }

  void _addPeer(String peerID) {
    if (_peerConnections.containsKey(peerID)) return;
    _peerConnections[peerID] = PeerConnection(); // new peer
    if (!_connectingQueue.contains(peerID)) {
      _connectingQueue.add(peerID);
    }
  }

  Future<void> _closePeerConnection(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    await _peerConnections[peerID]!.dispose();
    _peerConnections[peerID]!.state = PeerConnectionState.closed;
    _peerConnections.remove(peerID);
  }

  Future<void> _setDataChannel(String peerID) async {
    final pc = _peerConnections[peerID]!;
    print('creating data channel for $peerID');
    pc.dataChannel =
        await pc.conn!.createDataChannel('data', RTCDataChannelInit());
    pc.dataChannel!.onMessage = _handleDataChannelMessage(peerID);
    pc.dataChannel!.onDataChannelState = _handleDataChannelState(peerID);
  }

  Future<void> sendToPeer(String peerID, String message) async {
    final pc = _peerConnections[peerID]!;
    if (pc.dataChannel == null) {
      print('data channel not ready for $peerID');
      return;
    }
    print('sending to $peerID: $message');
    await pc.dataChannel!.send(RTCDataChannelMessage(message));
  }

  Future<void> sendToAllPeers(String message) async {
    for (final peerID in _peerConnections.keys) {
      await sendToPeer(peerID, message);
    }
  }

  Future<void> _createOffer(String peerID) async {
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

  Future<void> _connectPeer(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    print('connecting to $peerID');
    await _setDataChannel(peerID);
    await _createOffer(peerID);
  }

  Future<void> _createPeer(String peerID) async {
    if (_peerConnections[peerID]?.conn != null) return;
    final pc = _peerConnections[peerID]!;
    pc.conn = await createPeerConnection(configuration);
    pc.state = PeerConnectionState.connecting;

    pc.conn!.onIceCandidate = (candidate) async {
      if (candidate.candidate == null) return;
      print('sending answer with icecandidate to $peerID');
      await _signalling.sendMessage('candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'to': peerID,
      });
    };

    pc.conn!.onIceConnectionState = (state) {
      print('onIceConnectionState: $state for $peerID');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          pc.state = PeerConnectionState.failed;
          pc.conn!.restartIce();
          break;
        default:
          break;
      }
    };

    pc.conn!.onDataChannel = (channel) {
      print('onDataChannel: ${channel.label}');
      pc.dataChannel = channel;
      pc.dataChannel!.onMessage = _handleDataChannelMessage(peerID);
      pc.dataChannel!.onDataChannelState = _handleDataChannelState(peerID);
    };

    pc.conn!.onTrack = (event) {
      print('onTrack: ${event.track.id}');
    };
  }

  Function(RTCDataChannelMessage) _handleDataChannelMessage(String peerID) {
    final peer = _peerConnections[peerID]!;
    return (RTCDataChannelMessage message) {
      print('received: ${message.text}');
      Map<String, dynamic> data;
      final jsonStr = String.fromCharCodes(message.binary);
      data = jsonDecode(jsonStr);
      final type = data['type'];
      final pid = data['from'];
      // final payload = data['payload'];
      switch (type) {
        case 'handshake':
          print('handshake from $pid');
          peer.state = PeerConnectionState.connected;
          break;
        default:
          print('unknown message type: $type');
      }
    };
  }

  Function(RTCDataChannelState) _handleDataChannelState(String peerID) {
    final peer = _peerConnections[peerID]!;
    return (RTCDataChannelState state) {
      print('data channel state: $state');
      switch (state) {
        case RTCDataChannelState.RTCDataChannelOpen:
          print('data channel opened');
          peer.dataChannel!.send(RTCDataChannelMessage(jsonEncode({
            'type': 'handshake',
            'from': localPeerID,
          })));
          break;
        case RTCDataChannelState.RTCDataChannelClosed:
          print('data channel closed');
          break;
        default:
      }
    };
  }

  /// Start connection signalling for all peers in the connectingQueue
  Future<void> _connect() async {
    while (_connectingQueue.isNotEmpty) {
      final peerID = _connectingQueue.removeAt(0);
      await _createPeer(peerID); // new peer in connecting state
      await _connectPeer(peerID); // initiate connection signalling
    }
  }

  Future<void> _handleOffer(String peerID, Map<String, dynamic> message) async {
    if (_peerConnections.containsKey(peerID)) {
      assert(_peerConnections[peerID]?.conn != null);
      final pc = _peerConnections[peerID]!;
      print('handling offer from $peerID');
      // if ((await pc.conn!.getRemoteDescription()) == null) {
      await pc.conn!.setRemoteDescription(
        RTCSessionDescription(
          message['sdp'],
          message['type'],
        ),
      );
      final answer = await pc.conn!.createAnswer();
      await pc.conn!.setLocalDescription(answer);
      await _signalling.sendMessage('answer', {
        'sdp': answer.sdp,
        'type': answer.type,
        'to': peerID,
      });
      // } else {
      // print('offer:remote description already set');
      // }
    } else {
      // create new peer and add to connecting queue
      print('adding $peerID to connecting queue');
      _addPeer(peerID);
      await _createPeer(peerID);
      await _handleOffer(peerID, message);
    }
  }

  Future<void> _handleAnswer(
      String peerID, Map<String, dynamic> message) async {
    if (!_peerConnections.containsKey(peerID)) return;
    final pc = _peerConnections[peerID]!;
    print('handling answer from $peerID');
    if ((await pc.conn?.getRemoteDescription()) == null) {
      // ? TODO: check if this is correct
      await pc.conn!.setRemoteDescription(
        RTCSessionDescription(
          message['sdp'],
          message['type'],
        ),
      );
    } else {
      print('answer:remote description already set');
    }
  }

  Future<void> _handleCandidate(
      String peerID, Map<String, dynamic> message) async {
    if (!_peerConnections.containsKey(peerID)) return;
    final pc = _peerConnections[peerID]!;
    print('handling candidate from $peerID');
    if ((await pc.conn!.getRemoteDescription()) == null) {
      print('candidate:remote description not set yet');
      print(pc.conn != null);
      return;
    }
    await pc.conn!.addCandidate(
      RTCIceCandidate(
        message['candidate'],
        message['sdpMid'],
        message['sdpMLineIndex'],
      ),
    );
  }

  Future<void> _handleLeave(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    print('handling leave from $peerID');
    await _closePeerConnection(peerID);
  }

  Future<void> onMessage(QuerySnapshot<Object?> event) async {
    for (final doc in event.docChanges) {
      // only handle new messages
      if (doc.type != DocumentChangeType.added) {
        continue;
      }
      final data = doc.doc.data() as Map<String, dynamic>;
      final peerID = data['from'] as String;
      if (peerID == localPeerID) {
        continue;
      }
      final type = data['type'] as String;
      final message = data['message'] as Map<String, dynamic>;
      switch (type) {
        case 'join':
          print('join from $peerID');
          _addPeer(peerID);
          await _connect();
          break;
        case 'offer':
          print('offer from $peerID to ${message['to']}]}');
          if (message['to'] == localPeerID) {
            await _handleOffer(peerID, message); // creaet answer
          }
          break;
        case 'answer':
          print('answer from $peerID');
          if (message['to'] == localPeerID) {
            await _handleAnswer(peerID, message); // set remote description
          }
          break;
        case 'candidate':
          print('candidate from $peerID to ${message['to']}');
          if (message['to'] == localPeerID) {
            await _handleCandidate(peerID, message); // add ice candidate
          }
          break;
        case 'leave':
          print('leave from $peerID');
          await _handleLeave(peerID);
          break;
        default:
          print('Unknown message type: $type');
      }
    }
  }
}
