import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TrainDayRange {
  final int firstTrain;
  final int lastTrain;

  const TrainDayRange({required this.firstTrain, required this.lastTrain});
}

class _TrainCandidate {
  final Map<String, dynamic> trip;
  final int departureMinutes;
  final int arrivalMinutes;

  const _TrainCandidate({
    required this.trip,
    required this.departureMinutes,
    required this.arrivalMinutes,
  });
}

class TimetableController {
  /// 駅マスタ
  /// {駅名: {路線ID: [停車駅リスト]}}のマップ
  Map<String, Map<String, List<dynamic>>> routeMaster = {};

  /// 路線ごとの時刻表キャッシュ
  /// {路線ID: List<trips>}のマップ
  final Map<String, List<dynamic>> cachedTimetables = {};

  /// {路線ID:{曜日区分:{駅:始発・終電}}}のマップ
  final Map<String, Map<String, Map<String, TrainDayRange>>> trainDayRanges =
      {};

  /// 路線IDと時刻表ファイル名のマップ
  Map<String, String> timetableFileMap = {};

  // 次の時刻表を表示できるのかを定義
  bool _hasNextTimeTable = true;
  bool _hasPreviousTimeTable = true;

  bool get hasNextTimeTable => _hasNextTimeTable;
  bool get hasPreviousTimeTable => _hasPreviousTimeTable;

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
  // 路線時刻表インデックス読み込み
  // ============================================================
  Future<void> loadTimetableIndex() async {
    final jsonString = await rootBundle.loadString(
      'assets/timetable_index.json',
    );

    final Map<String, dynamic> data = jsonDecode(jsonString);

    timetableFileMap = data.map(
      (key, value) => MapEntry(key, value.toString()),
    );
  }

  Future<void> loadTimetableFileForLine(String lineId) async {
    if (cachedTimetables.containsKey(lineId)) {
      return;
    }

    final fileName = timetableFileMap[lineId];

    if (fileName == null) {
      debugPrint('❌ timetable file not found: $lineId');
      return;
    }

    try {
      final jsonString = await rootBundle.loadString('assets/$fileName');

      final Map<String, dynamic> lineData = jsonDecode(jsonString);

      if (lineData['trips'] is List) {
        cachedTimetables[lineId] = List<dynamic>.from(lineData['trips']);
      }
      // 始発・終電を作成
      _buildTrainDayRanges(lineId: lineId, trips: cachedTimetables[lineId]!);
    } catch (e) {
      debugPrint('❌ 路線ファイル [$lineId] のロード失敗: $e');
    }
  }

  /// ============================================================
  /// 始発・終電のキャッシュを作る
  ///  ============================================================
  void _buildTrainDayRanges({
    required String lineId,
    required List<dynamic> trips,
  }) {
    final dayRanges = <String, Map<String, TrainDayRange>>{};

    for (final trip in trips) {
      final dayType = trip['day_type'] as String?;
      if (dayType == null) {
        continue;
      }
      final stopTimes = trip['stop_times'] as Map<String, dynamic>?;
      if (stopTimes == null) {
        continue;
      }

      // 曜日区分がまだなければ作る
      final stationRanges = dayRanges.putIfAbsent(
        dayType,
        () => <String, TrainDayRange>{},
      );

      // この列車に存在する全駅を見る
      for (final entry in stopTimes.entries) {
        final station = entry.key;
        final timing = entry.value as Map<String, dynamic>;

        // depを優先し、なければarr
        final int? minute = timing['dep'] as int? ?? timing['arr'] as int?;

        if (minute == null) {
          continue;
        }

        final current = stationRanges[station];
        if (current == null) {
          // 初めて見た駅
          stationRanges[station] = TrainDayRange(
            firstTrain: minute,
            lastTrain: minute,
          );
        } else {
          // 始発・終電を更新
          stationRanges[station] = TrainDayRange(
            firstTrain: minute < current.firstTrain
                ? minute
                : current.firstTrain,
            lastTrain: minute > current.lastTrain ? minute : current.lastTrain,
          );
        }
      }
    }

    trainDayRanges[lineId] = dayRanges;
  }

  // ============================================================
  // 曜日区分
  // ============================================================
  String _dayTypeFromDate(DateTime date) {
    if (date.weekday == DateTime.saturday) {
      return 'saturday';
    }

    if (date.weekday == DateTime.sunday) {
      return 'sundayHoliday';
    }

    return 'weekday';
  }

  (TimeOfDay, TimeOfDay) findNextTrainTimes({
    required String lineId,
    required String departureStation,
    required String arrivalStation,
    required TimeOfDay baseTime, // 始発終電に関わらず、0 ~ 1440の範囲で定義される
    int shiftCount = 0,
  }) {
    final jsonTrips = cachedTimetables[lineId];
    if (jsonTrips == null || jsonTrips.isEmpty) {
      return (baseTime, baseTime);
    }

    // ============================================================
    // 現在時刻
    // ============================================================
    final now = DateTime.now();
    final todayDayType = _dayTypeFromDate(now);
    final todayRange = trainDayRanges[lineId]?[todayDayType]?[departureStation];

    if (todayRange == null) {
      debugPrint(
        '❌ 始発・終電情報なし: '
        '$lineId / $todayDayType / $departureStation',
      );
      return (baseTime, baseTime);
    }
    final baseMinutes = baseTime.hour * 60 + baseTime.minute;
    // ============================================================
    // 基準日を決める
    // 現曜日の始発前であれば、昨日の深夜帯の時刻表を見るために、１日(1440分)加算する
    // ============================================================
    DateTime baseDate = now;
    int normalizedBaseMinutes = baseMinutes;
    if (baseMinutes < todayRange.firstTrain) {
      baseDate = now.subtract(const Duration(days: 1));
      normalizedBaseMinutes += 1440;
      // 曜日の変更
    }

    // ============================================================
    // 基準日の曜日
    // ============================================================
    // final baseDayType = _dayTypeFromDate(baseDate);

    // ============================================================
    // 基準日の時刻表を取得
    // ============================================================
    List<_TrainCandidate> getCandidates(DateTime date, int dayOffset) {
      final dayType = _dayTypeFromDate(date);

      final candidates = <_TrainCandidate>[];

      for (final rawTrip in jsonTrips) {
        if (rawTrip['day_type'] != dayType) {
          continue;
        }
        final trip = rawTrip as Map<String, dynamic>;
        final stopTimes = trip['stop_times'];
        if (stopTimes is! Map<String, dynamic>) {
          continue;
        }

        final depTiming = stopTimes[departureStation];
        final arrTiming = stopTimes[arrivalStation];
        if (depTiming == null || arrTiming == null) {
          continue;
        }

        final int? depMin = depTiming['dep'] ?? depTiming['arr'];
        final int? arrMin = arrTiming['arr'] ?? arrTiming['dep'];
        if (depMin == null || arrMin == null) {
          continue;
        }

        candidates.add(
          _TrainCandidate(
            trip: trip,
            departureMinutes: dayOffset * 1440 + depMin,
            arrivalMinutes: dayOffset * 1440 + arrMin,
          ),
        );
      }

      candidates.sort(
        (a, b) => a.departureMinutes.compareTo(b.departureMinutes),
      );

      return candidates;
    }

    // ============================================================
    // 前日・当日・翌日の列車をまとめる
    // ============================================================

    final candidates = <_TrainCandidate>[];
    // 基準値以前の曜日の時刻はマイナスとなる
    candidates.addAll(
      getCandidates(baseDate.subtract(const Duration(days: 1)), -1),
    );
    candidates.addAll(getCandidates(baseDate, 0));
    candidates.addAll(getCandidates(baseDate.add(const Duration(days: 1)), 1));

    if (candidates.isEmpty) {
      debugPrint(
        '❌ 該当列車なし: '
        '$lineId / $departureStation → $arrivalStation',
      );
      return (baseTime, baseTime);
    }

    // ============================================================
    // 全体を時刻順にする
    // ============================================================
    candidates.sort((a, b) => a.departureMinutes.compareTo(b.departureMinutes));

    // ============================================================
    // 基準列車を探す
    // 基準の時間（normalizedBaseMinutes）以降で最初の列車を探す
    // ============================================================
    int baseIndex = -1;
    for (int i = 0; i < candidates.length; i++) {
      if (candidates[i].departureMinutes >= normalizedBaseMinutes) {
        baseIndex = i;
        break;
      }
    }

    assert(baseIndex != -1, '時刻表から検索できませんでした。');

    // ============================================================
    // shiftCount
    // ============================================================
    int targetIndex = baseIndex + shiftCount;
    if (targetIndex < 0) {
      targetIndex = 0;
    }
    if (targetIndex >= candidates.length) {
      targetIndex = candidates.length - 1;
    }
    final target = candidates[targetIndex];

    _hasNextTimeTable = (targetIndex != candidates.length - 1);
    _hasPreviousTimeTable = (targetIndex != 0);

    // ============================================================
    // TimeOfDayへ変換
    // ============================================================
    final departureTime = convertToTimeOfDay(target.departureMinutes);
    final arrivalTime = convertToTimeOfDay(target.arrivalMinutes);
    return (departureTime, arrivalTime);
  }

  TimeOfDay convertToTimeOfDay(int minutes) {
    minutes = minutes % 1440; // 24時間を超える場合は繰り返す
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  // ============================================================
  // 時刻加算
  // ============================================================
  TimeOfDay addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }
}
