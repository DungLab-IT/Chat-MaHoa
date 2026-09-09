import '../../models/contact_model.dart';
import '../../models/message_model.dart';
import 'database_backend.dart';

class UnsupportedDatabaseBackend implements DatabaseBackend {
  Never _unsupported() => throw UnsupportedError('No database backend for this platform');

  @override
  Future<void> initialize() async => _unsupported();
  @override
  Future<void> close() async => _unsupported();
  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async => _unsupported();
  @override
  Future<Map<String, dynamic>?> getProfile() async => _unsupported();
  @override
  Future<void> saveContact(ContactModel contact) async => _unsupported();
  @override
  Future<List<ContactModel>> getContacts() async => _unsupported();
  @override
  Future<void> updateContactStatus(String contactId, {required bool isOnline, DateTime? lastSeen}) async => _unsupported();
  @override
  Future<void> saveMessage(MessageModel message) async => _unsupported();
  @override
  Future<List<MessageModel>> getMessagesByContactId(String contactId) async => _unsupported();
}

DatabaseBackend createDatabaseBackend() => UnsupportedDatabaseBackend();