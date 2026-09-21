import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class LineController {
  LineController();

  Future<void> init() async {
    await loadLineColor();
  }

  // 路線の色を格納するマップ
  Map<String, Color> lineColorMap = {};

  // ============================================================
  Future<void> loadLineColor() async {
    final yamlString = await rootBundle.loadString(
      'assets/line_color/line_color.yaml',
    );

    // loadYamlでパースする（YamlMap型が返る）
    final YamlMap data = loadYaml(yamlString);

    // Map<String, String> に安全に変換
    lineColorMap = data.map<String, Color>(
      (key, value) => MapEntry<String, Color>(
        key.toString(),
        Color(int.parse(value.toString())),
      ),
    );
  }

  // 指定した路線のカラーコードを返すメソッド
  Color lineColor(String lineName) {
    return lineColorMap[lineName] ?? Color(0xFF00B0FF); // デフォルトの色
  }
}
