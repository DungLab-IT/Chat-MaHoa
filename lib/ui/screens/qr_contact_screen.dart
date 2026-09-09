import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/database/database_helper.dart';
import '../../core/services/chat_service.dart';

class QrContactScreen extends StatefulWidget {
  const QrContactScreen({super.key, required this.database, required this.profile, required this.chatService});

  final DatabaseHelper database;
  final Map<String, dynamic> profile;
  final ChatService chatService;

  @override
  State<QrContactScreen> createState() => _QrContactScreenState();
}

class _QrContactScreenState extends State<QrContactScreen> {
  final _manualController = TextEditingController();
  bool _hasScanned = false;

  String get _payload => jsonEncode({
        'v': 1,
        'id': widget.profile['id'],
        'name': widget.profile['display_name'],
        'pk': widget.profile['public_key'],
      });

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _importContact(String raw) async {
    try {
      var value = raw.trim();
      if (!value.startsWith('{')) {
        value = utf8.decode(base64Decode(value));
      }
      final json = jsonDecode(value) as Map<String, dynamic>;
      final id = json['id'] as String?;
      final name = json['name'] as String?;
      final publicKey = (json['pk'] ?? json['public_key']) as String?;
      if (id == null || name == null || publicKey == null || id == widget.profile['id']) {
        throw const FormatException('Payload danh bạ không hợp lệ');
      }
      await widget.chatService.sendContactInvite(contactId: id, displayName: name, publicKey: publicKey);
      if (mounted) {
        _manualController.clear();
        setState(() => _hasScanned = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gửi lời mời đến $name')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chuỗi QR không hợp lệ')));
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Danh bạ & QR'),
            bottom: const TabBar(tabs: [Tab(text: 'QR của tôi'), Tab(text: 'Thêm liên hệ')]),
          ),
          body: TabBarView(children: [_MyQrView(payload: _payload), _AddContactView(onImport: _importContact, hasScanned: _hasScanned, onScanned: (value) { if (_hasScanned) return; setState(() => _hasScanned = true); _importContact(value); })]),
        ),
      );
}

class _MyQrView extends StatelessWidget {
  const _MyQrView({required this.payload});
  final String payload;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Container(padding: const EdgeInsets.all(18), color: Colors.white, child: QrImageView(data: payload, size: 240)),
                const SizedBox(height: 22),
                Text('Chia sẻ mã này để kết nối an toàn.', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: payload)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép payload QR'))); }, icon: const Icon(Icons.copy), label: const Text('Sao chép chuỗi JSON')),
              ],
            ),
          ),
        ),
      );
}

class _AddContactView extends StatefulWidget {
  const _AddContactView({required this.onImport, required this.hasScanned, required this.onScanned});
  final Future<void> Function(String) onImport;
  final bool hasScanned;
  final void Function(String) onScanned;

  @override
  State<_AddContactView> createState() => _AddContactViewState();
}

class _AddContactViewState extends State<_AddContactView> {
  final _manualController = TextEditingController();

  @override
  void dispose() { _manualController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (kIsWeb) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('Camera trên Web cần HTTPS hoặc localhost. Nếu bị chặn, hãy dán chuỗi QR bên dưới.', textAlign: TextAlign.center)),
          Container(height: 250, constraints: const BoxConstraints(maxWidth: 520), clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)), child: widget.hasScanned ? const Center(child: Text('Đã nhận mã QR')) : _QrScanner(onScanned: widget.onScanned)),
          const SizedBox(height: 18),
          const Text('Không có camera? Dán payload JSON hoặc Base64 bên dưới.'),
          const SizedBox(height: 12),
          TextField(controller: _manualController, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Payload danh bạ', alignLabelWithHint: true)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => widget.onImport(_manualController.text), icon: const Icon(Icons.person_add_alt_1), label: const Text('Gửi lời mời')),
        ],
      ),
    );
  }
}

class _QrScanner extends StatefulWidget {
  const _QrScanner({required this.onScanned});
  final void Function(String) onScanned;

  @override
  State<_QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<_QrScanner> with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) { _controller.start(); }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) { _controller.stop(); }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final value = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
              if (value != null) widget.onScanned(value);
            },
            errorBuilder: (context, error) {
              _error ??= error.errorDetails?.message ?? 'Không thể mở camera';
              return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center)));
            },
          ),
          const Align(alignment: Alignment.center, child: SizedBox(width: 190, height: 190, child: DecoratedBox(decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))))))
        ],
      );
}