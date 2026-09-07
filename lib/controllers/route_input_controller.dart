import 'package:flutter/material.dart';

import 'package:girinori/models/transit_model.dart';

class RouteInputData {
  final TextEditingController nameController;
  final List<TextEditingController> viaStationControllers = [];
  final List<TextEditingController> walkTimeControllers = [];
  final List<String?> selectedLineNames = [];

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
  RouteInputController({required this.routeMaster, this.editingRoute}) {
    initialize();
  }

  // ============================================================
  // Data
  // ============================================================
  final Map<String, Map<String, List<dynamic>>> routeMaster;
  final TransitRoute? editingRoute;
  // final List<TransitRoute>? editingRoutes;

  // ============================================================
  // 共通駅
  // ============================================================
  late final TextEditingController departureController;
  late final TextEditingController arrivalController;

  // ============================================================
  // Route
  // ============================================================
  RouteInputData route = RouteInputData(defaultName: 'ルート 1');
  int currentRouteIndex = 0;

  // ============================================================
  // Form Keys
  // ============================================================
  late final GlobalKey<FormState> formKey;
  // ============================================================
  // 初期化
  // ============================================================
  void initialize() {
    if (editingRoute != null) {
      _initializeFromEditingRoutes();
    } else {
      _initializeNewRoute();
    }
  }

  // ============================================================
  // Getters
  // ============================================================
  RouteInputData get currentRoute => route;
  int get totalNodes => currentRoute.viaStationControllers.length + 2;
  // int get routeCount => route.length;

  // ============================================================
  // 編集データから初期化
  // ============================================================
  void _initializeFromEditingRoutes() {
    final route = editingRoute!;
    departureController = TextEditingController(
      text: route.segments.first.departureStation,
    );
    arrivalController = TextEditingController(
      text: route.segments.last.arrivalStation,
    );
    formKey = GlobalKey<FormState>();
    final inputData = RouteInputData(defaultName: route.name);
    for (int i = 0; i < route.segments.length; i++) {
      final segment = route.segments[i];
      if (i == 0) {
        inputData.selectedLineNames.add(segment.lineName);
      } else {
        inputData.viaStationControllers.add(
          TextEditingController(text: segment.departureStation),
        );
        inputData.selectedLineNames.add(segment.lineName);
      }
      if (i < route.segments.length - 1) {
        inputData.walkTimeControllers.add(
          TextEditingController(text: segment.walkTimeAfter.toString()),
        );
      }
    }
    // this.route.add(inputData);
    this.route = inputData;
  }

  // ============================================================
  // 新規ルート
  // ============================================================
  void _initializeNewRoute() {
    departureController = TextEditingController(text: '横浜');
    arrivalController = TextEditingController(text: '桜木町');
    formKey = GlobalKey<FormState>();
    final route = RouteInputData(defaultName: 'ルート 1');
    // 最初の区間の路線選択欄を用意する
    route.selectedLineNames.add(null);
    this.route = route;
  }

  // ============================================================
  // 経由駅追加
  // ============================================================

  void addTransferStation() {
    final route = currentRoute;
    route.viaStationControllers.add(TextEditingController());
    route.walkTimeControllers.add(TextEditingController(text: '3'));
    route.selectedLineNames.add(null);
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
    // 経由駅を1つ削除すると、その駅に対応する路線を削除
    if (viaIndex + 1 < route.selectedLineNames.length) {
      route.selectedLineNames.removeAt(viaIndex + 1);
    }
  }

  List<String> getAvailableLines(int segmentIndex) {
    final route = currentRoute;
    // 範囲チェック
    if (segmentIndex < 0 || segmentIndex >= route.selectedLineNames.length) {
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
    if (segmentIndex == route.selectedLineNames.length - 1) {
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
  void selectLine(int segmentIndex, String? lineName) {
    final route = currentRoute;
    if (segmentIndex < 0 || segmentIndex >= route.selectedLineNames.length) {
      return;
    }

    route.selectedLineNames[segmentIndex] = lineName;
  }

  // ============================================================
  // ルートをTransitRouteへ変換
  // ============================================================
  TransitRoute compileRoute() {
    final route = currentRoute;

    final segments = <TransitSegment>[];
    for (int i = 0; i < route.selectedLineNames.length; i++) {
      final departureStation = i == 0
          ? departureController.text.trim()
          : route.viaStationControllers[i - 1].text.trim();

      final arrivalStation = i == route.selectedLineNames.length - 1
          ? arrivalController.text.trim()
          : route.viaStationControllers[i].text.trim();

      final walkTime = i < route.walkTimeControllers.length
          ? int.tryParse(route.walkTimeControllers[i].text.trim()) ?? 0
          : 0;

      segments.add(
        TransitSegment(
          departureStation: departureStation,
          lineName: route.selectedLineNames[i] ?? '',
          duration: 15,
          arrivalStation: arrivalStation,
          walkTimeAfter: walkTime,
        ),
      );
    }

    return TransitRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: route.nameController.text.trim(),
      segments: segments,
    );
  }

  // ============================================================
  // Dispose
  // ============================================================
  void dispose() {
    departureController.dispose();
    arrivalController.dispose();
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

    if (segmentIndex < 0 || segmentIndex >= route.selectedLineNames.length) {
      return null;
    }

    return route.selectedLineNames[segmentIndex];
  }
}
