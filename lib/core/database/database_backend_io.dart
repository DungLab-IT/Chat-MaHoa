import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/contact_model.dart';
import '../../models/message_model.dart';
import 'database_backend.dart';

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
      directory = await getApplicationDocumentsDirectory();
    } catch (_) {
      directory = Directory.systemTemp;
    }
    final databasePath = path.join(directory.path, 'lan_secure_messenger.db');
    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (database, version) async {
        await _createTables(database);
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
        last_seen DATETIME
      )
    ''');
    await database.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT CHECK(status IN ('pending', 'sent', 'delivered', 'read'))
      )
    ''');
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
  Future<List<MessageModel>> getMessagesByContactId(String contactId) async {
    final rows = await database.query(
      'messages',
      where: 'sender_id = ? OR receiver_id = ?',
      whereArgs: [contactId, contactId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(MessageModel.fromMap).toList();
  }
}

DatabaseBackend createDatabaseBackend() => NativeDatabaseBackend();