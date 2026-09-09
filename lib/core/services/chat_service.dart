import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../models/contact_model.dart';
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
  late final StreamSubscription<Map<String, dynamic>> _messageSubscription;

  Map<String, dynamic>? _myProfile;
  String? _masterPin;
  SimpleKeyPair? _privateKey;
  bool _disposed = false;

  Stream<MessageModel> get messageStream => _messageController.stream;
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
    final encrypted = await _crypto.encryptMessage(plainTextContent, sessionKey);
    transport.sendEncryptedMessage(
      toClientId: receiverContactId,
      payload: {
        'iv': encrypted.iv,
        'ciphertext': encrypted.ciphertext,
        'tag': encrypted.authTag,
      },
    );

    final message = MessageModel(
      id: _messageId(),
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
    if (_disposed || message['type'] != 'MESSAGE_FORWARD') return;
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
      id: _messageId(),
      senderId: senderId,
      receiverId: _myClientId,
      content: content,
      timestamp: receivedAt,
      status: 'delivered',
    );
    await database.saveMessage(savedMessage);
    _messageController.add(savedMessage);
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
  }
}