import '../../models/contact_model.dart';
import '../../models/message_model.dart';
import 'database_backend.dart';

class WebDatabaseBackend implements DatabaseBackend {
  final Map<String, dynamic> _profile = {};
  final Map<String, ContactModel> _contacts = {};
  final Map<String, MessageModel> _messages = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    _profile
      ..clear()
      ..addAll(profile);
  }

  @override
  Future<Map<String, dynamic>?> getProfile() async {
    return _profile.isEmpty ? null : Map<String, dynamic>.from(_profile);
  }

  @override
  Future<void> saveContact(ContactModel contact) async {
    _contacts[contact.id] = contact;
  }

  @override
  Future<List<ContactModel>> getContacts() async {
    final contacts = _contacts.values.toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return contacts;
  }

  @override
  Future<void> updateContactStatus(
    String contactId, {
    required bool isOnline,
    DateTime? lastSeen,
  }) async {
    final contact = _contacts[contactId];
    if (contact == null) return;
    _contacts[contactId] = ContactModel(
      id: contact.id,
      displayName: contact.displayName,
      publicKey: contact.publicKey,
      isOnline: isOnline,
      lastSeen: lastSeen,
    );
  }

  @override
  Future<void> saveMessage(MessageModel message) async {
    _messages[message.id] = message;
  }

  @override
  Future<List<MessageModel>> getMessagesByContactId(String contactId) async {
    final messages = _messages.values
        .where((message) => message.senderId == contactId || message.receiverId == contactId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }
}

DatabaseBackend createDatabaseBackend() => WebDatabaseBackend();