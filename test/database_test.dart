import 'package:flutter_test/flutter_test.dart';
import 'package:lan_secure_messenger/core/database/database_helper.dart';
import 'package:lan_secure_messenger/models/contact_model.dart';
import 'package:lan_secure_messenger/models/message_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final database = DatabaseHelper.instance;

  setUp(() async {
    await database.close();
    await database.initialize();
  });

  tearDown(() => database.close());

  test('reads and writes profile, contacts, and messages', () async {
    const contactId = 'test-contact';
    const messageId = 'test-message';
    final lastSeen = DateTime.utc(2026, 9, 8, 12);
    final timestamp = DateTime.utc(2026, 9, 8, 12, 1);

    await database.saveProfile({
      'id': 'test-profile',
      'display_name': 'Test User',
      'public_key': 'public-key',
      'encrypted_private_key': 'encrypted-private-key',
      'salt': 'salt',
    });
    await database.saveContact(const ContactModel(
      id: contactId,
      displayName: 'Contact One',
      publicKey: 'contact-public-key',
    ));
    await database.updateContactStatus(
      contactId,
      isOnline: true,
      lastSeen: lastSeen,
    );
    await database.saveMessage(MessageModel(
      id: messageId,
      senderId: 'me',
      receiverId: contactId,
      content: 'Encrypted content decrypted locally',
      timestamp: timestamp,
      status: 'sent',
    ));

    final profile = await database.getProfile();
    final contacts = await database.getContacts();
    final messages = await database.getMessagesByContactId(contactId);

    expect(profile?['display_name'], 'Test User');
    expect(contacts, hasLength(1));
    expect(contacts.single.isOnline, isTrue);
    expect(contacts.single.lastSeen, lastSeen);
    expect(messages, hasLength(1));
    expect(messages.single.id, messageId);
    expect(messages.single.content, 'Encrypted content decrypted locally');
    expect(messages.single.timestamp, timestamp);
  });
}