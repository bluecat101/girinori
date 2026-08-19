import 'package:flutter/material.dart';

// ============================================================
// 時刻フォーマット
// ============================================================
String formatTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
