import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lan_secure_messenger/core/crypto/crypto_service.dart';
import 'package:lan_secure_messenger/core/services/chat_contracts.dart';
import 'package:lan_secure_messenger/core/services/chat_service.dart';
import 'package:lan_secure_messenger/models/contact_model.dart';
import 'package:lan_secure_messenger/models/message_model.dart';

class MemoryDatabase implements ChatDatabase {
  final List<ContactModel> contacts = [];
  final List<MessageModel> messages = [];

  @override
  Future<List<ContactModel>> getContacts() async => List.unmodifiable(contacts);

  @override
  Future<void> saveContact(ContactModel contact) async {
    contacts.removeWhere((item) => item.id == contact.id);
    contacts.add(contact);
  }

  @override
  Future<void> saveMessage(MessageModel message) async => messages.add(message);
}

class InMemoryTransport implements ChatTransport {
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();
  InMemoryTransport? peer;
  Map<String, dynamic>? lastPayload;

  @override
  bool get isConnected => true;

  @override
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  @override
  void sendEncryptedMessage({
    required String toClientId,
    required Map<String, dynamic> payload,
  }) {
    lastPayload = payload;
    peer?._controller.add({
      'type': 'MESSAGE_FORWARD',
      'to': toClientId,
      'from': 'usr_alice',
      'payload': payload,
    });
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  test('Alice encrypts, transports, and Bob decrypts a message', () async {
    final crypto = CryptoService();
    final aliceKeyPair = await crypto.generateKeyPair();
    final bobKeyPair = await crypto.generateKeyPair();
    final alicePublicKey = crypto.exportPublicKey(
      await aliceKeyPair.extractPublicKey(),
    );
    final bobPublicKey = crypto.exportPublicKey(
      await bobKeyPair.extractPublicKey(),
    );

    final aliceDatabase = MemoryDatabase();
    final bobDatabase = MemoryDatabase();
    await aliceDatabase.saveContact(ContactModel(
      id: 'usr_bob',
      displayName: 'Bob',
      publicKey: bobPublicKey,
    ));
    await bobDatabase.saveContact(ContactModel(
      id: 'usr_alice',
      displayName: 'Alice',
      publicKey: alicePublicKey,
    ));

    final aliceTransport = InMemoryTransport();
    final bobTransport = InMemoryTransport();
    aliceTransport.peer = bobTransport;
    bobTransport.peer = aliceTransport;
    final alice = ChatService(
      database: aliceDatabase,
      transport: aliceTransport,
      crypto: crypto,
    );
    final bob = ChatService(
      database: bobDatabase,
      transport: bobTransport,
      crypto: crypto,
    );
    await alice.initializeWithKeyPair(
      profile: {'id': 'usr_alice', 'display_name': 'Alice'},
      masterPin: 'alice-pin',
      privateKey: aliceKeyPair,
    );
    await bob.initializeWithKeyPair(
      profile: {'id': 'usr_bob', 'display_name': 'Bob'},
      masterPin: 'bob-pin',
      privateKey: bobKeyPair,
    );

    final received = Completer<MessageModel>();
    final subscription = bob.messageStream.listen((message) {
      if (!received.isCompleted) received.complete(message);
    });

    await alice.sendMessage(
      receiverContactId: 'usr_bob',
      plainTextContent: 'Hello Bob, this is E2EE.',
    );
    final bobMessage = await received.future.timeout(const Duration(seconds: 1));

    expect(aliceTransport.lastPayload, isNotNull);
    expect(aliceTransport.lastPayload, isNot(contains('Hello Bob, this is E2EE.')));
    expect(bobMessage.senderId, 'usr_alice');
    expect(bobMessage.receiverId, 'usr_bob');
    expect(bobMessage.content, 'Hello Bob, this is E2EE.');
    expect(bobMessage.status, 'delivered');
    expect(aliceDatabase.messages.single.status, 'sent');
    expect(bobDatabase.messages.single.content, 'Hello Bob, this is E2EE.');

    await subscription.cancel();
    await alice.dispose();
    await bob.dispose();
    await aliceTransport.dispose();
    await bobTransport.dispose();
  });
}