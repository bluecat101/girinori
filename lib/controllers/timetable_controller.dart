import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:girinori/models/route_master_model.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/models/trip_model.dart';

class TrainDayRange {
  final int firstTrain;
  final int lastTrain;

  const TrainDayRange({required this.firstTrain, required this.lastTrain});
}

class _TrainCandidate {
  final Trip trip;
  final int departureMinutes;
  final int arrivalMinutes;

  const _TrainCandidate({
    required this.trip,
    required this.departureMinutes,
    required this.arrivalMinutes,
  });
}

class TimetableController {
  TimetableController({required this.routeMaster});

  /// 駅マスタ
  final RouteMaster routeMaster;

  // Map<String, Map<String, List<dynamic>>> routeMaster = {};

  /// 路線ごとの時刻表キャッシュ
  /// {路線ID: List< Trip >}のマップ
  final Map<String, List<Trip>> cachedTimetables = {};

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

  /// ============================================================
  /// 路線時刻表読み込み(From 路線名)
  /// ============================================================
  Future<void> loadTimetableFileForLines(List<String> lineIds) async {
    for (final lineId in lineIds) {
      await _loadTimetableFileForLine(lineId);
    }
  }

  // ============================================================
  // 路線時刻表読み込み(From 路線ID)
  // ============================================================
  Future<void> _loadTimetableFileForLine(String lineId) async {
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
        cachedTimetables[lineId] = (lineData['trips'] as List)
            .map((trip) => Trip.fromJson(Map<String, dynamic>.from(trip)))
            .toList();
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
    required List<Trip> trips,
  }) {
    final dayRanges = <String, Map<String, TrainDayRange>>{};

    for (final trip in trips) {
      final dayType = trip.dayType;
      final stopTimes = trip.stopTimes;

      // 曜日区分がまだなければ作る
      final stationRanges = dayRanges.putIfAbsent(
        dayType,
        () => <String, TrainDayRange>{},
      );

      // この列車に存在する全駅を見る
      for (final entry in stopTimes.entries) {
        final station = entry.key;
        final stopTime = entry.value;

        // depを優先し、なければarr
        final int? minute = stopTime.dep ?? stopTime.arr;

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
      return 'sunday';
    }

    return 'weekday';
  }

  SegmentResult findNextTrainTimesByLineIds({
    required List<String> lineIds,
    required String departureStation,
    required String arrivalStation,
    required TimeOfDay baseTime,
    bool isLookingBackward = false,
  }) {
    // 出発駅の路線情報を取得
    final depLineIds = routeMaster[departureStation]?.keys.toList();
    if (depLineIds == null) {
      return SegmentResult(dep: baseTime, arr: baseTime, lineName: '');
    }

    TimeOfDay? earliestDeparture;
    TimeOfDay? earliestArrival;
    String earliestLineName = '';

    int? targetDiff; // 基準からの差分の最小値を保持する変数
    final int baseMinutes = baseTime.hour * 60 + baseTime.minute;

    for (final lineId in lineIds) {
      // 内部の単道路線検索を呼び出す
      final (TimeOfDay dep, TimeOfDay arr) = _findNextTrainTimes(
        lineId: lineId,
        departureStation: departureStation,
        arrivalStation: arrivalStation,
        baseTime: baseTime,
        isLookingBackward: isLookingBackward,
      );
      if (dep != baseTime || arr != baseTime) {
        int depMinutes = dep.hour * 60 + dep.minute;

        // 日付またぎの補正（必要に応じて調整）
        if (!isLookingBackward && depMinutes < baseMinutes) {
          depMinutes += 24 * 60; // 未来方向で日付をまたぐ場合
        } else if (isLookingBackward && depMinutes > baseMinutes) {
          depMinutes -= 24 * 60; // 過去方向で日付をまたぐ場合（前日の深夜など）
        }

        // 差分の計算（未来か過去かで計算の向きが変わる）
        final int diff = isLookingBackward
            ? baseMinutes -
                  depMinutes // 過去方向の差分（例: 30分前なら +30）
            : depMinutes - baseMinutes; // 未来方向の差分（例: 30分後なら +30）

        // 💡 差分が有効（0以上）かつ、より近いものを採用する
        if (diff >= 0) {
          if (targetDiff == null || diff < targetDiff) {
            targetDiff = diff;
            earliestDeparture = dep;
            earliestLineName = _extractUniqueLineName(lineId);
            earliestArrival = arr;
          }
        }
      }
    }

    return SegmentResult(
      dep: earliestDeparture ?? baseTime,
      arr: earliestArrival ?? baseTime,
      lineName: earliestLineName,
    );
  }

  (TimeOfDay, TimeOfDay) _findNextTrainTimes({
    required String lineId,
    required String departureStation,
    required String arrivalStation,
    required TimeOfDay baseTime, // 始発終電に関わらず、0 ~ 1440の範囲で定義される
    required bool isLookingBackward, // 過去の列車を探すかどうかのフラグ
  }) {
    final jsonTrips = cachedTimetables[lineId];
    assert(
      jsonTrips != null && jsonTrips.isNotEmpty,
      '路線 [$lineId] の時刻表がロードされていません。',
    );

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
    // 基準日の時刻表を取得
    // ============================================================
    List<_TrainCandidate> getCandidates(DateTime date, int dayOffset) {
      final dayType = _dayTypeFromDate(date);

      final candidates = <_TrainCandidate>[];

      for (final trip in jsonTrips!) {
        if (trip.dayType != dayType) {
          continue;
        }
        final stopTimes = trip.stopTimes;

        final depTiming = stopTimes[departureStation];
        final arrTiming = stopTimes[arrivalStation];
        if (depTiming == null || arrTiming == null) {
          continue;
        }

        final int? depMin = depTiming.dep ?? depTiming.arr;
        final int? arrMin = arrTiming.arr ?? arrTiming.dep;
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
    // ============================================================
    int targetIndex = -1;

    if (!isLookingBackward) {
      // 🔀 【未来（次へ）を探す場合】
      // 基準時間（normalizedBaseMinutes）「以降」で最初の列車を探す
      for (int i = 0; i < candidates.length; i++) {
        if (candidates[i].departureMinutes >= normalizedBaseMinutes) {
          targetIndex = i;
          break;
        }
      }
    } else {
      // 🔙 【過去（1本前）を探す場合】
      // 基準時間（normalizedBaseMinutes）「以前」で、一番後ろ（直前の列車）を探す
      for (int i = candidates.length - 1; i >= 0; i--) {
        if (candidates[i].departureMinutes <= normalizedBaseMinutes) {
          targetIndex = i;
          break;
        }
      }
    }

    // 万が一見つからなかった場合の安全ガード
    if (targetIndex == -1) {
      targetIndex = isLookingBackward ? 0 : candidates.length - 1;
    }

    final dep = candidates[targetIndex].departureMinutes;
    final arr = candidates[targetIndex].arrivalMinutes;

    _hasNextTimeTable = (targetIndex != candidates.length - 1);
    _hasPreviousTimeTable = (targetIndex != 0);

    // ============================================================
    // TimeOfDayへ変換
    // ============================================================
    final departureTime = _convertToTimeOfDay(dep);
    final arrivalTime = _convertToTimeOfDay(arr);
    return (departureTime, arrivalTime);
  }

  TimeOfDay _convertToTimeOfDay(int minutes) {
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

  /// ============================================================
  /// 路線名からユニークな路線名を抽出する
  /// ============================================================
  String _extractUniqueLineName(String fullLineName) {
    return fullLineName.split('_').first;
  }
}
