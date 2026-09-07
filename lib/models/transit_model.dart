import 'package:flutter/material.dart';

class TransitSegment {
  String lineName;
  String departureStation;
  int duration;
  String arrivalStation;
  int walkTimeAfter;

  TransitSegment({
    required this.lineName,
    required this.departureStation, // 区間の出発駅を保持する変数
    required this.duration, // 区間の所要時間（分）を保持する変数
    required this.arrivalStation, // 区間の到着駅を保持する変数
    this.walkTimeAfter = 0, // 区間の到着駅から次の区間までの徒歩時間（分）を保持する変数
  });
}

class TransitRoute {
  final String id;
  final String name;
  final List<TransitSegment> segments;

  TransitRoute({required this.id, required this.name, required this.segments});
}

class SegmentResult {
  final TimeOfDay dep;
  final TimeOfDay arr;
  SegmentResult({required this.dep, required this.arr});
}

class RouteResult {
  final List<SegmentResult> segmentResults;
  final int countdownMinutes;
  RouteResult({required this.segmentResults, required this.countdownMinutes});
}
