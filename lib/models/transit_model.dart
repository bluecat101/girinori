import 'package:flutter/material.dart';

class TransitSegment {
  List<String> lineIds;
  String departureStation;
  int duration;
  String arrivalStation;
  int walkTimeAfter;

  TransitSegment({
    required this.lineIds, // 区間の路線名を保持する変数（複数の路線が存在する場合があるため、List<String>型）
    required this.departureStation, // 区間の出発駅を保持する変数
    required this.duration, // 区間の所要時間（分）を保持する変数
    required this.arrivalStation, // 区間の到着駅を保持する変数
    this.walkTimeAfter = 0, // 区間の到着駅から次の区間までの徒歩時間（分）を保持する変数
  });
  Map<String, dynamic> toJson() {
    return {
      'lineIds': lineIds,
      'departureStation': departureStation,
      'duration': duration,
      'arrivalStation': arrivalStation,
      'walkTimeAfter': walkTimeAfter,
    };
  }

  factory TransitSegment.fromJson(Map<String, dynamic> json) {
    return TransitSegment(
      lineIds: List<String>.from(json['lineIds']),
      departureStation: json['departureStation'],
      duration: json['duration'],
      arrivalStation: json['arrivalStation'],
      walkTimeAfter: json['walkTimeAfter'] ?? 0,
    );
  }

  // 区間の路線詳細名から路線名を抽出するメソッド
  static String extractUniqueLineId(String fullLineId) {
    return fullLineId.split('_').first;
  }

  // 区間の路線詳細名リストからユニークな路線名を抽出するメソッド
  static List<String> extractUniqueLineIds(List<String> fullLineIds) {
    return fullLineIds.map(extractUniqueLineId).toSet().toList();
  }
}

class TransitRoute {
  final String id;
  final String name;
  final List<TransitSegment> segments;

  TransitRoute({required this.id, required this.name, required this.segments});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'segments': segments.map((segment) => segment.toJson()).toList(),
    };
  }

  factory TransitRoute.fromJson(Map<String, dynamic> json) {
    return TransitRoute(
      id: json['id'],
      name: json['name'],
      segments: (json['segments'] as List<dynamic>)
          .map((segmentJson) => TransitSegment.fromJson(segmentJson))
          .toList(),
    );
  }
}

class SegmentResult {
  final TimeOfDay dep;
  final TimeOfDay arr;
  final String lineName;
  SegmentResult({required this.dep, required this.arr, this.lineName = ''});
}
