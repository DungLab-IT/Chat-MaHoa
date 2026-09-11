import 'package:flutter/material.dart';

class DeleteChatDialog extends StatefulWidget {
  const DeleteChatDialog({super.key, required this.contactName});

  final String contactName;

  @override
  State<DeleteChatDialog> createState() => _DeleteChatDialogState();
}

class _DeleteChatDialogState extends State<DeleteChatDialog> {
  bool _deleteForBoth = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Xóa cuộc trò chuyện?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc chắn muốn xóa cuộc trò chuyện với ${widget.contactName}?'),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _deleteForBoth,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Đồng thời xóa cho cả ${widget.contactName}'),
              onChanged: (value) => setState(() => _deleteForBoth = value ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, _deleteForBoth),
            child: const Text('Xóa'),
          ),
        ],
      );
}
