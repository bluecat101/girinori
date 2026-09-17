import 'package:flutter/services.dart'; // 💡 rootBundle（ファイル読み込み）に必要です
import 'package:flutter/material.dart';
import 'package:girinori/controllers/line_controller.dart';
import 'package:girinori/controllers/timetable_controller.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/utils/format_time.dart';
import 'package:girinori/widgets/dashboard/line_row.dart';
import 'package:girinori/widgets/dashboard/station_row.dart';

class RouteTimelineCard extends StatelessWidget {
  final TransitRoute route;
  final TimeOfDay baseTime;
  final TimetableController timetableController;
  final LineController lineController;
  final Map<String, int> segmentShiftCounts;
  final void Function(int segmentIndex, bool isNext) onShiftTrain;
  final void Function(Offset globalPosition) onRouteMenu;

  const RouteTimelineCard({
    super.key,
    required this.route,
    required this.baseTime,
    required this.timetableController,
    required this.lineController,
    required this.segmentShiftCounts,
    required this.onShiftTrain,
    required this.onRouteMenu,
  });

  @override
  Widget build(BuildContext context) {
    // 表示するための出発時刻、到着時刻、路線名を格納するリストを作成
    List<TimeOfDay> departureTimes = [];
    List<TimeOfDay> arrivalTimes = [];
    List<String> lineNames = []; // 区間の路線名を格納するリスト
    TimeOfDay runningTime = baseTime;

    for (int i = 0; i < route.segments.length; i++) {
      final segment = route.segments[i];
      // この区間のシフト数のキーを作成して取得する
      final shiftKey = '${route.id}_$i';
      final shiftCount = segmentShiftCounts[shiftKey] ?? 0;
      final SegmentResult segmentResult = timetableController
          .findNextTrainTimesByLineNames(
            lineNames: segment.lineNames,
            departureStation: segment.departureStation,
            arrivalStation: segment.arrivalStation,
            baseTime: runningTime,
            shiftCount: shiftCount,
          );

      departureTimes.add(segmentResult.dep);
      arrivalTimes.add(segmentResult.arr);
      lineNames.add(segmentResult.lineName);

      // 次の乗り換えがある場合は、本物の到着時刻に徒歩時間を足す
      runningTime = timetableController.addMinutes(
        segmentResult.arr,
        segment.walkTimeAfter,
      );
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
            // Text(
            //   route.name,
            //   maxLines: 1,
            //   overflow: TextOverflow.ellipsis,
            //   style: const TextStyle(
            //     fontSize: 14,
            //     fontWeight: FontWeight.bold,
            //     color: Colors.white,
            //   ),
            // ),
            // const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    route.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // 右側の三点リーダー（メニューボタン）
                InkWell(
                  onTapDown: (details) {
                    onRouteMenu(details.globalPosition);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.more_vert, // 縦の三点リーダー
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              "${formatTime(departureTimes.first)} -> ${formatTime(arrivalTimes.last)} 着",
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
                      LineRow(
                        displayLineName: _formatLineName(
                          route.segments[i].lineNames,
                          i,
                        ),
                        lineColor: lineController.lineColor(lineNames[i]),
                      ),
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

  String _formatLineName(List<String> lineNames, int index) {
    // インデックスが範囲内かチェックするガード
    if (index < 0 || index >= lineNames.length) {
      return '';
    }

    // 複数の路線がある場合は名前の後ろに ' ... ' を付与する
    return lineNames.length > 1 ? '${lineNames[index]} ... ' : lineNames[index];
  }
}
