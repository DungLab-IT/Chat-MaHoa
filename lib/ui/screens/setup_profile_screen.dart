import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';

import '../../core/crypto/crypto_service.dart';
import '../../core/database/database_helper.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({
    super.key,
    required this.database,
    required this.crypto,
    required this.onCreated,
  });

  final DatabaseHelper database;
  final CryptoService crypto;
  final Future<void> Function(Map<String, dynamic> profile, SimpleKeyPair keyPair, String masterPin)
      onCreated;

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isSaving = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final keyPair = await widget.crypto.generateKeyPair();
      final encrypted = await widget.crypto.encryptPrivateKey(
        keyPair,
        _pinController.text,
      );
      final publicKey = await keyPair.extractPublicKey();
      final profile = {
        'id': 'usr_${DateTime.now().microsecondsSinceEpoch}',
        'display_name': _nameController.text.trim(),
        'public_key': widget.crypto.exportPublicKey(publicKey),
        'encrypted_private_key': jsonEncode(encrypted.toJson()),
        'salt': encrypted.salt,
      };
      await widget.database.saveProfile(profile);
      await widget.onCreated(profile, keyPair, _pinController.text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo hồ sơ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BrandMark(),
                    const SizedBox(height: 34),
                    Text('Bắt đầu riêng tư.', style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 10),
                    Text(
                      'Tạo danh tính cục bộ để nhắn tin E2EE trong mạng LAN của bạn.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Tên hiển thị', prefixIcon: Icon(Icons.person_outline)),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Nhập tên hiển thị' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pinController,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Master PIN',
                        hintText: '6 chữ số',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePin ? 'Hiện PIN' : 'Ẩn PIN',
                          onPressed: () => setState(() => _obscurePin = !_obscurePin),
                          icon: Icon(_obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) => value != null && RegExp(r'^\d{6}$').hasMatch(value) ? null : 'PIN phải gồm đúng 6 chữ số',
                    ),
                    const SizedBox(height: 18),
                    _SecurityNote(),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _createProfile,
                        icon: _isSaving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward),
                        label: Text(_isSaving ? 'Đang tạo khóa...' : 'Tạo hồ sơ an toàn'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text('LAN / SECURE', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w700, color: Colors.white70)),
        ],
      );
}

class _SecurityNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(12)),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, size: 20, color: Color(0xff56d5c5)),
            SizedBox(width: 10),
            Expanded(child: Text('Private Key chỉ được lưu dưới dạng mã hóa. Master PIN không rời khỏi thiết bị này.', style: TextStyle(color: Colors.white70, height: 1.4))),
          ],
        ),
      );
}