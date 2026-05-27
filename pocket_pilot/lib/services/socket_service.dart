import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:pockect_pilot/services/api_service.dart';
import 'package:flutter/foundation.dart';

class SocketService {
  static io.Socket? _socket;

  static void init() {
    if (_socket != null) return;

    // Remove '/api' from the baseUrl for Socket.IO connection
    final socketUrl = ApiService.baseUrl.replaceAll('/api', '');

    _socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.onConnect((_) {
      debugPrint('Connected to Socket.io');
    });

    _socket!.onDisconnect((_) {
      debugPrint('Disconnected from Socket.io');
    });
    
    _socket!.connect();
  }

  static void joinGoalRoom(String goalId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('joinGoalRoom', goalId);
    }
  }

  static void onGoalUpdated(Function(dynamic) callback) {
    if (_socket != null) {
      _socket!.on('goalUpdated', callback);
    }
  }

  static void offGoalUpdated() {
    if (_socket != null) {
      _socket!.off('goalUpdated');
    }
  }

  static void dispose() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }
}
