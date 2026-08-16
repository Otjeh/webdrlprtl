import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _file async {
    final path = await _localPath;
    return File('$path/idigi_store.json');
  }

  Future<Map<String, dynamic>> readJson() async {
    try {
      final file = await _file;
      if (!await file.exists()) {
        return {};
      }

      final contents = await file.readAsString();
      if (contents.trim().isEmpty) {
        return {};
      }

      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> writeJson(Map<String, dynamic> data) async {
    final file = await _file;
    await file.writeAsString(jsonEncode(data));
  }
}
