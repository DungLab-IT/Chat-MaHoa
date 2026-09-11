import 'dart:convert';

import '../../models/contact_model.dart';
import '../../models/contact_request_model.dart';
import '../../models/message_model.dart';
import 'database_backend.dart';
import '../../services/storage_service.dart';

class WebDatabaseBackend implements DatabaseBackend {
  final Map<String, dynamic> _profile = {};
  final Map<String, ContactModel> _contacts = {};
  final Map<String, ContactRequestModel> _requests = {};
  final Map<String, MessageModel> _messages = {};

  @override
  Future<void> initialize() async {
    final profile = StorageService.instance.readWebValue('lan_profile');
    final contacts = StorageService.instance.readWebValue('lan_contacts');
    final requests = StorageService.instance.readWebValue('lan_contact_requests');
    final messages = StorageService.instance.readWebValue('lan_messages');
    if (profile != null) _profile.addAll(Map<String, dynamic>.from(jsonDecode(profile) as Map));
    if (contacts != null) {
      for (final item in jsonDecode(contacts) as List) {
        final contact = ContactModel.fromMap(Map<String, dynamic>.from(item as Map));
        _contacts[contact.id] = contact;
      }
    }
    if (requests != null) {
      for (final item in jsonDecode(requests) as List) {
        final request = ContactRequestModel.fromMap(Map<String, dynamic>.from(item as Map));
        _requests[request.id] = request;
      }
    }
    if (messages != null) {
      for (final item in jsonDecode(messages) as List) {
        final message = MessageModel.fromMap(Map<String, dynamic>.from(item as Map));
        _messages[message.id] = message;
      }
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    _profile
      ..clear()
      ..addAll(profile);
    await _persist();
  }

  @override
  Future<Map<String, dynamic>?> getProfile() async {
    return _profile.isEmpty ? null : Map<String, dynamic>.from(_profile);
  }

  @override
  Future<void> saveContact(ContactModel contact) async {
    _contacts[contact.id] = contact;
    await _persist();
  }

  @override
  Future<List<ContactModel>> getContacts() async {
    final contacts = _contacts.values.toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return contacts;
  }

  @override
  Future<void> saveContactRequest(ContactRequestModel request) async { _requests[request.id] = request; await _persist(); }

  @override
  Future<List<ContactRequestModel>> getPendingContactRequests() async => _requests.values.where((request) => request.status == 'pending' || request.status == 'pendingReceived' || request.status == 'pendingSent').toList();

  @override
  Future<ContactRequestModel?> getContactRequest(String requestId) async => _requests[requestId];

  @override
  Future<void> updateContactRequestStatus(String requestId, String status) async {
    final request = _requests[requestId];
    if (request == null) return;
    _requests[requestId] = ContactRequestModel(id: request.id, senderId: request.senderId, receiverId: request.receiverId, displayName: request.displayName, publicKey: request.publicKey, status: status, createdAt: request.createdAt);
    await _persist();
  }

  @override
  Future<void> deleteContact(String contactId) async { _contacts.remove(contactId); await deleteMessagesByContactId(contactId); await _persist(); }

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
    await _persist();
  }

  @override
  Future<MessageModel?> getMessage(String messageId) async => _messages[messageId];

  @override
  Future<List<MessageModel>> getMessagesByContactId(String contactId) async {
    final messages = _messages.values
        .where((message) => message.senderId == contactId || message.receiverId == contactId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  @override
  Future<void> deleteMessagesByContactId(String contactId) async { _messages.removeWhere((_, message) => message.senderId == contactId || message.receiverId == contactId); await _persist(); }

  @override
  Future<void> deleteMessage(String messageId) async { _messages.remove(messageId); await _persist(); }

  @override
  Future<void> markMessageRecalled(String messageId) async {
    final message = _messages[messageId];
    if (message == null) return;
    _messages[messageId] = MessageModel(id: message.id, senderId: message.senderId, receiverId: message.receiverId, content: message.content, timestamp: message.timestamp, status: message.status, isRecalled: true);
    await _persist();
  }

  @override
  Future<void> clearChat(String contactId) async => deleteMessagesByContactId(contactId);

  Future<void> _persist() async {
    await StorageService.instance.saveWebValue('lan_profile', jsonEncode(_profile));
    await StorageService.instance.saveWebValue('lan_contacts', jsonEncode(_contacts.values.map((contact) => contact.toMap()).toList()));
    await StorageService.instance.saveWebValue('lan_contact_requests', jsonEncode(_requests.values.map((request) => request.toMap()).toList()));
    await StorageService.instance.saveWebValue('lan_messages', jsonEncode(_messages.values.map((message) => message.toMap()).toList()));
  }
}

DatabaseBackend createDatabaseBackend() => WebDatabaseBackend();