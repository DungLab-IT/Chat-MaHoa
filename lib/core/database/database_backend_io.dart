import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/contact_model.dart';
import '../../models/contact_request_model.dart';
import '../../models/message_model.dart';
import 'database_backend.dart';
import '../../services/storage_service.dart';

class NativeDatabaseBackend implements DatabaseBackend {
  Database? _database;

  @override
  Future<void> initialize() async {
    if (_database != null) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    Directory directory;
    try {
      directory = Directory(await StorageService.instance.getNativeStoragePath());
      await directory.create(recursive: true);
      final databaseFile = File(path.join(directory.path, 'lan_secure_messenger.db'));
      if (!await databaseFile.exists()) {
        final defaultPath = await StorageService.instance.getDefaultNativeStoragePath();
        final oldDatabase = File(path.join(defaultPath, 'lan_secure_messenger.db'));
        if (await oldDatabase.exists() && oldDatabase.path != databaseFile.path) {
          await oldDatabase.copy(databaseFile.path);
        }
      }
    } catch (_) {
      directory = Directory.systemTemp;
    }
    final databasePath = path.join(directory.path, 'lan_secure_messenger.db');
    _database = await openDatabase(
      databasePath,
      version: 3,
      onCreate: (database, version) async {
        await _createTables(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('ALTER TABLE messages ADD COLUMN is_recalled INTEGER NOT NULL DEFAULT 0');
          await database.execute('''CREATE TABLE contact_requests (
            id TEXT PRIMARY KEY, sender_id TEXT NOT NULL, receiver_id TEXT NOT NULL,
            display_name TEXT NOT NULL, public_key TEXT NOT NULL, status TEXT NOT NULL,
            created_at INTEGER NOT NULL)''');
        }
        if (oldVersion < 3) {
          await database.execute("ALTER TABLE contacts ADD COLUMN status TEXT NOT NULL DEFAULT 'accepted'");
        }
      },
    );
  }

  Database get database {
    final database = _database;
    if (database == null) {
      throw StateError('DatabaseBackend.initialize() must be called first');
    }
    return database;
  }

  Future<void> _createTables(Database database) async {
    await database.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        public_key TEXT NOT NULL,
        is_online INTEGER DEFAULT 0,
        last_seen DATETIME,
        status TEXT NOT NULL DEFAULT 'accepted'
      )
    ''');
    await database.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT CHECK(status IN ('pending', 'sent', 'delivered', 'read')),
        is_recalled INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await database.execute('''CREATE TABLE contact_requests (
      id TEXT PRIMARY KEY, sender_id TEXT NOT NULL, receiver_id TEXT NOT NULL,
      display_name TEXT NOT NULL, public_key TEXT NOT NULL, status TEXT NOT NULL,
      created_at INTEGER NOT NULL)''');
    await database.execute('''
      CREATE TABLE my_profile (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        public_key TEXT NOT NULL,
        encrypted_private_key TEXT NOT NULL,
        salt TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    await database.insert('my_profile', profile, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>?> getProfile() async {
    final rows = await database.query('my_profile', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<void> saveContact(ContactModel contact) async {
    await database.insert('contacts', contact.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<ContactModel>> getContacts() async {
    final rows = await database.query('contacts', orderBy: 'display_name COLLATE NOCASE');
    return rows.map(ContactModel.fromMap).toList();
  }

  @override
  Future<void> saveContactRequest(ContactRequestModel request) async => database.insert('contact_requests', request.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<List<ContactRequestModel>> getPendingContactRequests() async {
    final rows = await database.query('contact_requests', where: "status IN (?, ?, ?)", whereArgs: ['pending', 'pendingReceived', 'pendingSent'], orderBy: 'created_at DESC');
    return rows.map(ContactRequestModel.fromMap).toList();
  }

  @override
  Future<ContactRequestModel?> getContactRequest(String requestId) async {
    final rows = await database.query('contact_requests', where: 'id = ?', whereArgs: [requestId], limit: 1);
    return rows.isEmpty ? null : ContactRequestModel.fromMap(rows.first);
  }

  @override
  Future<void> updateContactRequestStatus(String requestId, String status) async => database.update('contact_requests', {'status': status}, where: 'id = ?', whereArgs: [requestId]);

  @override
  Future<void> deleteContact(String contactId) async {
    await database.delete('contacts', where: 'id = ?', whereArgs: [contactId]);
    await deleteMessagesByContactId(contactId);
  }

  @override
  Future<void> updateContactStatus(
    String contactId, {
    required bool isOnline,
    DateTime? lastSeen,
  }) async {
    await database.update(
      'contacts',
      {'is_online': isOnline ? 1 : 0, 'last_seen': lastSeen?.toIso8601String()},
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  @override
  Future<void> saveMessage(MessageModel message) async {
    await database.insert('messages', message.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<MessageModel?> getMessage(String messageId) async {
    final rows = await database.query('messages', where: 'id = ?', whereArgs: [messageId], limit: 1);
    return rows.isEmpty ? null : MessageModel.fromMap(rows.first);
  }

  @override
  Future<List<MessageModel>> getMessagesByContactId(String contactId) async {
    final rows = await database.query(
      'messages',
      where: 'sender_id = ? OR receiver_id = ?',
      whereArgs: [contactId, contactId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(MessageModel.fromMap).toList();
  }

  @override
  Future<void> deleteMessagesByContactId(String contactId) async => database.delete('messages', where: 'sender_id = ? OR receiver_id = ?', whereArgs: [contactId, contactId]);

  @override
  Future<void> deleteMessage(String messageId) async => database.delete('messages', where: 'id = ?', whereArgs: [messageId]);

  @override
  Future<void> markMessageRecalled(String messageId) async => database.update('messages', {'is_recalled': 1}, where: 'id = ?', whereArgs: [messageId]);

  @override
  Future<void> clearChat(String contactId) async => deleteMessagesByContactId(contactId);
}

DatabaseBackend createDatabaseBackend() => NativeDatabaseBackend();