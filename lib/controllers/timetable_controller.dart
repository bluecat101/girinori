import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimetableController {
  /// 駅マスタ
  Map<String, Map<String, List<dynamic>>> routeMaster = {};

  /// 路線ごとの時刻表キャッシュ
  ///
  /// Key:
  ///   ＪＲ根岸線_大宮・南浦和方面
  ///
  /// Value:
  ///   その路線の trips
  final Map<String, List<dynamic>> cachedTimetables = {};

  // ============================================================
  // 駅マスタ読み込み
  // ============================================================

  Future<void> loadRouteMasterFile() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/route_master.json',
      );

      final Map<String, dynamic> rawMap = jsonDecode(jsonString);
      final formattedMaster = <String, Map<String, List<dynamic>>>{};
      rawMap.forEach((station, routes) {
        final routeMap = <String, List<dynamic>>{};
        if (routes is Map<String, dynamic>) {
          routes.forEach((lineId, stopStations) {
            if (stopStations is List) {
              routeMap[lineId] = stopStations;
            }
          });
        }
        formattedMaster[station] = routeMap;
      });
      routeMaster = formattedMaster;
      debugPrint(
        '🚀 駅マスタのロード成功'
        '（${routeMaster.length}駅）',
      );
    } catch (e) {
      debugPrint('❌ 駅マスタのロード失敗: $e');
    }
  }

  // ============================================================
  // 路線時刻表読み込み
  // ============================================================
  Future<void> loadTimetableFileForLine(String lineId) async {
    // すでに読み込み済みなら何もしない
    if (cachedTimetables.containsKey(lineId)) {
      return;
    }
    try {
      final safeFilename = lineId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final jsonString = await rootBundle.loadString(
        'assets/$safeFilename.json',
      );
      final Map<String, dynamic> lineData = jsonDecode(jsonString);
      if (lineData.containsKey('trips')) {
        cachedTimetables[lineId] = lineData['trips'] as List<dynamic>;

        debugPrint(
          '🚊 路線ファイルのロード成功: '
          'timetable_$safeFilename.json '
          '(${cachedTimetables[lineId]!.length}本収容)',
        );
      }
    } catch (e) {
      debugPrint('❌ 路線ファイル [$lineId] のロードに失敗: $e');
    }
  }

  // ============================================================
  // 曜日判定
  // ============================================================
  String _getTodayDayType() {
    final now = DateTime.now();
    if (now.weekday == DateTime.saturday) {
      return 'saturday';
    }
    if (now.weekday == DateTime.sunday) {
      return 'sunday';
    }
    return 'weekday';
  }

  // ============================================================
  // 列車時刻検索
  // ============================================================

  (TimeOfDay, TimeOfDay) findNextTrainTimes({
    required String lineId,
    required String departureStation,
    required String arrivalStation,
    required TimeOfDay baseTime,
    int shiftCount = 0,
  }) {
    final jsonTrips = cachedTimetables[lineId];
    if (jsonTrips == null) {
      return (baseTime, baseTime);
    }
    final dayType = _getTodayDayType();
    final baseMinutes = baseTime.hour * 60 + baseTime.minute;
    final validTrips = <Map<String, dynamic>>[];
    final depMinutesList = <int>[];
    // ----------------------------------------------------------
    // 今日走っている列車を抽出
    // ----------------------------------------------------------
    for (final trip in jsonTrips) {
      if (trip['day_type'] != dayType) {
        continue;
      }
      final stopTimes = trip['stop_times'] as Map<String, dynamic>;
      final depTiming = stopTimes[departureStation];
      final arrTiming = stopTimes[arrivalStation];
      if (depTiming == null || arrTiming == null) {
        continue;
      }
      final int? depMin = depTiming['dep'] ?? depTiming['arr'];
      if (depMin != null) {
        validTrips.add(trip as Map<String, dynamic>);
        depMinutesList.add(depMin);
      }
    }
    if (depMinutesList.isEmpty) {
      return (baseTime, baseTime);
    }

    // ----------------------------------------------------------
    // 出発時刻順に並べる
    // ----------------------------------------------------------
    final sortedIndices = List<int>.generate(depMinutesList.length, (i) => i);
    sortedIndices.sort(
      (a, b) => depMinutesList[a].compareTo(depMinutesList[b]),
    );

    // ----------------------------------------------------------
    // 基準時刻以降で最初の列車を探す
    // ----------------------------------------------------------
    int baseIndexInSorted = 0;
    bool found = false;
    for (int i = 0; i < sortedIndices.length; i++) {
      if (depMinutesList[sortedIndices[i]] >= baseMinutes) {
        baseIndexInSorted = i;
        found = true;
        break;
      }
    }
    if (!found) {
      baseIndexInSorted = 0;
    }

    // ----------------------------------------------------------
    // シフト
    // ----------------------------------------------------------
    int targetIndexInSorted = baseIndexInSorted + shiftCount;
    // 始発以前には行かない
    if (targetIndexInSorted < 0) {
      targetIndexInSorted = 0;
    }
    // 終電以降には行かない
    if (targetIndexInSorted >= sortedIndices.length) {
      targetIndexInSorted = sortedIndices.length - 1;
    }

    // ----------------------------------------------------------
    // 対象列車
    // ----------------------------------------------------------
    final targetTrip = validTrips[sortedIndices[targetIndexInSorted]];
    final targetStopTimes = targetTrip['stop_times'] as Map<String, dynamic>;
    final int finalDepMin =
        targetStopTimes[departureStation]['dep'] ??
        targetStopTimes[departureStation]['arr'];
    final int finalArrMin =
        targetStopTimes[arrivalStation]['arr'] ??
        targetStopTimes[arrivalStation]['dep'];
    return (
      TimeOfDay(hour: (finalDepMin ~/ 60) % 24, minute: finalDepMin % 60),
      TimeOfDay(hour: (finalArrMin ~/ 60) % 24, minute: finalArrMin % 60),
    );
  }

  // ============================================================
  // 時刻加算
  // ============================================================
  TimeOfDay addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }
}
