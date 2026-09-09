import '../../models/contact_model.dart';
import '../../models/message_model.dart';

abstract class ChatDatabase {
  Future<void> saveContact(ContactModel contact);
  Future<List<ContactModel>> getContacts();
  Future<void> saveMessage(MessageModel message);
}

abstract class ChatTransport {
  Stream<Map<String, dynamic>> get messages;

  void sendEncryptedMessage({
    required String toClientId,
    required Map<String, dynamic> payload,
  });

  bool get isConnected;
}