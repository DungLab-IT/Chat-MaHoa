import '../../models/contact_model.dart';
import '../../models/contact_request_model.dart';
import '../../models/message_model.dart';

abstract class DatabaseBackend {
  Future<void> initialize();
  Future<void> close();
  Future<void> saveProfile(Map<String, dynamic> profile);
  Future<Map<String, dynamic>?> getProfile();
  Future<void> saveContact(ContactModel contact);
  Future<List<ContactModel>> getContacts();
  Future<void> saveContactRequest(ContactRequestModel request);
  Future<List<ContactRequestModel>> getPendingContactRequests();
  Future<ContactRequestModel?> getContactRequest(String requestId);
  Future<void> updateContactRequestStatus(String requestId, String status);
  Future<void> deleteContact(String contactId);
  Future<void> updateContactStatus(
    String contactId, {
    required bool isOnline,
    DateTime? lastSeen,
  });
  Future<void> saveMessage(MessageModel message);
  Future<MessageModel?> getMessage(String messageId);
  Future<List<MessageModel>> getMessagesByContactId(String contactId);
  Future<void> deleteMessagesByContactId(String contactId);
  Future<void> deleteMessage(String messageId);
  Future<void> markMessageRecalled(String messageId);
}