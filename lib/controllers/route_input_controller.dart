import 'package:flutter/material.dart';

import 'package:girinori/models/transit_model.dart';

class RouteInputData {
  final TextEditingController nameController;
  final List<TextEditingController> viaStationControllers = [];
  final List<TextEditingController> walkTimeControllers = [];
  final List<String?> selectedLines = [];

  RouteInputData({required String defaultName})
    : nameController = TextEditingController(text: defaultName);
  void dispose() {
    nameController.dispose();
    for (final controller in viaStationControllers) {
      controller.dispose();
    }
    for (final controller in walkTimeControllers) {
      controller.dispose();
    }
  }
}

class RouteInputController {
  RouteInputController({required this.routeMaster, this.editingRoutes}) {
    initialize();
  }

  // ============================================================
  // Data
  // ============================================================
  final Map<String, Map<String, List<dynamic>>> routeMaster;
  final List<TransitRoute>? editingRoutes;

  // ============================================================
  // 共通駅
  // ============================================================
  late final TextEditingController departureController;
  late final TextEditingController arrivalController;

  // ============================================================
  // Routes
  // ============================================================
  final List<RouteInputData> routes = [];
  int currentRouteIndex = 0;

  // ============================================================
  // Form Keys
  // ============================================================
  final List<GlobalKey<FormState>> formKeys = [];

  // ============================================================
  // 初期化
  // ============================================================
  void initialize() {
    if (editingRoutes != null && editingRoutes!.isNotEmpty) {
      _initializeFromEditingRoutes();
    } else {
      _initializeNewRoute();
    }
  }

  // ============================================================
  // Getters
  // ============================================================
  RouteInputData get currentRoute => routes[currentRouteIndex];
  int get totalNodes => currentRoute.viaStationControllers.length + 2;
  int get routeCount => routes.length;

  // ============================================================
  // 編集データから初期化
  // ============================================================
  void _initializeFromEditingRoutes() {
    final firstRoute = editingRoutes!.first;
    departureController = TextEditingController(
      text: firstRoute.segments.first.departureStation,
    );
    arrivalController = TextEditingController(
      text: firstRoute.segments.last.arrivalStation,
    );
    for (final route in editingRoutes!) {
      formKeys.add(GlobalKey<FormState>());
      final inputData = RouteInputData(defaultName: route.name);
      for (int i = 0; i < route.segments.length; i++) {
        final segment = route.segments[i];
        if (i == 0) {
          inputData.selectedLines.add(segment.line);
        } else {
          inputData.viaStationControllers.add(
            TextEditingController(text: segment.departureStation),
          );
          inputData.selectedLines.add(segment.line);
        }
        if (i < route.segments.length - 1) {
          inputData.walkTimeControllers.add(
            TextEditingController(text: segment.walkTimeAfter.toString()),
          );
        }
      }
      routes.add(inputData);
    }
  }

  // ============================================================
  // 新規ルート
  // ============================================================
  void _initializeNewRoute() {
    departureController = TextEditingController(text: '横浜');
    arrivalController = TextEditingController(text: '桜木町');
    formKeys.add(GlobalKey<FormState>());
    final route = RouteInputData(defaultName: 'ルート 1');
    // 最初の区間の路線選択欄を用意する
    route.selectedLines.add(null);
    routes.add(route);
  }

  // ============================================================
  // ルート追加
  // ============================================================
  void addNewRouteTemplate() {
    final nextNumber = routes.length + 1;
    formKeys.add(GlobalKey<FormState>());
    routes.add(RouteInputData(defaultName: 'ルート $nextNumber'));
    currentRouteIndex = routes.length - 1;
  }

  // ============================================================
  // ルート削除
  // ============================================================
  void removeRoute(int index) {
    if (routes.length <= 1) {
      return;
    }

    routes[index].dispose();
    routes.removeAt(index);
    formKeys.removeAt(index);
    if (index >= routes.length) {
      currentRouteIndex = routes.length - 1;
    } else {
      currentRouteIndex = index;
    }
  }

  // ============================================================
  // 経由駅追加
  // ============================================================

  void addTransferStation() {
    final route = currentRoute;
    route.viaStationControllers.add(TextEditingController());
    route.walkTimeControllers.add(TextEditingController(text: '3'));
    route.selectedLines.add(null);
  }

  // ============================================================
  // 経由駅削除
  // ============================================================

  void removeTransferStation(int viaIndex) {
    final route = currentRoute;
    if (viaIndex < 0 || viaIndex >= route.viaStationControllers.length) {
      return;
    }
    route.viaStationControllers[viaIndex].dispose();
    route.walkTimeControllers[viaIndex].dispose();
    route.viaStationControllers.removeAt(viaIndex);
    route.walkTimeControllers.removeAt(viaIndex);
    // 経由駅を1つ削除すると、
    // その駅に対応する路線を削除
    if (viaIndex + 1 < route.selectedLines.length) {
      route.selectedLines.removeAt(viaIndex + 1);
    }
  }

  List<String> getAvailableLines(int segmentIndex) {
    final route = currentRoute;
    // 範囲チェック
    if (segmentIndex < 0 || segmentIndex >= route.selectedLines.length) {
      return [];
    }

    // 駅ノードの数が足りない場合
    final viaCount = route.viaStationControllers.length;
    if (segmentIndex > viaCount) {
      return [];
    }

    final String depStation;
    if (segmentIndex == 0) {
      depStation = departureController.text.trim();
    } else {
      final viaIndex = segmentIndex - 1;
      if (viaIndex >= viaCount) {
        return [];
      }
      depStation = route.viaStationControllers[viaIndex].text.trim();
    }

    final String arrStation;
    if (segmentIndex == route.selectedLines.length - 1) {
      arrStation = arrivalController.text.trim();
    } else {
      if (segmentIndex >= viaCount) {
        return [];
      }
      arrStation = route.viaStationControllers[segmentIndex].text.trim();
    }

    if (depStation.isEmpty || arrStation.isEmpty) {
      return [];
    }

    final depStationData = routeMaster[depStation];
    if (depStationData == null) {
      return [];
    }
    final validLines = <String>[];
    depStationData.forEach((lineId, stopStations) {
      if (stopStations.contains(arrStation)) {
        validLines.add(lineId);
      }
    });
    return validLines;
  }

  // ============================================================
  // 路線選択
  // ============================================================
  void selectLine(int segmentIndex, String? line) {
    final route = currentRoute;
    if (segmentIndex < 0 || segmentIndex >= route.selectedLines.length) {
      return;
    }

    final availableLines = getAvailableLines(segmentIndex);
    if (line != null && !availableLines.contains(line)) {
      route.selectedLines[segmentIndex] = null;
      return;
    }
    route.selectedLines[segmentIndex] = line;
  }

  // ============================================================
  // 全ルートをTransitRouteへ変換
  // ============================================================

  List<TransitRoute> compileAllRoutes() {
    final compiledRoutes = <TransitRoute>[];
    for (int routeIndex = 0; routeIndex < routes.length; routeIndex++) {
      final routeData = routes[routeIndex];
      final segments = <TransitSegment>[];
      final totalSegments = routeData.selectedLines.length;
      for (int i = 0; i < totalSegments; i++) {
        final String dep;
        if (i == 0) {
          dep = departureController.text;
        } else {
          dep = routeData.viaStationControllers[i - 1].text;
        }

        final String arr;
        if (i == totalSegments - 1) {
          arr = arrivalController.text;
        } else {
          arr = routeData.viaStationControllers[i].text;
        }

        final int walk;
        if (i < routeData.walkTimeControllers.length) {
          walk = int.tryParse(routeData.walkTimeControllers[i].text) ?? 0;
        } else {
          walk = 0;
        }
        segments.add(
          TransitSegment(
            departureStation: dep,
            line: routeData.selectedLines[i] ?? '',
            duration: 15,
            arrivalStation: arr,
            walkTimeAfter: walk,
          ),
        );
      }

      compiledRoutes.add(
        TransitRoute(
          id: '${DateTime.now().millisecondsSinceEpoch}$routeIndex',
          name: routeData.nameController.text,
          segments: segments,
        ),
      );
    }
    return compiledRoutes;
  }

  // ============================================================
  // Dispose
  // ============================================================
  void dispose() {
    departureController.dispose();
    arrivalController.dispose();
    for (final route in routes) {
      route.dispose();
    }
  }

  /// ============================================================
  /// Getters for Controllers
  /// ============================================================
  TextEditingController getStationController(int nodeIndex) {
    if (nodeIndex == 0) {
      return departureController;
    }
    if (nodeIndex == totalNodes - 1) {
      return arrivalController;
    }
    return currentRoute.viaStationControllers[nodeIndex - 1];
  }

  TextEditingController? getWalkTimeController(int nodeIndex) {
    if (nodeIndex == 0 || nodeIndex == totalNodes - 1) {
      return null;
    }
    return currentRoute.walkTimeControllers[nodeIndex - 1];
  }

  String? getSelectedLine(int segmentIndex) {
    final route = currentRoute;

    if (segmentIndex < 0 || segmentIndex >= route.selectedLines.length) {
      return null;
    }

    return route.selectedLines[segmentIndex];
  }
}
