import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../core/network/websocket_client.dart';
import '../../core/services/chat_service.dart';
import '../../models/contact_model.dart';
import '../../models/message_model.dart';
import 'chat_room_screen.dart';
import 'qr_contact_screen.dart';
import 'server_connect_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, required this.database, required this.client, required this.chatService, required this.profile});

  final DatabaseHelper database;
  final WebSocketClient client;
  final ChatService chatService;
  final Map<String, dynamic> profile;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ContactModel> _contacts = [];
  StreamSubscription<MessageModel>? _messageSubscription;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final Map<String, MessageModel?> _latest = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _messageSubscription = widget.chatService.messageStream.listen((_) => _loadContacts());
    _statusSubscription = widget.client.connectionStatus.listen((status) { if (mounted) setState(() => _status = status); });
  }

  Future<void> _loadContacts() async {
    final contacts = await widget.database.getContacts();
    for (final contact in contacts) {
      final messages = await widget.database.getMessagesByContactId(contact.id);
      _latest[contact.id] = messages.isEmpty ? null : messages.last;
    }
    if (mounted) setState(() => _contacts = contacts);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openQr() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => QrContactScreen(database: widget.database, profile: widget.profile)));
    _loadContacts();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Tin nhắn'),
          actions: [
            IconButton(tooltip: 'Thêm liên hệ', onPressed: _openQr, icon: const Icon(Icons.qr_code_2)),
            IconButton(tooltip: 'Cấu hình server', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServerConnectScreen(client: widget.client, clientId: widget.profile['id'] as String))), icon: const Icon(Icons.tune)),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadContacts,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ConnectionBanner(status: _status),
              const SizedBox(height: 20),
              if (_contacts.isEmpty) const _EmptyChats() else ..._contacts.map(_contactTile),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(onPressed: _openQr, icon: const Icon(Icons.person_add_alt_1), label: const Text('Kết bạn')),
      );

  Widget _contactTile(ContactModel contact) {
    final latest = _latest[contact.id];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Stack(children: [CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Text(contact.displayName.isEmpty ? '?' : contact.displayName[0].toUpperCase())), Positioned(right: 0, bottom: 0, child: Icon(Icons.circle, size: 12, color: contact.isOnline ? const Color(0xff58d69c) : Colors.white30))]),
        title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(latest?.content ?? 'Bắt đầu cuộc trò chuyện bảo mật', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: latest == null ? null : Text(_time(latest.timestamp), style: Theme.of(context).textTheme.labelSmall),
        onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(contact: contact, database: widget.database, chatService: widget.chatService, client: widget.client, myClientId: widget.profile['id'] as String))); _loadContacts(); },
      ),
    );
  }

  String _time(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.status});
  final ConnectionStatus status;
  @override
  Widget build(BuildContext context) {
    final online = status == ConnectionStatus.connected;
    final retrying = status == ConnectionStatus.reconnecting;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: online ? const Color(0xff123f3d) : const Color(0xff2a2d3b), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.circle, size: 11, color: online ? const Color(0xff58d69c) : retrying ? Colors.amber : Colors.redAccent),
        const SizedBox(width: 10),
        Text(online ? 'Relay đang hoạt động' : retrying ? 'Đang kết nối lại...' : 'Chưa kết nối Local Relay'),
        const Spacer(),
        Icon(online ? Icons.wifi : retrying ? Icons.sync : Icons.wifi_off, size: 18),
      ]),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 100), child: Column(children: [Icon(Icons.forum_outlined, size: 52, color: Colors.white24), const SizedBox(height: 14), const Text('Chưa có cuộc trò chuyện'), const SizedBox(height: 6), const Text('Thêm một liên hệ để bắt đầu.', style: TextStyle(color: Colors.white54))]));
}