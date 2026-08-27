import 'package:flutter/services.dart';

class WidgetService {
  static const _channel = MethodChannel('girinori/widget');

  static Future<void> update({
    required String route,
    required String departure,
    required String arrival,
  }) async {
    await _channel.invokeMethod('updateWidget', {
      'route': route,
      'departure': departure,
      'arrival': arrival,
    });
  }
}
