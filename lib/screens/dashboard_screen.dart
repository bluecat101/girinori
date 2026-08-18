import 'dart:convert'; // 💡 JSONパースに必要です
import 'package:flutter/services.dart'; // 💡 rootBundle（ファイル読み込み）に必要です
import 'package:flutter/material.dart';
import 'package:girinori/controllers/timetable_controller.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/screens/add_route_screen.dart';
import 'package:girinori/widgets/dashboard/station_row.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 💡 【新設計】クローラーが作った駅マスタを保持する変数
  Map<String, Map<String, List<dynamic>>> myLoadedRouteMaster = {};

  // 💡 【新設計】現在表示しているルートで使う路線の時刻表データ（trips）だけを小分けにキャッシュする場所
  // Key: "ＪＲ根岸線_大宮・南浦和方面"、 Value: その路線の trips 配列
  final Map<String, List<dynamic>> _cachedTimetables = {};

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
  }

  // 💡 【新設計】必要な路線の個別時刻表ファイル（timetable_xxx.json）をピンポイントでオンデマンド読込
  Future<void> _loadTimetableFileForLine(String lineId) async {
    // すでにロード済み（キャッシュにある）なら何もしない（メモリの節約）
    if (_cachedTimetables.containsKey(lineId)) return;

    try {
      // 禁止文字を安全に置換したファイル名を指定
      final safeFilename = lineId.replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");
      final jsonString = await rootBundle.loadString(
        'assets/timetables/$safeFilename.json',
      );
      final Map<String, dynamic> lineData = jsonDecode(jsonString);

      if (lineData.containsKey('trips')) {
        _cachedTimetables[lineId] = lineData['trips'] as List<dynamic>;
        print(
          "🚊 路線ファイルのロード成功: timetable_$safeFilename.json (${_cachedTimetables[lineId]!.length}本収容)",
        );
      }
    } catch (e) {
      print("❌ 路線ファイル [ $lineId ] のロードに失敗しました（ファイルがないかアセット未登録）: $e");
    }
  }

  void _shiftTrainCount(String routeId, int segmentIndex, bool isNext) {
    setState(() {
      final key = "${routeId}_$segmentIndex";
      final currentShift = _segmentShiftCounts[key] ?? 0;

      // 次へなら+1、前へなら-1
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
          : _buildRoutePageView(),
    );
  }

  Widget _buildRouteTimelineCard(TransitRoute route) {
    final baseTime = _routeBaseTimes[route.id] ?? TimeOfDay.now();
    List<TimeOfDay> departureTimes = [];
    List<TimeOfDay> arrivalTimes = [];
    TimeOfDay runningTime = baseTime;

    for (int i = 0; i < route.segments.length; i++) {
      final segment = route.segments[i];
      // この区間のシフト数のキーを作成して取得する
      final shiftKey = '${route.id}_$i';
      final shiftCount = _segmentShiftCounts[shiftKey] ?? 0;
      final (dep, arr) = _timetableController.findNextTrainTimes(
        lineId: segment.line,
        departureStation: segment.departureStation,
        arrivalStation: segment.arrivalStation,
        baseTime: baseTime,
        shiftCount: shiftCount,
      );

      departureTimes.add(dep);
      arrivalTimes.add(arr); // 💡 これで「1229」がそのまま格納されます！

      // 次の乗り換えがある場合は、本物の到着時刻に徒歩時間を足す
      runningTime = _timetableController.addMinutes(arr, segment.walkTimeAfter);
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              route.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${_timetableController.formatTime(arrivalTimes.last)} 着",
              style: const TextStyle(
                color: Color(0xFF00E676),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(color: Colors.white10, height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < route.segments.length; i++) ...[
                      DashboardStationRow(
                        routeId: route.id,
                        segmentIndex: i,
                        stationName: route.segments[i].departureStation,
                        arrivalTime: i == 0 ? null : arrivalTimes[i - 1],
                        departureTime: departureTimes[i],
                        segment: route.segments[i],
                        isStart: i == 0,
                        isEnd: false,
                        shiftCount: _segmentShiftCounts['${route.id}_$i'] ?? 0,
                        onShiftTrain: (forward) {
                          setState(() {
                            _shiftTrainCount(route.id, i, forward);
                          });
                        },
                      ),
                      _buildLineRow(route.segments[i].line),
                    ],
                    DashboardStationRow(
                      routeId: route.id,
                      segmentIndex: route.segments.length,
                      stationName: route.segments.last.arrivalStation,
                      arrivalTime: arrivalTimes.last,
                      departureTime: null,
                      segment: route.segments.last,
                      isStart: false,
                      isEnd: true,
                      // 到着駅には列車変更ボタンがない
                      shiftCount: 0,
                      onShiftTrain: null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        await _loadTimetableFileForLine(segment.line);
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
    _pageController.animateToPage(
      myRoutes.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
        await _loadTimetableFileForLine(segment.line);
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

  Widget _buildRoutePageView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: PageView.builder(
        controller: _pageController,
        itemCount: myRoutes.length,
        padEnds: false,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 4.0),
            child: GestureDetector(
              onTap: () => _editRoute(index),
              child: _buildRouteTimelineCard(myRoutes[index]),
            ),
          );
        },
      ),
    );
  }

  // --- ➔ 路線要素（スリム化） ---
  Widget _buildLineRow(String lineName) {
    // 💡 画面表示用に prefix（ＪＲ根岸線_大宮・南浦和方面）から路線名だけを切り出す
    final cleanName = lineName.split('_')[0];

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6.0),
          child: Container(
            width: 1,
            height: 16,
            color: const Color(0xFF00B0FF).withOpacity(0.5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            cleanName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF00B0FF),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
