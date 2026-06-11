// lib/models/transit_model.dart

class TransitSegment {
  String line;
  String departureStation;
  int duration;
  String arrivalStation;
  int walkTimeAfter;

  TransitSegment({
    required this.line,
    required this.departureStation,
    required this.duration,
    required this.arrivalStation,
    this.walkTimeAfter = 0,
  });
}

class TransitRoute {
  final String id;
  final String name;
  final List<TransitSegment> segments;

  TransitRoute({required this.id, required this.name, required this.segments});

  // 💡 動的に取得した timetables を使って計算するメソッド
  RouteResult? calculate(
    DateTime now,
    Map<String, Map<int, List<int>>> timetables,
  ) {
    List<SegmentResult> results = [];
    DateTime searchTime = now;
    int countdown = 0;

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];

      // 💡 JSONから取得したデータを見に行く
      final timetable = timetables["${seg.departureStation}駅_${seg.line}"];
      if (timetable == null) return null;

      DateTime? depTime;

      // 深夜3時（27時）まで対応できるようにループ条件を調整
      // searchTimeの時から28時間後まで走査（日付を跨ぐ深夜ダイヤ対応）
      for (int hOffset = 0; hOffset < 24; hOffset++) {
        int currentHour = (searchTime.hour + hOffset) % 24;

        if (timetable.containsKey(currentHour)) {
          for (int m in timetable[currentHour]!) {
            // 検索対象の時刻を生成（時間ベースで翌日になる場合は日を+1する処理）
            int dayOffset = 0;
            if (currentHour < searchTime.hour) {
              dayOffset = 1; // 23時から0時や1時を探す場合は翌日扱い
            }

            final target = DateTime(
              now.year,
              now.month,
              now.day + dayOffset,
              currentHour,
              m,
            );

            if (target.isAfter(searchTime) ||
                target.isAtSameMomentAs(searchTime)) {
              depTime = target;
              break;
            }
          }
        }
        if (depTime != null) break;
      }

      if (depTime == null) return null;

      final arrTime = depTime.add(Duration(minutes: seg.duration));
      results.add(SegmentResult(dep: depTime, arr: arrTime));

      if (i == 0) {
        countdown = depTime.difference(now).inMinutes;
      }
      searchTime = arrTime.add(Duration(minutes: seg.walkTimeAfter));
    }

    return RouteResult(segmentResults: results, countdownMinutes: countdown);
  }
}

class SegmentResult {
  final DateTime dep;
  final DateTime arr;
  SegmentResult({required this.dep, required this.arr});
}

class RouteResult {
  final List<SegmentResult> segmentResults;
  final int countdownMinutes;
  RouteResult({required this.segmentResults, required this.countdownMinutes});
}
