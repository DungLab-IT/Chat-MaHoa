import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/database/database_helper.dart';
import '../../core/services/chat_service.dart';
import '../../core/network/websocket_client.dart';
import '../../models/contact_model.dart';
import '../../models/message_model.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key, required this.contact, required this.database, required this.chatService, required this.client, required this.myClientId});

  final ContactModel contact;
  final DatabaseHelper database;
  final ChatService chatService;
  final WebSocketClient client;
  final String myClientId;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<MessageModel>? _subscription;
  List<MessageModel> _messages = [];
  bool _sending = false;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  StreamSubscription<ConnectionStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _loadMessages();
    _subscription = widget.chatService.messageStream.listen((message) {
      if ((message.senderId == widget.contact.id && message.receiverId == widget.myClientId) || (message.receiverId == widget.contact.id && message.senderId == widget.myClientId)) {
        setState(() => _messages = [..._messages, message]);
        _scrollToBottom();
      }
    });
    _status = widget.client.status;
    _statusSubscription = widget.client.connectionStatus.listen((status) {
      if (mounted) setState(() => _status = status);
    });
  }

  Future<void> _loadMessages() async { final messages = await widget.database.getMessagesByContactId(widget.contact.id); if (mounted) { setState(() => _messages = messages); _scrollToBottom(); } }
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if ((target - _scrollController.offset).abs() < 1) return;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _sending || !widget.client.isConnected) return;
    setState(() => _sending = true);
    try { _inputController.clear(); await widget.chatService.sendMessage(receiverContactId: widget.contact.id, plainTextContent: content); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không gửi được tin nhắn: $error'))); } finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  void dispose() { _subscription?.cancel(); _statusSubscription?.cancel(); _inputController.dispose(); _scrollController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Row(children: [CircleAvatar(radius: 17, child: Text(widget.contact.displayName[0].toUpperCase())), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.contact.displayName, style: const TextStyle(fontSize: 16)), Row(children: [const Text('E2EE Secured', style: TextStyle(fontSize: 11, color: Color(0xff59d6c5))), const SizedBox(width: 7), Icon(Icons.circle, size: 8, color: _status == ConnectionStatus.connected ? const Color(0xff58d69c) : _status == ConnectionStatus.reconnecting ? Colors.amber : Colors.redAccent)])]),] ),),
        body: Column(children: [if (_status != ConnectionStatus.connected) _ReconnectBanner(status: _status, onReconnect: widget.client.reconnect), Expanded(child: _messages.isEmpty ? const Center(child: Text('Tin nhắn được mã hóa đầu cuối')) : ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(16), itemCount: _messages.length, itemBuilder: (_, index) { final message = _messages[index]; return _Bubble(message: message, mine: message.senderId == widget.myClientId); })), _Composer(controller: _inputController, sending: _sending, enabled: _status == ConnectionStatus.connected, onSend: _send)]),
      );
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner({required this.status, required this.onReconnect});
  final ConnectionStatus status;
  final Future<void> Function() onReconnect;
  @override
  Widget build(BuildContext context) => MaterialBanner(content: Text(status == ConnectionStatus.reconnecting ? 'Đang kết nối lại Local Relay...' : 'Chưa kết nối Local Relay'), leading: Icon(status == ConnectionStatus.reconnecting ? Icons.sync : Icons.wifi_off, color: status == ConnectionStatus.reconnecting ? Colors.amber : Colors.redAccent), actions: [TextButton(onPressed: onReconnect, child: const Text('KẾT NỐI LẠI'))]);
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final MessageModel message;
  final bool mine;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final maxBubbleWidth = constraints.maxWidth * .7;
          return Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              decoration: BoxDecoration(
                color: mine ? Theme.of(context).colorScheme.primary : const Color(0xff303443),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Align(alignment: Alignment.centerLeft, child: Text(message.content)),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.enabled, required this.onSend});
  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;
  bool get _desktopOrWeb => kIsWeb || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    final textField = TextField(
      enabled: enabled,
      controller: controller,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: enabled ? 'Tin nhắn bảo mật...' : 'Kết nối server để nhắn tin',
        prefixIcon: const Icon(Icons.lock_outline, size: 19),
      ),
    );
    final editor = _desktopOrWeb
        ? Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): SendMessageIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                SendMessageIntent: CallbackAction<SendMessageIntent>(onInvoke: (_) {
                  if (enabled && !sending) onSend();
                  return null;
                }),
              },
              child: textField,
            ),
          )
        : textField;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: editor),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Gửi tin nhắn',
              onPressed: enabled && !sending ? onSend : null,
              icon: sending
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class SendMessageIntent extends Intent {
  const SendMessageIntent();
}