import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const MyTransitApp());
}

class MyTransitApp extends StatelessWidget {
  const MyTransitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SokuKita',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121214),
        cardColor: const Color(0xFF1E1E24),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676), // ネオングリーン
          secondary: Color(0xFF00B0FF), // ネオンブルー
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

// --- 時刻表データ（テスト用に様々な駅を拡充） ---
const Map<String, Map<int, List<int>>> mockTimetables = {
  "中野駅_東西線": {
    7: [3, 10, 18, 25, 33, 40, 48, 55],
    8: [2, 9, 15, 22, 30, 38, 45, 52],
    16: [5, 15, 25, 35, 45, 55],
    17: [5, 15, 25, 35, 45, 55],
    23: [1, 11, 21, 32, 45, 58],
  },
  "大手町駅_千代田線": {
    7: [1, 7, 13, 20, 27, 34, 41, 48, 55],
    8: [2, 9, 16, 23, 30, 37, 44, 51, 58],
    16: [3, 13, 23, 33, 43, 53],
    17: [3, 13, 23, 33, 43, 53],
    23: [4, 14, 25, 37, 50],
  },
  "表参道駅_半蔵門線": {
    7: [5, 15, 25, 35, 45, 55],
    8: [5, 15, 25, 35, 45, 55],
    16: [0, 10, 20, 30, 40, 50],
    17: [0, 10, 20, 30, 40, 50],
  },
  "渋谷駅_山手線": {
    16: [2, 12, 22, 32, 42, 52],
    17: [2, 12, 22, 32, 42, 52],
  },
};

// --- [新設計] 1つの区間（電車に乗る区間）のデータモデル ---
class TransitSegment {
  String line; // 路線名
  String departureStation; // 出発（乗車）駅
  int duration; // 乗車時間（分）
  String arrivalStation; // 到着（降車）駅
  int walkTimeAfter; // 降車後、次の路線への徒歩乗り換え時間（分）。最後の区間は0

  TransitSegment({
    required this.line,
    required this.departureStation,
    required this.duration,
    required this.arrivalStation,
    this.walkTimeAfter = 0,
  });
}

// --- ルートのデータモデル（セグメントの配列を持つ） ---
class TransitRoute {
  final String id;
  final String name;
  final List<TransitSegment> segments; // ここを配列にすることで何回乗り換えでも対応

  TransitRoute({required this.id, required this.name, required this.segments});
}

// --- 計算結果用のモデル ---
class SegmentResult {
  final DateTime dep;
  final DateTime arr;
  SegmentResult({required this.dep, required this.arr});
}

class RouteResult {
  final List<SegmentResult> segmentResults;
  final int countdownMinutes;
  RouteResult({required this.segmentResults, required this.countdownMinutes});
}

// --- ダッシュボード画面 ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 初期データとして「2回乗り換え（3路線）」のルートを登録
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
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // --- 動的パイプライン計算ロジック ---
  RouteResult? _calculateRoute(TransitRoute route) {
    List<SegmentResult> results = [];
    DateTime searchTime = _now;
    int countdown = 0;

    for (int i = 0; i < route.segments.length; i++) {
      final seg = route.segments[i];
      final timetable = mockTimetables["${seg.departureStation}駅_${seg.line}"];
      if (timetable == null) return null; // 時刻表がない場合は計算不能

      DateTime? depTime;
      // searchTime以降の直近の電車を検索
      for (int h = searchTime.hour; h < 24; h++) {
        if (timetable.containsKey(h)) {
          for (int m in timetable[h]!) {
            final target = DateTime(_now.year, _now.month, _now.day, h, m);
            if (target.isAfter(searchTime) ||
                target.isAtSameMomentAs(searchTime)) {
              depTime = target;
              break;
            }
          }
        }
        if (depTime != null) break;
      }

      if (depTime == null) return null;

      final arrTime = depTime.add(Duration(minutes: seg.duration));
      results.add(SegmentResult(dep: depTime, arr: arrTime));

      // 最初の路線の出発までの時間をカウントダウンとする
      if (i == 0) {
        countdown = depTime.difference(_now).inMinutes;
      }

      // 次の路線の検索開始時刻 = 今の路線の到着時刻 + 徒歩乗り換え時間
      searchTime = arrTime.add(Duration(minutes: seg.walkTimeAfter));
    }

    return RouteResult(segmentResults: results, countdownMinutes: countdown);
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
      body: Padding(
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
                  final result = _calculateRoute(route);

                  // ⬇️ 16行目の「if (result == null)」からここを差し替えました！
                  if (result == null) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                        ), // 薄い赤枠
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

                            // 横型のマイルート概要表示 (A => B => C)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildCompactStationBadge(
                                    route.segments.first.departureStation,
                                    isStart: true,
                                  ),
                                  for (
                                    int i = 0;
                                    i < route.segments.length;
                                    i++
                                  ) ...[
                                    _buildCompactArrowWithLine(
                                      route.segments[i].line,
                                    ),
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
                  // ⬆️ 差し替えコピペはここまでです！

                  // ここから下は通常のルート表示（既存のまま）
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
                                  color: const Color(
                                    0xFF00E676,
                                  ).withOpacity(0.1),
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
                            _buildTransitLine(
                              route.segments[i].duration,
                              isWalk: false,
                            ),
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
                  ); // Containerの閉じ忘れに注意
                },
              ),
            ),
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

  // 運行終了時用のコンパクトな駅バッジ
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

  // 「=>」の上に路線名を表示するスタイリッシュな矢印パーツ
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
        painter: _LinePainter(isWalk: isWalk),
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

// --- ルートの新規登録画面（動的追加対応） ---
// --- 直感的なステップ型・ルートの新規登録画面 ---
class AddRouteScreen extends StatefulWidget {
  const AddRouteScreen({super.key});

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: "マイ即帰宅ルート");

  // 各ポイントの駅名と路線のコントローラー
  final _startStationController = TextEditingController(text: "中野");
  final _firstLineController = TextEditingController(text: "東西线");
  final _firstDurationController = TextEditingController(text: "20");

  // 2回目以降の乗り換えを管理するリスト
  // 各要素: { "station": 乗換駅/経由地, "line": 次の路線, "duration": 次の乗車時間, "walk": ここでの徒歩乗換時間 }
  final List<Map<String, TextEditingController>> _transferSteps = [];

  final _endStationController = TextEditingController(text: "表参道");

  @override
  void initState() {
    super.initState();
    // デフォルトで1回乗り換え（中継1つ）の状態を作っておく
    _addTransferStepFields("大手町", "千代田線", "15", "1");
  }

  void _addTransferStepFields([
    String station = "",
    String line = "",
    String dur = "",
    String walk = "1",
  ]) {
    setState(() {
      _transferSteps.add({
        "station": TextEditingController(text: station),
        "line": TextEditingController(text: line),
        "duration": TextEditingController(text: dur),
        "walk": TextEditingController(text: walk),
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startStationController.dispose();
    _firstLineController.dispose();
    _firstDurationController.dispose();
    _endStationController.dispose();
    for (var step in _transferSteps) {
      step.values.forEach((c) => c.dispose());
    }
    super.dispose();
  }

  // 入力値からリアルタイムに現在のルート構成（TransitSegmentのリスト）を組み立てる
  List<TransitSegment> _compileSegments() {
    List<TransitSegment> segments = [];

    if (_transferSteps.isEmpty) {
      // 乗り換えなし（直通）の場合
      segments.add(
        TransitSegment(
          departureStation: _startStationController.text,
          line: _firstLineController.text,
          duration: int.tryParse(_firstDurationController.text) ?? 0,
          arrivalStation: _endStationController.text,
          walkTimeAfter: 0,
        ),
      );
    } else {
      // 1本目の路線（出発地 ➔ 最初の乗換駅）
      segments.add(
        TransitSegment(
          departureStation: _startStationController.text,
          line: _firstLineController.text,
          duration: int.tryParse(_firstDurationController.text) ?? 0,
          arrivalStation: _transferSteps.first["station"]!.text,
          walkTimeAfter: int.tryParse(_transferSteps.first["walk"]!.text) ?? 0,
        ),
      );

      // 中継路線のループ
      for (int i = 0; i < _transferSteps.length; i++) {
        final currentStep = _transferSteps[i];
        final isLast = i == _transferSteps.length - 1;

        segments.add(
          TransitSegment(
            departureStation: currentStep["station"]!.text,
            line: currentStep["line"]!.text,
            duration: int.tryParse(currentStep["duration"]!.text) ?? 0,
            arrivalStation: isLast
                ? _endStationController.text
                : _transferSteps[i + 1]["station"]!.text,
            walkTimeAfter: isLast
                ? 0
                : (int.tryParse(_transferSteps[i + 1]["walk"]!.text) ?? 0),
          ),
        );
      }
    }
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final currentSegments = _compileSegments();

    return Scaffold(
      appBar: AppBar(
        title: const Text('即帰宅ルートの登録'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputField(
                      _nameController,
                      "ルート名",
                      "例: 平日帰宅ルート",
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle("1. 出発のベース設定"),
                    Card(
                      color: const Color(0xFF1E1E24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildInputField(
                              _startStationController,
                              "出発駅",
                              "例: 中野",
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    _firstLineController,
                                    "初めに使う路線",
                                    "例: 東西線",
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInputField(
                                    _firstDurationController,
                                    "乗車時間 (分)",
                                    "例: 20",
                                    isNumber: true,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle("2. 乗り換え経由地の追加"),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transferSteps.length,
                      itemBuilder: (context, index) {
                        final step = _transferSteps[index];
                        return Card(
                          color: const Color(0xFF22222A),
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "乗り換え ➔ 第 ${index + 1} 経由地",
                                      style: const TextStyle(
                                        color: Color(0xFF00B0FF),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => setState(
                                        () => _transferSteps.removeAt(index),
                                      ),
                                    ),
                                  ],
                                ),
                                _buildInputField(
                                  step["station"]!.text.isEmpty
                                      ? TextEditingController(
                                          text: "${index + 1}つ目の乗換駅",
                                        )
                                      : step["station"]!,
                                  "経由駅（乗換駅）",
                                  "例: 大手町",
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInputField(
                                        step["line"]!,
                                        "次に乗る路線",
                                        "例: 千代田線",
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInputField(
                                        step["duration"]!,
                                        "乗車時間 (分)",
                                        "例: 15",
                                        isNumber: true,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildInputField(
                                  step["walk"]!,
                                  "この駅での徒歩乗り換え時間 (分)",
                                  "例: 1",
                                  isNumber: true,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00B0FF),
                        side: const BorderSide(color: Color(0xFF00B0FF)),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _addTransferStepFields(),
                      icon: const Icon(Icons.add_location_alt),
                      label: const Text("さらに乗り換え（経由地）を追加"),
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle("3. 最終目的地"),
                    _buildInputField(
                      _endStationController,
                      "目的地（帰宅駅）",
                      "例: 渋谷",
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // --- 【新設】一番下のリアルタイム完成予想図（Preview View） ---
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E24),
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 1),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "👀 ルート完成予想図 (プレビュー)",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPreviewStation(
                            currentSegments.first.departureStation,
                            isStart: true,
                          ),
                          for (int i = 0; i < currentSegments.length; i++) ...[
                            _buildPreviewLine(
                              currentSegments[i].line,
                              currentSegments[i].duration,
                            ),
                            if (i < currentSegments.length - 1) ...[
                              _buildPreviewStation(
                                currentSegments[i].arrivalStation,
                              ),
                              _buildPreviewWalk(
                                currentSegments[i].walkTimeAfter,
                              ),
                            ] else ...[
                              _buildPreviewStation(
                                currentSegments[i].arrivalStation,
                                isEnd: true,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(
                            context,
                            TransitRoute(
                              id: DateTime.now().toString(),
                              name: _nameController.text,
                              segments: _compileSegments(),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        "このパイプラインを確定保存",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isNumber = false,
    TextEditingController? controllerOverride,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controllerOverride ?? controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF121214),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      validator: (value) => (value == null || value.isEmpty) ? '入力必須' : null,
    );
  }

  // --- プレビュー用UIコンポーネント群 ---
  Widget _buildPreviewStation(
    String name, {
    bool isStart = false,
    bool isEnd = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isStart
            ? const Color(0xFF00E676).withOpacity(0.2)
            : (isEnd ? Colors.redAccent.withOpacity(0.2) : Colors.white10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isStart
              ? const Color(0xFF00E676)
              : (isEnd ? Colors.redAccent : Colors.white24),
        ),
      ),
      child: Text(
        name.isEmpty ? "駅名" : name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isStart
              ? const Color(0xFF00E676)
              : (isEnd ? Colors.redAccent : Colors.white),
        ),
      ),
    );
  }

  Widget _buildPreviewLine(String name, int duration) {
    return Row(
      children: [
        Container(width: 16, height: 2, color: const Color(0xFF00B0FF)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF00B0FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            "${name.isEmpty ? '路線' : name} (${duration}分)",
            style: const TextStyle(color: Color(0xFF00B0FF), fontSize: 11),
          ),
        ),
        Container(width: 16, height: 2, color: const Color(0xFF00B0FF)),
      ],
    );
  }

  Widget _buildPreviewWalk(int minutes) {
    return Row(
      children: [
        const Text(" ➔ ", style: TextStyle(color: Colors.orange)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            "🚶 $minutes分",
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Text(" ➔ ", style: TextStyle(color: Colors.orange)),
      ],
    );
  }
}

// 縦の破線を描画するクラス（既存）
class _LinePainter extends CustomPainter {
  final bool isWalk;
  _LinePainter({required this.isWalk});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isWalk ? Colors.orange : const Color(0xFF00B0FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (!isWalk) {
      canvas.drawLine(const Offset(0, -10), Offset(0, size.height + 10), paint);
    } else {
      double dashHeight = 4, dashSpace = 4, startY = -10;
      while (startY < size.height + 10) {
        canvas.drawLine(
          Offset(0, startY),
          Offset(0, startY + dashHeight),
          paint,
        );
        startY += dashHeight + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
