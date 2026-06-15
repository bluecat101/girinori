import 'package:flutter/material.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/screens/add_route_screen.dart';

// 擬似的な時刻表データ
final Map<String, Map<int, List<int>>> mockTimetables = {
  "中野駅_東西線": {
    18: [0, 10, 20, 30, 40, 50],
    19: [0, 10, 20, 30, 40, 50],
  },
  "大手町駅_千代田線": {
    18: [5, 18, 30, 42, 55],
    19: [5, 18, 30, 42, 55],
  },
  "表参道駅_半蔵門線": {
    18: [3, 13, 23, 33, 43, 53],
    19: [3, 13, 23, 33, 43, 53],
  },
};

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 💡 見え方をテストしやすいようにルートを3つに用意
  List<TransitRoute> myRoutes = [
    TransitRoute(
      id: "route_1",
      name: "大手町経由",
      segments: [
        TransitSegment(
          departureStation: "中野",
          line: "東西線",
          duration: 20,
          arrivalStation: "大手町",
          walkTimeAfter: 3,
        ),
        TransitSegment(
          departureStation: "大手町",
          line: "千代田線",
          duration: 15,
          arrivalStation: "表参道",
          walkTimeAfter: 0,
        ),
      ],
    ),
    TransitRoute(
      id: "route_2",
      name: "直行バス",
      segments: [
        TransitSegment(
          departureStation: "中野",
          line: "東西線",
          duration: 35,
          arrivalStation: "表参道",
          walkTimeAfter: 0,
        ),
      ],
    ),
    TransitRoute(
      id: "route_3",
      name: "新宿経由",
      segments: [
        TransitSegment(
          departureStation: "中野",
          line: "中央線",
          duration: 5,
          arrivalStation: "新宿",
          walkTimeAfter: 5,
        ),
        TransitSegment(
          departureStation: "新宿",
          line: "山手線",
          duration: 15,
          arrivalStation: "渋谷",
          walkTimeAfter: 0,
        ),
      ],
    ),
  ];

  final Map<String, TimeOfDay> _routeBaseTimes = {};

  // 💡 2個しっかりと表示され、3個目が少し見切れる魔法の比率 (43%)
  final PageController _pageController = PageController(viewportFraction: 0.43);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    for (var route in myRoutes) {
      _routeBaseTimes[route.id] = TimeOfDay(hour: now.hour, minute: now.minute);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  TimeOfDay _findNextTrain(
    String station,
    String line,
    TimeOfDay baseTime, {
    bool isPrevious = false,
  }) {
    final key = "${station}駅_$line";
    final table = mockTimetables[key];
    if (table == null) return baseTime;

    List<TimeOfDay> allTrains = [];
    table.forEach((hour, minutes) {
      for (var min in minutes) {
        allTrains.add(TimeOfDay(hour: hour, minute: min));
      }
    });
    allTrains.sort(
      (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
    );
    final baseTotal = baseTime.hour * 60 + baseTime.minute;

    if (isPrevious) {
      final prevTrains = allTrains
          .where((t) => (t.hour * 60 + t.minute) < baseTotal)
          .toList();
      return prevTrains.isNotEmpty ? prevTrains.last : baseTime;
    } else {
      final nextTrains = allTrains
          .where((t) => (t.hour * 60 + t.minute) >= baseTotal)
          .toList();
      return nextTrains.isNotEmpty ? nextTrains.first : baseTime;
    }
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  void _shiftRouteTime(
    String routeId,
    TransitSegment segment, {
    required bool isNext,
  }) {
    setState(() {
      final currentTime = _routeBaseTimes[routeId] ?? TimeOfDay.now();
      final targetTrain = _findNextTrain(
        segment.departureStation,
        segment.line,
        isNext ? _addMinutes(currentTime, 1) : currentTime,
        isPrevious: !isNext,
      );
      _routeBaseTimes[routeId] = targetTrain;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
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
            onPressed: () async {
              final newRoute = await Navigator.push<TransitRoute>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddRouteScreen(timetables: mockTimetables),
                ),
              );
              if (newRoute != null) {
                setState(() {
                  myRoutes.add(newRoute);
                  final now = DateTime.now();
                  _routeBaseTimes[newRoute.id] = TimeOfDay(
                    hour: now.hour,
                    minute: now.minute,
                  );
                });
                _pageController.animateToPage(
                  myRoutes.length - 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            },
          ),
        ],
      ),
      body: myRoutes.isEmpty
          ? const Center(
              child: Text(
                "登録されたルートがありません",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: PageView.builder(
                controller: _pageController,
                itemCount: myRoutes.length,
                padEnds: false, // 💡 左端に寄せることで、右側に見切れを作る
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: 12.0,
                      top: 4.0,
                      bottom: 4.0,
                    ),
                    child: _buildRouteTimelineCard(myRoutes[index]),
                  );
                },
              ),
            ),
    );
  }

  // --- 📦 横幅が狭いスリムカード ---
  Widget _buildRouteTimelineCard(TransitRoute route) {
    final baseTime = _routeBaseTimes[route.id] ?? TimeOfDay.now();
    List<TimeOfDay> departureTimes = [];
    List<TimeOfDay> arrivalTimes = [];
    TimeOfDay runningTime = baseTime;

    for (int i = 0; i < route.segments.length; i++) {
      final seg = route.segments[i];
      final dep = _findNextTrain(seg.departureStation, seg.line, runningTime);
      departureTimes.add(dep);
      final arr = _addMinutes(dep, seg.duration);
      arrivalTimes.add(arr);
      runningTime = _addMinutes(arr, seg.walkTimeAfter);
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
            // ルート名
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
            // 最速到着時間
            Text(
              "${_formatTime(arrivalTimes.last)} 着",
              style: const TextStyle(
                color: Color(0xFF00E676),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(color: Colors.white10, height: 16),

            // タイムライン本体
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < route.segments.length; i++) ...[
                      // ⭕️ 1箇所目：出発駅・経由駅の呼び出し
                      _buildStationRow(
                        routeId: route.id,
                        stationName: route.segments[i].departureStation,
                        arrivalTime: i == 0
                            ? null
                            : arrivalTimes[i - 1], // 前の区間の到着時間
                        departureTime: departureTimes[i], // この区間の出発時間
                        segment: route.segments[i],
                        isStart: i == 0,
                        isEnd: false,
                      ),
                      _buildLineRow(route.segments[i].line),
                    ],
                    // ⭕️ 2箇所目：最終到着駅の呼び出し
                    _buildStationRow(
                      routeId: route.id,
                      stationName: route.segments.last.arrivalStation,
                      arrivalTime: arrivalTimes.last, // 最終到着時間
                      departureTime: null, // 到着駅なので出発時間はなし
                      segment: route.segments.last,
                      isStart: false,
                      isEnd: true,
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

  // --- 🚉 縦並び駅要素（幅150px前後に耐えるスリム設計） ---
  // --- 🚉 縦並び駅要素（到着時間を上に配置した新レイアウト） ---
  // --- 🚉 縦並び駅要素（「着 ➔ 駅名 ➔ 発」の3段レイアウト） ---
  Widget _buildStationRow({
    required String routeId,
    required String stationName,
    required TimeOfDay? arrivalTime,
    required TimeOfDay? departureTime,
    required TransitSegment segment,
    required bool isStart,
    required bool isEnd,
  }) {
    Color nodeColor = isStart
        ? const Color(0xFF00E676)
        : (isEnd ? Colors.redAccent : const Color(0xFF00B0FF));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ピン
        Icon(
          isStart
              ? Icons.radio_button_checked
              : (isEnd ? Icons.location_on : Icons.brightness_1),
          color: nodeColor,
          size: 14,
        ),
        const SizedBox(width: 8),

        // 💡 中央：上から「着」➔「駅名」➔「発」の3段コンポーネント
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 上段：到着時間（出発地以外に表示）
              if (arrivalTime != null)
                Text(
                  "${_formatTime(arrivalTime)}着",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),

              const SizedBox(height: 1),

              // 2. 中段：駅名
              Text(
                stationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isEnd ? Colors.redAccent : Colors.white,
                ),
              ),

              const SizedBox(height: 1),

              // 3. 下段：出発時間（目的地以外に表示）
              if (departureTime != null)
                Text(
                  "${_formatTime(departureTime)}発",
                  style: TextStyle(
                    color: isStart
                        ? const Color(0xFF00E676)
                        : const Color(0xFF00B0FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),

        // 最右翼：時刻シフトボタン（出発地と経由地のみ）
        if (!isEnd)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_left,
                  color: Colors.white38,
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () =>
                    _shiftRouteTime(routeId, segment, isNext: false),
              ),
              IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_right,
                  color: Colors.white38,
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () =>
                    _shiftRouteTime(routeId, segment, isNext: true),
              ),
            ],
          ),
      ],
    );
  }

  // --- ➔ 路線要素（スリム化） ---
  Widget _buildLineRow(String lineName) {
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
            lineName,
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
