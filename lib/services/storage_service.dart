import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();
  static const _storagePathKey = 'custom_storage_path';
  static const _cookieMaxAge = 60 * 60 * 24 * 365;

  Future<void> saveWebValue(String key, String value) async {
    if (!kIsWeb) return;
    final encoded = Uri.encodeComponent(value);
    html.document.cookie = '$key=$encoded; Max-Age=$_cookieMaxAge; Path=/; SameSite=Strict';
    html.window.localStorage[key] = value;
  }

  String? readWebValue(String key) {
    if (!kIsWeb) return null;
    final cookies = html.document.cookie?.split(';') ?? const <String>[];
    for (final cookie in cookies) {
      final separator = cookie.indexOf('=');
      if (separator < 0) continue;
      if (cookie.substring(0, separator).trim() == key) {
        return Uri.decodeComponent(cookie.substring(separator + 1));
      }
    }
    return html.window.localStorage[key];
  }

  Future<String> getNativeStoragePath() async {
    if (kIsWeb) throw StateError('Native storage is unavailable on web');
    final preferences = await SharedPreferences.getInstance();
    final customPath = preferences.getString(_storagePathKey);
    if (customPath != null && customPath.isNotEmpty) return customPath;
    return path.join(await getDefaultNativeStoragePath(), 'LanSecureMessengerData');
  }

  Future<String> getDefaultNativeStoragePath() async {
    if (kIsWeb) throw StateError('Native storage is unavailable on web');
    final externalDirectory = await getExternalStorageDirectory();
    final baseDirectory = externalDirectory ?? await getApplicationDocumentsDirectory();
    return baseDirectory.path;
  }

  Future<String?> getCustomStoragePath() async {
    if (kIsWeb) return null;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_storagePathKey);
  }

  Future<String?> chooseStoragePath() async {
    if (kIsWeb) return null;
    final selectedPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Chọn thư mục lưu dữ liệu Lan Secure Messenger',
    );
    if (selectedPath == null || selectedPath.isEmpty) return null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storagePathKey, selectedPath);
    return selectedPath;
  }

  Future<String> displayStoragePath() async {
    if (kIsWeb) return 'Browser Cookie + localStorage';
    return (await getCustomStoragePath()) ?? await getNativeStoragePath();
  }
}
