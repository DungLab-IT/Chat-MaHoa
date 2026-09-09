import '../../models/contact_model.dart';
import '../../models/message_model.dart';

abstract class DatabaseBackend {
  Future<void> initialize();
  Future<void> close();
  Future<void> saveProfile(Map<String, dynamic> profile);
  Future<Map<String, dynamic>?> getProfile();
  Future<void> saveContact(ContactModel contact);
  Future<List<ContactModel>> getContacts();
  Future<void> updateContactStatus(
    String contactId, {
    required bool isOnline,
    DateTime? lastSeen,
  });
  Future<void> saveMessage(MessageModel message);
  Future<List<MessageModel>> getMessagesByContactId(String contactId);
}