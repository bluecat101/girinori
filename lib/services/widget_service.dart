import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WidgetStation {
  final String station;
  final TimeOfDay? arrival;
  final TimeOfDay? departure;

  WidgetStation({required this.station, this.arrival, this.departure});
}

String formatTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
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
        'arrival': station.arrival != null
            ? formatTimeOfDay(station.arrival!)
            : null,
        'departure': station.departure != null
            ? formatTimeOfDay(station.departure!)
            : null,
      };
    }).toList();

    await _channel.invokeMethod('updateWidget', {
      'route': route,
      'stations': stationData,
    });
  }
}
