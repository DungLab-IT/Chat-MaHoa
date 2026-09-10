import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../models/contact_model.dart';
import '../../models/contact_request_model.dart';
import '../../models/message_model.dart';
import '../crypto/crypto_service.dart';
import 'chat_contracts.dart';

class ChatService {
  ChatService({
    required this.database,
    required this.transport,
    CryptoService? crypto,
  })  : _crypto = crypto ?? CryptoService() {
    _messageSubscription = transport.messages.listen((message) {
      unawaited(onMessageReceived(message));
    });
  }

  final ChatDatabase database;
  final ChatTransport transport;
  final CryptoService _crypto;
  final Map<String, SecretKey> _sessionKeys = {};
  final StreamController<MessageModel> _messageController =
      StreamController<MessageModel>.broadcast();
    final StreamController<ContactRequestModel> _requestController =
      StreamController<ContactRequestModel>.broadcast();
  late final StreamSubscription<Map<String, dynamic>> _messageSubscription;

  Map<String, dynamic>? _myProfile;
  String? _masterPin;
  SimpleKeyPair? _privateKey;
  bool _disposed = false;

  Stream<MessageModel> get messageStream => _messageController.stream;
  Stream<ContactRequestModel> get requestStream => _requestController.stream;
  Map<String, dynamic>? get myProfile => _myProfile == null
      ? null
      : Map<String, dynamic>.unmodifiable(_myProfile!);
  bool get isInitialized => _privateKey != null && _myProfile != null;
  bool get isConnected => transport.isConnected;

  Future<void> initialize({
    required Map<String, dynamic> profile,
    required String masterPin,
  }) async {
    final storedPayload = profile['encrypted_private_key'] as String?;
    final encryptedPrivateKey = storedPayload == null
        ? EncryptedPrivateKey.fromJson(profile)
        : EncryptedPrivateKey.fromJson({
            ...jsonDecode(storedPayload) as Map<String, dynamic>,
            'public_key': profile['public_key'],
            'salt': profile['salt'],
          });
    final privateKey = await _crypto.decryptPrivateKey(
      encryptedPrivateKey,
      masterPin,
    );
    await initializeWithKeyPair(
      profile: profile,
      masterPin: masterPin,
      privateKey: privateKey,
    );
  }

  Future<void> initializeWithKeyPair({
    required Map<String, dynamic> profile,
    required String masterPin,
    required SimpleKeyPair privateKey,
  }) async {
    _ensureNotDisposed();
    _myProfile = Map<String, dynamic>.from(profile);
    _masterPin = masterPin;
    _privateKey = privateKey;
  }

  Future<void> sendMessage({
    required String receiverContactId,
    required String plainTextContent,
  }) async {
    _ensureReady();
    final contact = await _findContact(receiverContactId);
    final sessionKey = await _sessionKeyFor(contact);
    final messageId = _messageId();
    final encrypted = await _crypto.encryptMessage(plainTextContent, sessionKey);
    transport.sendEncryptedMessage(
      toClientId: receiverContactId,
      payload: {
        'message_id': messageId,
        'iv': encrypted.iv,
        'ciphertext': encrypted.ciphertext,
        'tag': encrypted.authTag,
      },
    );

    final message = MessageModel(
      id: messageId,
      senderId: _myClientId,
      receiverId: receiverContactId,
      content: plainTextContent,
      timestamp: DateTime.now().toUtc(),
      status: 'sent',
    );
    await database.saveMessage(message);
    _messageController.add(message);
  }

  Future<void> onMessageReceived(Map<String, dynamic> message) async {
    if (_disposed) return;
    if (message['type'] == 'PEER_EVENT') {
      await _onPeerEvent(message);
      return;
    }
    if (message['type'] != 'MESSAGE_FORWARD') return;
    final senderId = message['from'];
    final rawPayload = message['payload'];
    if (senderId is! String || rawPayload is! Map) return;
    final payload = Map<String, dynamic>.from(rawPayload);
    final contact = await _findContact(senderId);
    final sessionKey = await _sessionKeyFor(contact);
    final content = await _crypto.decryptMessage(
      ciphertext: payload['ciphertext'] as String,
      iv: payload['iv'] as String,
      authTag: (payload['tag'] ?? payload['authTag']) as String,
      sessionKey: sessionKey,
    );
    final timestamp = message['timestamp'];
    final receivedAt = timestamp is int
        ? DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
        : DateTime.now().toUtc();
    final savedMessage = MessageModel(
      id: payload['message_id'] is String ? payload['message_id'] as String : _messageId(),
      senderId: senderId,
      receiverId: _myClientId,
      content: content,
      timestamp: receivedAt,
      status: 'delivered',
    );
    await database.saveMessage(savedMessage);
    _messageController.add(savedMessage);
  }

  Future<void> sendContactInvite({required String contactId, required String displayName, required String publicKey}) async {
    _ensureReady();
    final request = ContactRequestModel(id: _requestId(), senderId: _myClientId, receiverId: contactId, displayName: _myProfile!['display_name'] as String, publicKey: _myProfile!['public_key'] as String, status: 'pending', createdAt: DateTime.now().toUtc());
    final features = _features;
    await features.saveContactRequest(request);
    _sendPeerEvent(contactId, 'CONTACT_INVITE', request.toMap());
  }

  Future<void> acceptContactRequest(ContactRequestModel request) async {
    _ensureReady();
    final features = _features;
    await database.saveContact(ContactModel(id: request.senderId, displayName: request.displayName, publicKey: request.publicKey));
    await features.updateContactRequestStatus(request.id, 'accepted');
    _sendPeerEvent(request.senderId, 'CONTACT_ACCEPT', {'request_id': request.id, 'id': _myClientId, 'name': _myProfile!['display_name'], 'pk': _myProfile!['public_key']});
    _requestController.add(request);
  }

  Future<void> declineContactRequest(ContactRequestModel request) async {
    final features = _features;
    await features.updateContactRequestStatus(request.id, 'declined');
    _sendPeerEvent(request.senderId, 'CONTACT_DECLINE', {'request_id': request.id});
    _requestController.add(request);
  }

  Future<void> recallMessage(MessageModel message) async {
    _ensureReady();
    if (message.senderId != _myClientId) return;
    final features = _features;
    await features.markMessageRecalled(message.id);
    _sendPeerEvent(message.receiverId, 'MESSAGE_RECALL', {'message_id': message.id});
    final updated = await features.getMessage(message.id);
    if (updated != null) _messageController.add(updated);
  }

  Future<void> _onPeerEvent(Map<String, dynamic> message) async {
    final event = message['event'];
    final payload = message['payload'];
    final from = message['from'];
    if (event is! String || payload is! Map || from is! String) return;
    final data = Map<String, dynamic>.from(payload);
    if (event == 'CONTACT_INVITE') {
      final request = ContactRequestModel.fromMap(data);
      await _features.saveContactRequest(request);
      _requestController.add(request);
    } else if (event == 'CONTACT_ACCEPT') {
      await database.saveContact(ContactModel(id: data['id'] as String, displayName: data['name'] as String, publicKey: data['pk'] as String));
      final requestId = data['request_id'] as String?;
      if (requestId != null) await _features.updateContactRequestStatus(requestId, 'accepted');
    } else if (event == 'CONTACT_DECLINE') {
      final requestId = data['request_id'] as String?;
      if (requestId != null) await _features.updateContactRequestStatus(requestId, 'declined');
    } else if (event == 'MESSAGE_RECALL') {
      final messageId = data['message_id'] as String?;
      if (messageId != null) {
        await _features.markMessageRecalled(messageId);
        final recalled = await _features.getMessage(messageId);
        if (recalled != null) _messageController.add(recalled);
      }
    }
  }

  Future<SecretKey> _sessionKeyFor(ContactModel contact) async {
    final cachedKey = _sessionKeys[contact.id];
    if (cachedKey != null) return cachedKey;
    final privateKey = _privateKey;
    if (privateKey == null) throw StateError('ChatService is not initialized');
    final sessionKey = await _crypto.deriveSessionKey(
      localKeyPair: privateKey,
      remotePublicKey: _crypto.importPublicKey(contact.publicKey),
    );
    _sessionKeys[contact.id] = sessionKey;
    return sessionKey;
  }

  Future<ContactModel> _findContact(String contactId) async {
    final contacts = await database.getContacts();
    for (final contact in contacts) {
      if (contact.id == contactId) return contact;
    }
    throw StateError('Contact not found: $contactId');
  }

  String get _myClientId {
    final id = _myProfile?['id'];
    if (id is! String || id.isEmpty) throw StateError('Profile id is missing');
    return id;
  }

  String _messageId() => '$_myClientId-${DateTime.now().microsecondsSinceEpoch}';
  String _requestId() => 'request-$_myClientId-${DateTime.now().microsecondsSinceEpoch}';

  ChatDatabaseFeatures get _features {
    final features = database;
    if (features is! ChatDatabaseFeatures) throw StateError('Database does not support contact and message management');
    return features as ChatDatabaseFeatures;
  }

  void _sendPeerEvent(String toClientId, String event, Map<String, dynamic> payload) {
    final peerTransport = transport;
    if (peerTransport is! PeerEventTransport) throw StateError('Transport does not support peer events');
    (peerTransport as PeerEventTransport).sendPeerEvent(toClientId: toClientId, event: event, payload: payload);
  }

  void _ensureReady() {
    _ensureNotDisposed();
    if (!isInitialized || _masterPin == null) {
      throw StateError('ChatService must be initialized before sending messages');
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) throw StateError('ChatService has been disposed');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _messageSubscription.cancel();
    _sessionKeys.clear();
    _masterPin = null;
    _privateKey?.destroy();
    _privateKey = null;
    await _messageController.close();
    await _requestController.close();
  }
}