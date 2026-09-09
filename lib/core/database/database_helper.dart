import '../../models/contact_model.dart';
import '../../models/contact_request_model.dart';
import '../../models/message_model.dart';
import '../services/chat_contracts.dart';
import 'database_backend.dart';
import 'database_backend_stub.dart'
    if (dart.library.io) 'database_backend_io.dart'
    if (dart.library.html) 'database_backend_web.dart';

class DatabaseHelper implements ChatDatabase, ChatDatabaseFeatures {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  final DatabaseBackend _backend = createDatabaseBackend();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _backend.initialize();
    _initialized = true;
  }

  Future<void> close() async {
    await _backend.close();
    _initialized = false;
  }

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    await initialize();
    await _backend.saveProfile(profile);
  }

  Future<Map<String, dynamic>?> getProfile() async {
    await initialize();
    return _backend.getProfile();
  }

  @override
  Future<void> saveContact(ContactModel contact) async {
    await initialize();
    await _backend.saveContact(contact);
  }

  @override
  Future<List<ContactModel>> getContacts() async {
    await initialize();
    return _backend.getContacts();
  }

  @override
  Future<void> saveContactRequest(ContactRequestModel request) async { await initialize(); await _backend.saveContactRequest(request); }
  @override
  Future<List<ContactRequestModel>> getPendingContactRequests() async { await initialize(); return _backend.getPendingContactRequests(); }
  @override
  Future<ContactRequestModel?> getContactRequest(String requestId) async { await initialize(); return _backend.getContactRequest(requestId); }
  @override
  Future<void> updateContactRequestStatus(String requestId, String status) async { await initialize(); await _backend.updateContactRequestStatus(requestId, status); }
  @override
  Future<void> deleteContact(String contactId) async { await initialize(); await _backend.deleteContact(contactId); }

  Future<void> updateContactStatus(
    String contactId, {
    required bool isOnline,
    DateTime? lastSeen,
  }) async {
    await initialize();
    await _backend.updateContactStatus(contactId, isOnline: isOnline, lastSeen: lastSeen);
  }

  @override
  Future<void> saveMessage(MessageModel message) async {
    await initialize();
    await _backend.saveMessage(message);
  }

  @override
  Future<MessageModel?> getMessage(String messageId) async { await initialize(); return _backend.getMessage(messageId); }

  Future<List<MessageModel>> getMessagesByContactId(String contactId) async {
    await initialize();
    return _backend.getMessagesByContactId(contactId);
  }

  @override
  Future<void> deleteMessagesByContactId(String contactId) async { await initialize(); await _backend.deleteMessagesByContactId(contactId); }
  @override
  Future<void> deleteMessage(String messageId) async { await initialize(); await _backend.deleteMessage(messageId); }
  @override
  Future<void> markMessageRecalled(String messageId) async { await initialize(); await _backend.markMessageRecalled(messageId); }
}