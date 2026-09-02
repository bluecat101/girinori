class Trip {
  final String tripId; // 路線名
  final String dayType; // 平日/土/日祝
  final Map<String, StopTime> stopTimes; // {駅: {停車時刻,出発時刻}}

  Trip({required this.tripId, required this.dayType, required this.stopTimes});

  factory Trip.fromJson(Map<String, dynamic> json) {
    final rawStopTimes = json['stop_times'] as Map<String, dynamic>;

    return Trip(
      tripId: json['trip_id'] as String,
      dayType: json['day_type'] as String,
      stopTimes: rawStopTimes.map(
        (station, value) => MapEntry(
          station,
          StopTime.fromJson(Map<String, dynamic>.from(value)),
        ),
      ),
    );
  }
}

class StopTime {
  final int? arr;
  final int? dep;

  StopTime({this.arr, this.dep});

  factory StopTime.fromJson(Map<String, dynamic> json) {
    return StopTime(arr: json['arr'] as int?, dep: json['dep'] as int?);
  }
}
