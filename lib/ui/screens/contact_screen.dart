import 'package:flutter/material.dart';

import '../../core/database/database_helper.dart';
import '../../core/services/chat_service.dart';
import 'qr_contact_screen.dart';

class ContactScreen extends QrContactScreen {
  const ContactScreen({super.key, required super.database, required super.profile, required super.chatService});
}

Widget contactScreen({required DatabaseHelper database, required Map<String, dynamic> profile, required ChatService chatService}) => ContactScreen(database: database, profile: profile, chatService: chatService);
