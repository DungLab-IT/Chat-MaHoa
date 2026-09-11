import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/storage_service.dart';

class DataStorageSettingTile extends StatefulWidget {
  const DataStorageSettingTile({super.key, this.onPathChanged});

  final Future<void> Function()? onPathChanged;

  @override
  State<DataStorageSettingTile> createState() => _DataStorageSettingTileState();
}

class _DataStorageSettingTileState extends State<DataStorageSettingTile> {
  String? _path;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPath();
  }

  Future<void> _loadPath() async {
    final path = await StorageService.instance.displayStoragePath();
    if (mounted) setState(() { _path = path; _loading = false; });
  }

  Future<void> _choosePath() async {
    final selected = await StorageService.instance.chooseStoragePath();
    if (selected == null || !mounted) return;
    await widget.onPathChanged?.call();
    await _loadPath();
  }

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: const Text('Vị trí lưu dữ liệu'),
        subtitle: Text(_loading ? 'Đang tải...' : _path ?? (kIsWeb ? 'Browser storage' : 'Mặc định')),
        trailing: kIsWeb ? null : IconButton(tooltip: 'Đổi thư mục', onPressed: _choosePath, icon: const Icon(Icons.edit_location_alt_outlined)),
      );
}
