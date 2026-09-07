import 'package:flutter/services.dart'; // 💡 rootBundle（ファイル読み込み）に必要です
import 'package:flutter/material.dart';
import 'package:girinori/controllers/timetable_controller.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/screens/add_route_screen.dart';
import 'package:girinori/services/widget_service.dart';
import 'package:girinori/widgets/dashboard/route_page_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 💡 【新設計】クローラーが作った駅マスタを保持する変数
  Map<String, Map<String, List<dynamic>>> myLoadedRouteMaster = {};

  bool _isLoading = true; // 駅マスタと初期ルートのファイル読み込み管理フラグ

  // 💡 Widgetに表示するルートIDを保持する変数
  String? widgetRouteId;

  // 💡 ユーザーが登録したルートのリスト（prefixがクローラー仕様の日本語になっています）
  List<TransitRoute> myRoutes = [];

  final Map<String, TimeOfDay> _routeBaseTimes = {};
  // どのルートのどの区間が何本シフトしているかを保存するマップ
  // Key: "ルートID_区間インデックス" (例: "route_1_0")、 Value: シフト数 (-1や2など)
  final Map<String, int> _segmentShiftCounts = {};
  final PageController _pageController = PageController(viewportFraction: 0.43);

  final TimetableController _timetableController = TimetableController();
  final now = DateTime.now();
  @override
  void initState() {
    super.initState();
    // 起動時にまず駅マスタと、初期ルートに必要な時刻表ファイルを一括ロードする
    _initializeData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _timetableController.loadRouteMasterFile();
    await _timetableController.loadTimetableIndex();
    for (final route in myRoutes) {
      for (final segment in route.segments) {
        if (segment.lineName.isNotEmpty) {
          await _timetableController.loadTimetableFileFormLineName(
            segment.lineName,
          );
        }
      }
    }
    for (final route in myRoutes) {
      _routeBaseTimes[route.id] = TimeOfDay.fromDateTime(now);
    }
    setState(() {
      myLoadedRouteMaster = _timetableController.routeMaster;

      _isLoading = false;
    });
  }

  void _shiftTrainCount(String routeId, int segmentIndex, bool isNext) {
    setState(() {
      final key = "${routeId}_$segmentIndex";
      final currentShift = _segmentShiftCounts[key] ?? 0;

      _segmentShiftCounts[key] = isNext ? currentShift + 1 : currentShift - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121214),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: _buildAppBar(),
      body: myRoutes.isEmpty
          ? const Center(
              child: Text(
                '登録されたルートがありません',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RoutePageView(
              routes: myRoutes,
              routeBaseTimes: _routeBaseTimes,
              segmentShiftCounts: _segmentShiftCounts,
              pageController: _pageController,
              timetableController: _timetableController,
              onRouteMenu: _showRouteMenu,
              onShiftTrain: _shiftTrainCount,
              widgetRouteId: widgetRouteId,
            ),
    );
  }

  void _showRouteMenu(BuildContext context, int index, bool isWidgetRoute) {
    final route = myRoutes[index];

    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 200, 100, 200),
      items: [
        PopupMenuItem(value: 'edit', child: const Text('編集')),
        PopupMenuItem(value: 'delete', child: const Text('削除')),
        PopupMenuItem(
          value: 'widget',
          child: Text(isWidgetRoute ? 'Widgetに非表示' : 'Widgetに表示'),
        ),
      ],
    ).then((value) {
      switch (value) {
        case 'edit':
          _editRoute(index);
          break;
        case 'delete':
          _deleteRoute(route);
          break;
        case 'widget':
          _setWidgetRoute(route);
          break;
      }
    });
  }

  Future<void> _addRoute() async {
    final newRoute = await Navigator.push<TransitRoute>(
      context,
      MaterialPageRoute(
        builder: (context) => AddRouteScreen(routeMaster: myLoadedRouteMaster),
      ),
    );
    if (newRoute == null) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    for (final segment in newRoute.segments) {
      if (segment.lineName.isNotEmpty) {
        await _timetableController.loadTimetableFileFormLineName(
          segment.lineName,
        );
      }
    }
    setState(() {
      myRoutes.add(newRoute);
      _routeBaseTimes[newRoute.id] = TimeOfDay.fromDateTime(now);
      _isLoading = false;
    });
    // widgetを更新
    await _updateWidgetForRoute();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          myRoutes.length - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _editRoute(int index) async {
    final updatedRoute = await Navigator.push<TransitRoute>(
      context,
      MaterialPageRoute(
        builder: (context) => AddRouteScreen(
          routeMaster: myLoadedRouteMaster,
          editingRoute: myRoutes[index],
        ),
      ),
    );
    if (updatedRoute == null) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    for (final segment in updatedRoute.segments) {
      if (segment.lineName.isNotEmpty) {
        await _timetableController.loadTimetableFileFormLineName(
          segment.lineName,
        );
      }
    }
    setState(() {
      myRoutes[index] = updatedRoute;

      _isLoading = false;
    });
    await _updateWidgetForRoute();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        '即帰宅パイプライン',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.add_circle_outline,
            color: Color(0xFF00E676),
            size: 26,
          ),
          onPressed: _addRoute,
        ),
      ],
    );
  }

  Future<void> _deleteRoute(TransitRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ルートを削除'),
          content: Text('「${route.name}」を削除しますか？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      myRoutes.removeWhere((item) => item.id == route.id);
    });
  }

  Future<void> _setWidgetRoute(TransitRoute route) async {
    setState(() {
      if (route.id == widgetRouteId) {
        widgetRouteId = null; // すでにWidgetに表示されている場合は非表示にする
      } else {
        widgetRouteId = route.id; // Widgetに表示するルートを設定
      }
    });

    await _updateWidgetForRoute();
  }

  Future<void> _updateWidgetForRoute() async {
    final TransitRoute route;
    final noRoutesMessage = 'ルートを指定してください。';
    if (myRoutes.isEmpty) {
      await WidgetService.update(route: noRoutesMessage, stations: []);
      return;
    }

    if (widgetRouteId == null) {
      route = myRoutes.first;
    } else {
      route = myRoutes.firstWhere(
        (route) => route.id == widgetRouteId,
        orElse: () => myRoutes.first,
      );
    }

    if (route.segments.isEmpty) {
      await WidgetService.update(route: noRoutesMessage, stations: []);
      return;
    }

    final result = _fetchAllDepArrTimes(route.segments, _timetableController);

    final stations = <WidgetStation>[];

    for (int i = 0; i < route.segments.length; i++) {
      final segment = route.segments[i];
      final segmentResult = result[i];

      // 最初の駅
      if (i == 0) {
        stations.add(
          WidgetStation(
            station: segment.departureStation,
            departure: segmentResult.dep,
          ),
        );
      }

      // 到着駅
      stations.add(
        WidgetStation(
          station: segment.arrivalStation,
          arrival: segmentResult.arr,
        ),
      );

      // 次の区間がある場合、この駅は乗換駅なので出発時刻も設定
      if (i < route.segments.length - 1) {
        final nextResult = result[i + 1];

        stations[stations.length - 1] = WidgetStation(
          station: segment.arrivalStation,
          arrival: segmentResult.arr,
          departure: nextResult.dep,
        );
      }
    }

    await WidgetService.update(
      route:
          '${route.segments.first.departureStation} → '
          '${route.segments.last.arrivalStation}',
      stations: stations,
    );
  }

  List<SegmentResult> _fetchAllDepArrTimes(
    List<TransitSegment> segments,
    TimetableController timetableController,
  ) {
    final results = <SegmentResult>[];
    TimeOfDay baseTime = TimeOfDay.fromDateTime(now);

    for (final segment in segments) {
      final (dep, arr) = timetableController.findNextTrainTimesByLineName(
        lineName: segment.lineName,
        departureStation: segment.departureStation,
        arrivalStation: segment.arrivalStation,
        baseTime: baseTime,
        shiftCount: 0,
      );
      results.add(SegmentResult(dep: dep, arr: arr));

      // 次の区間は「到着＋徒歩時間」から検索
      baseTime = timetableController.addMinutes(arr, segment.walkTimeAfter);
    }

    return results;
  }
}
