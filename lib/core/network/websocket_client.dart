import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/chat_contracts.dart';

enum ConnectionStatus { connected, reconnecting, disconnected }

class WebSocketClient implements ChatTransport {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  String? _serverUrl;
  String? _clientId;
  bool _isDisposed = false;
  bool _manualDisconnect = false;
  bool _connectInProgress = false;

  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<ConnectionStatus> get connectionStatus => _statusController.stream;
  String? get clientId => _clientId;
  @override
  bool get isConnected => _channel != null;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  Future<String> getSavedServerUrl() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('relay_server_url') ?? 'ws://localhost:48485';
  }
  @override
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect(String serverUrl, String myClientId) async {
    _serverUrl = serverUrl;
    _clientId = myClientId;
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('relay_server_url', serverUrl);
    await _openConnection();
  }

  Future<void> connectToSavedServer(String myClientId) async {
    final serverUrl = await getSavedServerUrl();
    await connect(serverUrl, myClientId);
  }

  Future<void> reconnect() async {
    final clientId = _clientId;
    if (clientId == null) return;
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _openConnection();
  }

  Future<void> _openConnection() async {
    final serverUrl = _serverUrl;
    final clientId = _clientId;
    if (_isDisposed || _manualDisconnect || serverUrl == null || clientId == null) return;
    if (_connectInProgress || isConnected) return;

    _connectInProgress = true;
    _emitStatus(ConnectionStatus.reconnecting);
    final channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    _channel = channel;
    try {
      await channel.ready;
      if (_channel != channel || _isDisposed) {
        await channel.sink.close();
        return;
      }
      _statusController.add(ConnectionStatus.connected);
      _status = ConnectionStatus.connected;
      _connectInProgress = false;
      channel.sink.add(jsonEncode({'type': 'REGISTER', 'client_id': clientId}));
      channel.stream.listen(
        _handleMessage,
        onError: (_) => _handleDisconnect(channel),
        onDone: () => _handleDisconnect(channel),
        cancelOnError: true,
      );
    } catch (_) {
      _connectInProgress = false;
      _handleDisconnect(channel);
    }
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage as String);
      if (decoded is Map<String, dynamic>) {
        _messageController.add(decoded);
      }
    } on FormatException {
      // Ignore malformed relay frames.
    }
  }

  void _handleDisconnect(WebSocketChannel channel) {
    if (_channel != channel || _isDisposed) return;
    _channel = null;
    _connectInProgress = false;
    _emitStatus(ConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _isDisposed || _reconnectTimer?.isActive == true) return;
    _emitStatus(ConnectionStatus.reconnecting);
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      _openConnection();
    });
  }

  @override
  void sendEncryptedMessage({
    required String toClientId,
    required Map<String, dynamic> payload,
  }) {
    final clientId = _clientId;
    final channel = _channel;
    if (clientId == null || channel == null) return;
    channel.sink.add(jsonEncode({
      'type': 'MESSAGE_FORWARD',
      'to': toClientId,
      'from': clientId,
      'payload': payload,
    }));
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) await channel.sink.close();
    if (!_isDisposed) _emitStatus(ConnectionStatus.disconnected);
  }

  void _emitStatus(ConnectionStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  Future<void> dispose() async {
    await disconnect();
    _isDisposed = true;
    await _statusController.close();
    await _messageController.close();
  }
}