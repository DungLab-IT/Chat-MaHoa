import '../../models/contact_model.dart';
import '../../models/contact_request_model.dart';
import '../../models/message_model.dart';

abstract class ChatDatabase {
  Future<void> saveContact(ContactModel contact);
  Future<List<ContactModel>> getContacts();
  Future<void> saveMessage(MessageModel message);
}

abstract class ChatDatabaseFeatures {
  Future<void> saveContactRequest(ContactRequestModel request);
  Future<List<ContactRequestModel>> getPendingContactRequests();
  Future<ContactRequestModel?> getContactRequest(String requestId);
  Future<void> updateContactRequestStatus(String requestId, String status);
  Future<void> deleteContact(String contactId);
  Future<MessageModel?> getMessage(String messageId);
  Future<void> deleteMessagesByContactId(String contactId);
  Future<void> deleteMessage(String messageId);
  Future<void> markMessageRecalled(String messageId);
}

abstract class ChatTransport {
  Stream<Map<String, dynamic>> get messages;

  void sendEncryptedMessage({
    required String toClientId,
    required Map<String, dynamic> payload,
  });

  bool get isConnected;
}

abstract class PeerEventTransport {
  void sendPeerEvent({required String toClientId, required String event, required Map<String, dynamic> payload});
}