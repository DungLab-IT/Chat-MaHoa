import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/websocket_client.dart';

class ServerConnectScreen extends StatefulWidget {
  const ServerConnectScreen({super.key, required this.client, required this.clientId});

  final WebSocketClient client;
  final String clientId;

  @override
  State<ServerConnectScreen> createState() => _ServerConnectScreenState();
}

class _ServerConnectScreenState extends State<ServerConnectScreen> {
  final _urlController = TextEditingController(text: 'ws://localhost:48485');
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
    _status = widget.client.status;
    _statusSubscription = widget.client.connectionStatus.listen((status) {
      if (mounted) setState(() => _status = status);
    });
  }

  Future<void> _loadSavedUrl() async {
    final url = await widget.client.getSavedServerUrl();
    if (mounted && _urlController.text == 'ws://localhost:48485') {
      _urlController.text = url;
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    setState(() => _busy = true);
    try {
      if (_status == ConnectionStatus.connected) {
        await widget.client.disconnect();
      } else {
        await widget.client.connect(_urlController.text.trim(), widget.clientId);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kết nối thất bại: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Local server')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _StatusCard(status: _status),
            const SizedBox(height: 20),
            Text('Địa chỉ relay', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.link), hintText: 'ws://192.168.1.x:48485'),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _toggleConnection,
              icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_status == ConnectionStatus.connected ? Icons.link_off : Icons.link),
              label: Text(_status == ConnectionStatus.connected ? 'Ngắt kết nối' : 'Kết nối relay'),
            ),
            const SizedBox(height: 20),
            const Text('Relay chỉ chuyển tiếp payload đã mã hóa. Nội dung tin nhắn và khóa phiên không rời khỏi thiết bị.'),
          ],
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final online = status == ConnectionStatus.connected;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: online ? const Color(0xff123f3d) : const Color(0xff2a2d3b), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.circle, size: 14, color: online ? const Color(0xff59d6a6) : Colors.white38),
          const SizedBox(width: 12),
          Text(online ? 'Đang kết nối' : 'Đang ngoại tuyến', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}