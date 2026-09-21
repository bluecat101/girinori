import 'package:flutter/services.dart'; // 💡 rootBundle（ファイル読み込み）に必要です
import 'package:flutter/material.dart';
import 'package:girinori/controllers/line_controller.dart';
import 'package:girinori/controllers/timetable_controller.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/utils/format_time.dart';
import 'package:girinori/widgets/dashboard/line_row.dart';
import 'package:girinori/widgets/dashboard/station_row.dart';

class RouteTimelineCard extends StatefulWidget {
  final TransitRoute route;
  final TimetableController timetableController;
  final LineController lineController;
  final void Function(Offset globalPosition) onRouteMenu;

  const RouteTimelineCard({
    super.key,
    required this.route,
    required this.timetableController,
    required this.lineController,
    required this.onRouteMenu,
  });

  @override
  State<RouteTimelineCard> createState() => _RouteTimelineCardState();
}

class _RouteTimelineCardState extends State<RouteTimelineCard> {
  late TransitRoute _route;
  int startUpdateIndex = 0;
  bool isLookingBackward = false; // 過去の列車を探すかどうかのフラグ
  List<int> _segmentShiftCounts = [];
  List<TimeOfDay> _segmentBaseTimes = [];
  // 表示するための出発時刻、到着時刻、路線名を格納するリストを作成
  List<TimeOfDay> _departureTimes = [];
  List<TimeOfDay> _arrivalTimes = [];
  List<String> _lineNames = []; // 区間の路線名を格納するリスト

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    _initializeRouteData();
  }

  void _initializeRouteData() {
    // シフト回数リストの初期化
    _segmentShiftCounts = List.filled(_route.segments.length, 0);

    // 基準時刻リストの初期化
    final now = TimeOfDay.now();
    _segmentBaseTimes = List.generate(_route.segments.length, (index) => now);

    _departureTimes = List.generate(_route.segments.length, (index) => now);
    _arrivalTimes = List.generate(_route.segments.length, (index) => now);
    _lineNames = List.generate(_route.segments.length, (index) => "");
  }

  @override
  Widget build(BuildContext context) {
    for (int i = startUpdateIndex; i < _route.segments.length; i++) {
      final segment = _route.segments[i];
      // この区間のシフト数のキーを作成して取得する
      final shiftCount = _segmentShiftCounts[i];
      final SegmentResult segmentResult = widget.timetableController
          .findNextTrainTimesByLineIds(
            lineIds: segment.lineIds,
            departureStation: segment.departureStation,
            arrivalStation: segment.arrivalStation,
            baseTime: _segmentBaseTimes[i],
            isLookingBackward: i == startUpdateIndex
                ? isLookingBackward
                : shiftCount <
                      0, // 最初の区間は isLookingBackward を使用し、それ以降はシフト数がマイナスかどうかで判断
          );
      _departureTimes[i] = segmentResult.dep;
      _arrivalTimes[i] = segmentResult.arr;
      _lineNames[i] = segmentResult.lineName;

      // 区間の基準時刻を更新する
      _segmentBaseTimes[i] = segmentResult.dep;
      // 次の乗り換えがある場合は、本物の到着時刻に徒歩時間を足す
      if (i < _route.segments.length - 1) {
        _segmentBaseTimes[i + 1] = widget.timetableController.addMinutes(
          segmentResult.arr,
          segment.walkTimeAfter,
        );
        _segmentShiftCounts[i + 1] = 0; // 次の区間のシフト数をリセット
      }
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    _route.name,
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
                    widget.onRouteMenu(details.globalPosition);
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
              "${formatTime(_departureTimes.first)} -> ${formatTime(_arrivalTimes.last)} 着",
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
                    for (int i = 0; i < _route.segments.length; i++) ...[
                      DashboardStationRow(
                        routeId: _route.id,
                        segmentIndex: i,
                        stationName: _route.segments[i].departureStation,
                        arrivalTime: i == 0 ? null : _arrivalTimes[i - 1],
                        departureTime: _departureTimes[i],
                        segment: _route.segments[i],
                        isStart: i == 0,
                        isEnd: false,
                        isNextButtonEnabled:
                            widget.timetableController.hasNextTimeTable,
                        isPreviousButtonEnabled:
                            widget.timetableController.hasPreviousTimeTable,
                        shiftCount: _segmentShiftCounts[i],
                        onShiftTrain: (isNext) {
                          _shiftTrainCount(i, isNext);
                        },
                      ),
                      LineRow(
                        displayLineName: _formatLineName(
                          TransitSegment.extractUniqueLineIds(
                            _route.segments[i].lineIds,
                          ),
                          i,
                        ),
                        lineColor: widget.lineController.lineColor(
                          _lineNames[i],
                        ),
                      ),
                    ],
                    // 到着駅を表示する
                    DashboardStationRow(
                      routeId: _route.id,
                      segmentIndex: _route.segments.length,
                      stationName: _route.segments.last.arrivalStation,
                      arrivalTime: _arrivalTimes.last,
                      departureTime: null,
                      segment: _route.segments.last,
                      isStart: false,
                      isEnd: true, // 到着駅には列車変更ボタンがない
                      isNextButtonEnabled:
                          widget.timetableController.hasNextTimeTable,
                      isPreviousButtonEnabled:
                          widget.timetableController.hasPreviousTimeTable,
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

  /// 列車のシフト数を更新する
  void _shiftTrainCount(int segmentIndex, bool isNext) {
    setState(() {
      final currentShift = _segmentShiftCounts[segmentIndex];

      _segmentShiftCounts[segmentIndex] = isNext
          ? currentShift + 1
          : currentShift - 1;
      // 更新開始インデックスを設定して、次回のビルド時にその区間から再計算する
      startUpdateIndex = segmentIndex;
      isLookingBackward = !isNext;

      // 基準時刻を更新する
      _segmentBaseTimes[segmentIndex] = widget.timetableController.addMinutes(
        _segmentBaseTimes[segmentIndex],
        isNext ? 1 : -1,
      );
    });
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
