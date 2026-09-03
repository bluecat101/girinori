import 'package:flutter/services.dart';

class WidgetStation {
  final String station;
  final DateTime? arrival;
  final DateTime? departure;

  WidgetStation({required this.station, this.arrival, this.departure});
}

class WidgetService {
  static const _channel = MethodChannel('girinori/widget');

  static Future<void> update({
    required String route,
    required List<WidgetStation> stations,
  }) async {
    // WidgetStation → MethodChannelで渡せるMapに変換
    final stationData = stations.map((station) {
      return <String, String?>{
        'station': station.station,
        'arrival': station.arrival?.toIso8601String(),
        'departure': station.departure?.toIso8601String(),
      };
    }).toList();

    await _channel.invokeMethod('updateWidget', {
      'route': route,
      'stations': stationData,
    });
  }
}
