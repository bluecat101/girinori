import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:girinori/models/route_master_model.dart';

class RouteMasterProvider extends ChangeNotifier {
  RouteMaster _routeMaster = {};

  RouteMaster get routeMaster => _routeMaster;
  // ============================================================
  // 駅マスタ読み込み
  // ============================================================
  Future<void> load() async {
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

      // ★ Providerが保持している値を更新
      _routeMaster = formattedMaster;
      debugPrint('🚀 駅マスタのロード成功（${_routeMaster.length}駅）');
    } catch (e) {
      debugPrint('❌ 駅マスタのロード失敗: $e');
    } finally {
      notifyListeners();
    }
  }
}
