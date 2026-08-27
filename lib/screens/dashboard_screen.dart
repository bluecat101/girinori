import 'package:flutter/services.dart'; // 💡 rootBundle（ファイル読み込み）に必要です
import 'package:flutter/material.dart';
import 'package:girinori/controllers/timetable_controller.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/screens/add_route_screen.dart';
import 'package:girinori/services/widget_service.dart';
import 'package:girinori/utils/format_time.dart';
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

  // 💡 ユーザーが登録したルートのリスト（prefixがクローラー仕様の日本語になっています）
  List<TransitRoute> myRoutes = [
    TransitRoute(
      id: "route_1",
      name: "根岸線・大宮方面",
      segments: [
        TransitSegment(
          departureStation: "大船",
          line: "ＪＲ根岸線_大宮・南浦和方面", // 👈 クローラーのprefix（ファイル名）と完全一致させる
          duration: 15,
          arrivalStation: "磯子",
          walkTimeAfter: 0,
        ),
      ],
    ),
  ];

  final Map<String, TimeOfDay> _routeBaseTimes = {};
  // どのルートのどの区間が何本シフトしているかを保存するマップ
  // Key: "ルートID_区間インデックス" (例: "route_1_0")、 Value: シフト数 (-1や2など)
  final Map<String, int> _segmentShiftCounts = {};
  final PageController _pageController = PageController(viewportFraction: 0.43);

  final TimetableController _timetableController = TimetableController();
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
        if (segment.line.isNotEmpty) {
          await _timetableController.loadTimetableFileForLine(segment.line);
        }
      }
    }
    final now = DateTime.now();
    for (final route in myRoutes) {
      _routeBaseTimes[route.id] = TimeOfDay(hour: now.hour, minute: now.minute);
    }
    setState(() {
      myLoadedRouteMaster = _timetableController.routeMaster;

      _isLoading = false;
    });
    await WidgetService.update(
      route: '横浜 → 桜木町',
      departure: formatTime(TimeOfDay.now()),
      arrival: formatTime(TimeOfDay.now()),
    );
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
              onEditRoute: _editRoute,
              onShiftTrain: _shiftTrainCount,
            ),
    );
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
      if (segment.line.isNotEmpty) {
        await _timetableController.loadTimetableFileForLine(segment.line);
      }
    }
    final now = DateTime.now();
    setState(() {
      myRoutes.add(newRoute);
      _routeBaseTimes[newRoute.id] = TimeOfDay(
        hour: now.hour,
        minute: now.minute,
      );
      _isLoading = false;
    });
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
      if (segment.line.isNotEmpty) {
        await _timetableController.loadTimetableFileForLine(segment.line);
      }
    }
    setState(() {
      myRoutes[index] = updatedRoute;

      _isLoading = false;
    });
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
}
