import 'package:flutter/services.dart';

class WidgetService {
  static const _channel = MethodChannel('girinori/widget');

  static Future<void> update({
    required String route,
    required List<Map<String, String?>> stations,
  }) async {
    await _channel.invokeMethod('updateWidget', {
      'route': route,
      'stations': stations,
    });
  }
}
