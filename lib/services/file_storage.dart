import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FileStorage {
  static const String _fileName = 'route_data.json';

  /// 保存先ファイルを取得
  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// JSONを保存
  Future<void> save(Map<String, dynamic> data) async {
    final file = await _getFile();

    final jsonString = jsonEncode(data);

    await file.writeAsString(jsonString);
  }

  /// JSONを読み込み
  Future<Map<String, dynamic>?> load() async {
    final file = await _getFile();

    if (!await file.exists()) {
      return null;
    }

    final jsonString = await file.readAsString();

    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// ファイルを削除
  Future<void> delete() async {
    final file = await _getFile();

    if (await file.exists()) {
      await file.delete();
    }
  }
}
