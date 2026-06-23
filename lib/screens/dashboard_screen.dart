import 'dart:convert'; // 💡 JSONパースに必要です
import 'package:flutter/services.dart'; // 💡 rootBundle（ファイル読み込み）に必要です
import 'package:flutter/material.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/screens/add_route_screen.dart';

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

  // 💡 【新設計】初期化処理：マスタを読んだあと、初期ルートの時刻表もまとめてロード
  Future<void> _initializeData() async {
    await _loadRouteMasterFile();

    // 現在登録されているルートが使用する路線ファイルをすべて先読みする
    for (var route in myRoutes) {
      for (var segment in route.segments) {
        if (segment.line.isNotEmpty) {
          await _loadTimetableFileForLine(segment.line);
        }
      }
    }

    // 基準時刻を現在時刻に初期化
    final now = DateTime.now();
    for (var route in myRoutes) {
      _routeBaseTimes[route.id] = TimeOfDay(hour: now.hour, minute: now.minute);
    }

    setState(() {
      _isLoading = false; // すべての準備が完了！
    });
  }

  // 💡 【新設計】assets から route_master.json を非同期でロードする
  Future<void> _loadRouteMasterFile() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/route_master.json',
      );
      final Map<String, dynamic> rawMap = jsonDecode(jsonString);
      final Map<String, Map<String, List<dynamic>>> formattedMaster = {};

      rawMap.forEach((station, routes) {
        final Map<String, List<dynamic>> routeMap = {};
        if (routes is Map<String, dynamic>) {
          routes.forEach((lineId, stopStations) {
            if (stopStations is List) {
              routeMap[lineId] = stopStations;
            }
          });
        }
        formattedMaster[station] = routeMap;
      });

      myLoadedRouteMaster = formattedMaster;
      print("🚀 駅マスタのロード成功（${myLoadedRouteMaster.length}駅）");
    } catch (e) {
      print("❌ 駅マスタのロード失敗: $e");
    }
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

  // 💡 【今日が平日、土曜、日祝のどれかを判定するユーティリティ】
  String _getTodayDayType() {
    final now = DateTime.now();
    if (now.weekday == DateTime.saturday) {
      return "saturday";
    } else if (now.weekday == DateTime.sunday) {
      return "sunday";
    }
    return "weekday";
  }

  // シフト数（N本前/後）を考慮して、出発と到着の時刻をJSONからペアで引くロジック
  (TimeOfDay, TimeOfDay) _findNextTrainTimes({
    required String lineId,
    required String departureStation,
    required String arrivalStation,
    required TimeOfDay baseTime,
    int shiftCount = 0, // 💡 何本シフトするかを受け取る
  }) {
    final jsonTrips = _cachedTimetables[lineId];
    if (jsonTrips == null) return (baseTime, baseTime);

    final dayType = _getTodayDayType();
    int baseMinutes = baseTime.hour * 60 + baseTime.minute;

    List<Map<String, dynamic>> validTrips = [];
    List<int> depMinutesList = [];

    // 1. 今日走っている＆該当する駅に止まる列車をすべて抽出
    for (var trip in jsonTrips) {
      if (trip['day_type'] != dayType) continue;
      final stopTimes = trip['stop_times'] as Map<String, dynamic>;
      final depTiming = stopTimes[departureStation];
      final arrTiming = stopTimes[arrivalStation];
      if (depTiming == null || arrTiming == null) continue;

      int? depMin = depTiming['dep'] ?? depTiming['arr'];
      if (depMin != null) {
        validTrips.add(trip);
        depMinutesList.add(depMin);
      }
    }

    if (depMinutesList.isEmpty) return (baseTime, baseTime);

    // 2. 出発時間順に並び替えるためのインデックス配列を作成
    List<int> sortedIndices = List.generate(depMinutesList.length, (i) => i);
    sortedIndices.sort(
      (a, b) => depMinutesList[a].compareTo(depMinutesList[b]),
    );

    // 3. 基準時刻（現在時刻など）以降で、一番近い列車のインデックスを探す
    int baseIndexInSorted = 0;
    bool found = false;
    for (int i = 0; i < sortedIndices.length; i++) {
      if (depMinutesList[sortedIndices[i]] >= baseMinutes) {
        baseIndexInSorted = i;
        found = true;
        break;
      }
    }
    if (!found) baseIndexInSorted = 0; // なければ始発

    // 4. ベース位置に「ボタンを押した回数（シフト数）」を加算して、ターゲット列車を決定
    int targetIndexInSorted = baseIndexInSorted + shiftCount;

    // 配列の範囲外（終電以降や始発以前）にならないように丸める安全弁
    if (targetIndexInSorted < 0) targetIndexInSorted = 0;
    if (targetIndexInSorted >= sortedIndices.length)
      targetIndexInSorted = sortedIndices.length - 1;

    // 5. ターゲット列車の正確な出発・到着時刻を抽出
    final targetTrip = validTrips[sortedIndices[targetIndexInSorted]];
    final targetStopTimes = targetTrip['stop_times'] as Map<String, dynamic>;

    int finalDepMin =
        targetStopTimes[departureStation]['dep'] ??
        targetStopTimes[departureStation]['arr'];
    int finalArrMin =
        targetStopTimes[arrivalStation]['arr'] ??
        targetStopTimes[arrivalStation]['dep'];

    return (
      TimeOfDay(hour: (finalDepMin ~/ 60) % 24, minute: finalDepMin % 60),
      TimeOfDay(hour: (finalArrMin ~/ 60) % 24, minute: finalArrMin % 60),
    );
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  // 矢印ボタンが押されたとき、シフト数を±1する新しいメソッド
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
    // 💡 起動時のファイルロードを待つ安全弁
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
              // 💡 画面遷移時にロード済みの routeMaster を引き渡す
              final newRoute = await Navigator.push<TransitRoute>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddRouteScreen(routeMaster: myLoadedRouteMaster),
                ),
              );

              if (newRoute != null) {
                // 💡 新しいルートが追加されたら、そのルートが使う路線ファイルをその場で動的に追加ロードする！
                setState(() => _isLoading = true);
                for (var segment in newRoute.segments) {
                  if (segment.line.isNotEmpty) {
                    await _loadTimetableFileForLine(segment.line);
                  }
                }

                setState(() {
                  myRoutes.add(newRoute);
                  final now = DateTime.now();
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
                padEnds: false,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: 12.0,
                      top: 4.0,
                      bottom: 4.0,
                    ),
                    child: GestureDetector(
                      onTap: () async {
                        // 💡 編集画面（AddRouteScreen）へ、現在のルートデータを「editingRoute」として渡す
                        final updatedRoute = await Navigator.push<TransitRoute>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddRouteScreen(
                              routeMaster: myLoadedRouteMaster,
                              editingRoute:
                                  myRoutes[index], // 👈 ここで現在のデータを引き渡す！
                            ),
                          ),
                        );

                        // 💡 編集画面から保存されてデータが戻ってきたら、リストを更新する
                        if (updatedRoute != null) {
                          setState(() => _isLoading = true);

                          // 新しい路線が含まれているかもしれないので、念のため時刻表ファイルを再ロード
                          for (var segment in updatedRoute.segments) {
                            if (segment.line.isNotEmpty) {
                              await _loadTimetableFileForLine(segment.line);
                            }
                          }

                          setState(() {
                            myRoutes[index] =
                                updatedRoute; // 👈 該当インデックスのルートを最新版に差し替える
                            _isLoading = false;
                          });
                        }
                      },
                      child: _buildRouteTimelineCard(myRoutes[index]),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildRouteTimelineCard(TransitRoute route) {
    final baseTime = _routeBaseTimes[route.id] ?? TimeOfDay.now();
    List<TimeOfDay> departureTimes = [];
    List<TimeOfDay> arrivalTimes = [];
    TimeOfDay runningTime = baseTime;

    for (int i = 0; i < route.segments.length; i++) {
      final seg = route.segments[i];
      // この区間のシフト数のキーを作成して取得する
      final shiftKey = "${route.id}_$i";
      final currentShift = _segmentShiftCounts[shiftKey] ?? 0;

      final (dep, arr) = _findNextTrainTimes(
        lineId: seg.line,
        departureStation: seg.departureStation,
        arrivalStation: seg.arrivalStation, // 👈 追加
        baseTime: runningTime,
        shiftCount: currentShift, // 👈 追加
      );

      departureTimes.add(dep);
      arrivalTimes.add(arr); // 💡 これで「1229」がそのまま格納されます！

      // 次の乗り換えがある場合は、本物の到着時刻に徒歩時間を足す
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
              "${_formatTime(arrivalTimes.last)} 着",
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
                      _buildStationRow(
                        routeId: route.id,
                        segmentIndex: i, // 👈 これを追加！
                        stationName: route.segments[i].departureStation,
                        arrivalTime: i == 0 ? null : arrivalTimes[i - 1],
                        departureTime: departureTimes[i],
                        segment: route.segments[i],
                        isStart: i == 0,
                        isEnd: false,
                      ),
                      _buildLineRow(route.segments[i].line),
                    ],
                    _buildStationRow(
                      routeId: route.id,
                      segmentIndex: route.segments.length,
                      stationName: route.segments.last.arrivalStation,
                      arrivalTime: arrivalTimes.last,
                      departureTime: null,
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

  Widget _buildStationRow({
    required String routeId,
    required int segmentIndex, // 👈 1. 引数に segmentIndex を追加
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

    // 💡 2. 【ここを追加】現在のボタンの押し込み数（シフト数）を数えて、ラベル文字を作る
    String shiftLabel = "";
    if (!isEnd) {
      final shiftKey = "${routeId}_$segmentIndex";
      // ※まだ _segmentShiftCounts は定義していないので、一時的に 0 固定に型合わせしておきます。
      // あとで状態変数を追加したらここが連動します。
      int count = _segmentShiftCounts[shiftKey] ?? 0;
      if (count > 0) shiftLabel = " [$count本後]";
      if (count < 0) shiftLabel = " [${count.abs()}本前]";
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          isStart
              ? Icons.radio_button_checked
              : (isEnd ? Icons.location_on : Icons.brightness_1),
          color: nodeColor,
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (departureTime != null)
                // 💡 3. 【ここを修正】Rowで包んで、発車時刻の右隣にラベルを追加
                Row(
                  children: [
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
                    if (shiftLabel.isNotEmpty) // 👈 これを追加
                      Text(
                        shiftLabel,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
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
                // ⭕ 修正後：1本前に戻す
                onPressed: () => _shiftTrainCount(routeId, segmentIndex, false),
              ),
              IconButton(
                icon: const Icon(
                  Icons.keyboard_arrow_right,
                  color: Colors.white38,
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                // ⭕ 修正後：1本後に進める
                onPressed: () => _shiftTrainCount(routeId, segmentIndex, true),
              ),
            ],
          ),
      ],
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
