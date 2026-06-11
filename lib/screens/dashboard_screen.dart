import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'dart:async';

import 'package:girinori/models/transit_model.dart';
import 'package:girinori/widgets/line_painter.dart';
import 'package:girinori/screens/add_route_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 💡 固定の mockTimetables は削除し、動的変数として定義
  Map<String, Map<int, List<int>>> timetables = {};
  bool isLoading = true; // 読み込み状態フラグ

  // 💡 ルートの初期データもここに移動して、動的に追加できるようにする
  List<TransitRoute> myRoutes = [
    TransitRoute(
      id: "default_1",
      name: "帰宅（大手町・表参道経由）",
      segments: [
        TransitSegment(
          departureStation: "中野",
          line: "東西線",
          duration: 20,
          arrivalStation: "大手町",
          walkTimeAfter: 1,
        ),
        TransitSegment(
          departureStation: "大手町",
          line: "千代田線",
          duration: 15,
          arrivalStation: "表参道",
          walkTimeAfter: 2,
        ),
        TransitSegment(
          departureStation: "表参道",
          line: "半蔵門線",
          duration: 5,
          arrivalStation: "渋谷",
          walkTimeAfter: 0,
        ),
      ],
    ),
  ];

  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTimetables(); // 💡 起動時にJSONを読み込む

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  // 💡 JSON読み込み用の非同期関数
  Future<void> _loadTimetables() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/timetable.json',
      );
      final Map<String, dynamic> rawJson = jsonDecode(jsonString);

      Map<String, Map<int, List<int>>> cleanTimetables = {};
      rawJson.forEach((stationKey, timeData) {
        Map<int, List<int>> hourMap = {};
        if (timeData is Map) {
          timeData.forEach((hourStr, minutesList) {
            final int? hour = int.tryParse(hourStr);
            if (hour != null && minutesList is List) {
              hourMap[hour] = List<int>.from(minutesList);
            }
          });
        }
        cleanTimetables[stationKey] = hourMap;
      });

      setState(() {
        timetables = cleanTimetables;
        isLoading = false; // 読み込み完了！
      });
    } catch (e) {
      print("❌ JSON読み込みエラー: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'X-Transit',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF00E676),
              size: 28,
            ),
            onPressed: () async {
              final newRoute = await Navigator.push<TransitRoute>(
                context,
                MaterialPageRoute(builder: (context) => const AddRouteScreen()),
              );
              if (newRoute != null) {
                setState(() {
                  myRoutes.add(newRoute);
                });
              }
            },
          ),
        ],
      ),
      // 💡 読み込み中は真ん中にぐるぐるを表示する
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "現在時刻: ${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: myRoutes.length,
                      itemBuilder: (context, index) {
                        final route = myRoutes[index];

                        // 💡 モデル側の計算ロジックを呼び出す。JSONから取得した timetables を渡す！
                        final result = route.calculate(_now, timetables);

                        if (result == null) {
                          return _buildNoDataCard(route);
                        }

                        return _buildRouteCard(route, result);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // 💡 運行終了時のカードUIをまるごと外に逃がす
  Widget _buildNoDataCard(TransitRoute route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  route.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "運行終了 / データなし",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCompactStationBadge(
                    route.segments.first.departureStation,
                    isStart: true,
                  ),
                  for (int i = 0; i < route.segments.length; i++) ...[
                    _buildCompactArrowWithLine(route.segments[i].line),
                    _buildCompactStationBadge(
                      route.segments[i].arrivalStation,
                      isEnd: i == route.segments.length - 1,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(TransitRoute route, RouteResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  route.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "あと ${result.countdownMinutes} 分",
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Colors.white10),

            // ループ処理で何段階の乗り換えでも自動生成
            for (int i = 0; i < route.segments.length; i++) ...[
              _buildStationRow(
                route.segments[i].departureStation,
                result.segmentResults[i].dep,
                route.segments[i].line,
                isStart: i == 0,
              ),
              _buildTransitLine(route.segments[i].duration, isWalk: false),
              if (i < route.segments.length - 1) ...[
                _buildStationRow(
                  route.segments[i].arrivalStation,
                  result.segmentResults[i].arr,
                  "${route.segments[i + 1].line}へ乗換",
                  isTransfer: true,
                  nextDep: result.segmentResults[i + 1].dep,
                ),
                _buildTransitLine(
                  route.segments[i].walkTimeAfter,
                  isWalk: true,
                ),
              ] else ...[
                _buildStationRow(
                  route.segments[i].arrivalStation,
                  result.segmentResults[i].arr,
                  "帰宅完了！",
                  isEnd: true,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStationRow(
    String name,
    DateTime? time,
    String subtext, {
    bool isStart = false,
    bool isEnd = false,
    bool isTransfer = false,
    DateTime? nextDep,
  }) {
    String timeStr = time != null
        ? "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}"
        : "";
    String nextDepStr = nextDep != null
        ? " ➔ ${nextDep.hour.toString().padLeft(2, '0')}:${nextDep.minute.toString().padLeft(2, '0')}発"
        : "";

    return Row(
      children: [
        Icon(
          isStart
              ? Icons.radio_button_checked
              : (isEnd ? Icons.location_on : Icons.brightness_1),
          size: 20,
          color: isStart
              ? const Color(0xFF00E676)
              : (isEnd ? Colors.redAccent : const Color(0xFF00B0FF)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$name駅 $timeStr$nextDepStr",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtext.isNotEmpty)
                Text(
                  subtext,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStationBadge(
    String name, {
    bool isStart = false,
    bool isEnd = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isStart
            ? const Color(0xFF00E676).withOpacity(0.1)
            : (isEnd ? Colors.redAccent.withOpacity(0.1) : Colors.white10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isStart
              ? const Color(0xFF00E676).withOpacity(0.5)
              : (isEnd ? Colors.redAccent.withOpacity(0.5) : Colors.white24),
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isStart
              ? const Color(0xFF00E676)
              : (isEnd ? Colors.redAccent : Colors.white),
        ),
      ),
    );
  }

  Widget _buildCompactArrowWithLine(String lineName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lineName,
            style: const TextStyle(
              color: Color(0xFF00B0FF),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "➔",
            style: TextStyle(color: Colors.white30, fontSize: 16, height: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitLine(int minutes, {bool isWalk = false}) {
    return Container(
      margin: const EdgeInsets.only(left: 9),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: CustomPaint(
        painter: LinePainter(isWalk: isWalk),
        child: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            "${minutes}分",
            style: TextStyle(
              color: isWalk ? Colors.orange : Colors.grey,
              fontSize: 12,
              fontWeight: isWalk ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
