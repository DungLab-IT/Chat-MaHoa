import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

import 'core/crypto/crypto_service.dart';
import 'core/database/database_helper.dart';
import 'core/network/websocket_client.dart';
import 'core/services/chat_service.dart';
import 'ui/screens/chat_list_screen.dart';
import 'ui/screens/setup_profile_screen.dart';

void main() => runApp(const LanSecureMessengerApp());

class LanSecureMessengerApp extends StatefulWidget {
  const LanSecureMessengerApp({super.key});

  @override
  State<LanSecureMessengerApp> createState() => _LanSecureMessengerAppState();
}

class MyApp extends LanSecureMessengerApp {
  const MyApp({super.key});
}

class _LanSecureMessengerAppState extends State<LanSecureMessengerApp> {
  final _database = DatabaseHelper.instance;
  final _crypto = CryptoService();
  final _webSocketClient = WebSocketClient();
  Map<String, dynamic>? _profile;
  ChatService? _chatService;
  bool _loading = true;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _database.getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _startupError = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _activateProfile({
    required String pin,
    SimpleKeyPair? keyPair,
    Map<String, dynamic>? profile,
  }) async {
    final selectedProfile = profile ?? _profile;
    if (selectedProfile == null) return;
    final service = ChatService(
      database: _database,
      transport: _webSocketClient,
      crypto: _crypto,
    );
    if (keyPair == null) {
      await service.initialize(profile: selectedProfile, masterPin: pin);
    } else {
      await service.initializeWithKeyPair(
        profile: selectedProfile,
        masterPin: pin,
        privateKey: keyPair,
      );
    }
    unawaited(_webSocketClient.connectToSavedServer(selectedProfile['id'] as String));
    if (mounted) {
      setState(() {
        _profile = selectedProfile;
        _chatService = service;
      });
    }
  }

  @override
  void dispose() {
    _chatService?.dispose();
    _webSocketClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Lan Secure Messenger',
        theme: _theme,
        home: _buildHome(),
      );

  Widget _buildHome() {
    if (_loading) return const _LoadingScreen();
    if (_startupError != null) {
      return _ErrorScreen(error: _startupError!, onRetry: _loadProfile);
    }
    final profile = _profile;
    final chatService = _chatService;
    if (profile == null) {
      return SetupProfileScreen(
        database: _database,
        crypto: _crypto,
        onCreated: (createdProfile, keyPair, masterPin) => _activateProfile(
          pin: masterPin,
          profile: createdProfile,
          keyPair: keyPair,
        ),
      );
    }
    if (chatService == null) {
      return _UnlockScreen(
        profile: profile,
        onUnlock: (pin) => _activateProfile(pin: pin),
      );
    }
    return ChatListScreen(
      database: _database,
      client: _webSocketClient,
      chatService: chatService,
      profile: profile,
    );
  }
}

ThemeData get _theme => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xff10131d),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff36b9aa),
        brightness: Brightness.dark,
      ).copyWith(surface: const Color(0xff191d29)),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff10131d),
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xff1d2230),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff36b9aa)),
        ),
        counterStyle: const TextStyle(color: Colors.white38),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xff191d29),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      useMaterial3: true,
    );

class _UnlockScreen extends StatefulWidget {
  const _UnlockScreen({required this.profile, required this.onUnlock});

  final Map<String, dynamic> profile;
  final Future<void> Function(String pin) onUnlock;

  @override
  State<_UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<_UnlockScreen> {
  final _pinController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_pinController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN phải gồm đúng 6 chữ số')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onUnlock(_pinController.text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN không đúng hoặc khóa đã hỏng')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.lock_open, size: 32),
                  ),
                  const SizedBox(height: 22),
                  Text('Mở khóa hồ sơ', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    widget.profile['display_name'] as String? ?? 'Lan Secure Messenger',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _pinController,
                    autofocus: true,
                    obscureText: true,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 10),
                    decoration: const InputDecoration(labelText: 'Master PIN'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _unlock,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Mở khóa'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('Không thể mở dữ liệu cục bộ'),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 18),
                FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
              ],
            ),
          ),
        ),
      );
}
