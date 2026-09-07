import 'package:flutter/services.dart'; // 💡 rootBundle（ファイル読み込み）に必要です
import 'package:flutter/material.dart';
import 'package:girinori/controllers/timetable_controller.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/utils/format_time.dart';
import 'package:girinori/widgets/dashboard/line_row.dart';
import 'package:girinori/widgets/dashboard/station_row.dart';

class RouteTimelineCard extends StatelessWidget {
  final TransitRoute route;
  final TimeOfDay baseTime;
  final TimetableController timetableController;
  final Map<String, int> segmentShiftCounts;
  final void Function(int segmentIndex, bool isNext) onShiftTrain;

  const RouteTimelineCard({
    super.key,
    required this.route,
    required this.baseTime,
    required this.timetableController,
    required this.segmentShiftCounts,
    required this.onShiftTrain,
  });

  @override
  Widget build(BuildContext context) {
    List<TimeOfDay> departureTimes = [];
    List<TimeOfDay> arrivalTimes = [];
    TimeOfDay runningTime = baseTime;

    for (int i = 0; i < route.segments.length; i++) {
      final segment = route.segments[i];
      // この区間のシフト数のキーを作成して取得する
      final shiftKey = '${route.id}_$i';
      final shiftCount = segmentShiftCounts[shiftKey] ?? 0;
      final (TimeOfDay dep, TimeOfDay arr) = timetableController
          .findNextTrainTimesByLineName(
            lineName: segment.lineName,
            departureStation: segment.departureStation,
            arrivalStation: segment.arrivalStation,
            baseTime: runningTime,
            shiftCount: shiftCount,
          );

      departureTimes.add(dep);
      arrivalTimes.add(arr);

      // 次の乗り換えがある場合は、本物の到着時刻に徒歩時間を足す
      runningTime = timetableController.addMinutes(arr, segment.walkTimeAfter);
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              route.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${formatTime(arrivalTimes.last)} 着",
              style: const TextStyle(
                color: Color(0xFF00E676),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(color: Colors.white10, height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 出発駅、経由駅を表示する
                    for (int i = 0; i < route.segments.length; i++) ...[
                      DashboardStationRow(
                        routeId: route.id,
                        segmentIndex: i,
                        stationName: route.segments[i].departureStation,
                        arrivalTime: i == 0 ? null : arrivalTimes[i - 1],
                        departureTime: departureTimes[i],
                        segment: route.segments[i],
                        isStart: i == 0,
                        isEnd: false,
                        isNextButtonEnabled:
                            timetableController.hasNextTimeTable,
                        isPreviousButtonEnabled:
                            timetableController.hasPreviousTimeTable,
                        shiftCount: segmentShiftCounts['${route.id}_$i'] ?? 0,
                        onShiftTrain: (isNext) {
                          // _shiftTrainCount(route.id, i, forward);
                          onShiftTrain(i, isNext);
                        },
                      ),
                      LineRow(lineName: route.segments[i].lineName),
                    ],
                    // 到着駅を表示する
                    DashboardStationRow(
                      routeId: route.id,
                      segmentIndex: route.segments.length,
                      stationName: route.segments.last.arrivalStation,
                      arrivalTime: arrivalTimes.last,
                      departureTime: null,
                      segment: route.segments.last,
                      isStart: false,
                      isEnd: true, // 到着駅には列車変更ボタンがない
                      isNextButtonEnabled: timetableController.hasNextTimeTable,
                      isPreviousButtonEnabled:
                          timetableController.hasPreviousTimeTable,
                      shiftCount: 0,
                      onShiftTrain: null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
