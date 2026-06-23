import 'package:flutter/material.dart';
import 'package:girinori/models/transit_model.dart';

class AddRouteScreen extends StatefulWidget {
  // final Map<String, Map<int, List<int>>> timetables;
  final Map<String, Map<String, List<dynamic>>> routeMaster;

  // const AddRouteScreen({super.key, required this.timetables});
  const AddRouteScreen({super.key, required this.routeMaster}); // 👈 引数を変更

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: "マイ即帰宅ルート");

  // 💡 初期表示は「出発駅」と「到着駅」の2つのみに修正！
  final List<TextEditingController> _stationControllers = [
    TextEditingController(text: "中野"), // index 0: 出発
    TextEditingController(text: "渋谷"), // index 1: 到着
  ];

  // 💡 最初は経由地がないので、乗り換え徒歩時間リストは「空」からスタート
  final List<TextEditingController> _walkTimeControllers = [];

  // 💡 最初は2駅（1区間）だけなので、路線枠も1つだけでスタート
  final List<String?> _selectedLines = [null];

  @override
  void dispose() {
    _nameController.dispose();
    for (var c in _stationControllers) c.dispose();
    for (var c in _walkTimeControllers) c.dispose();
    super.dispose();
  }

  // 💡 出発駅と到着駅の「両方」を結ぶ路線だけを route_master.json から動的に抽出する
  List<String> _getAvailableLines(int segmentIndex) {
    // 現在の区間の出発駅と到着駅を取得
    String depStation = _stationControllers[segmentIndex].text.trim();
    String arrStation = _stationControllers[segmentIndex + 1].text.trim();

    if (depStation.isEmpty || arrStation.isEmpty) return [];

    // 駅マスタ（widget.routeMaster）から出発駅の情報を引く
    final depStationData = widget.routeMaster[depStation];
    if (depStationData == null) return [];

    List<String> validLines = [];

    // 出発駅が持っている全路線をループ
    depStationData.forEach((lineId, stopStations) {
      // 💡 その路線の「停車駅リスト」の中に、到着駅（arrStation）が含まれているかチェック！
      if (stopStations.contains(arrStation)) {
        validLines.add(lineId); // 条件に合う路線（例: ＪＲ根岸線_大宮・南浦和方面）だけをプルダウンの選択肢にする
      }
    });

    return validLines;
  }

  // 💡 経由地を追加する（出発地と目的地の間に挟み込む）
  void _addTransferStation() {
    setState(() {
      // 常に最後（目的地）の1つ手前に新しい経由駅を挿入
      int insertIndex = _stationControllers.length - 1;

      _stationControllers.insert(insertIndex, TextEditingController(text: ""));
      _walkTimeControllers.add(TextEditingController(text: "3")); // 乗り換え時間を追加
      _selectedLines.add(null); // 新しい区間の路線枠を追加
    });
  }

  // 経由地を削除する
  void _removeTransferStation(int index) {
    if (_stationControllers.length <= 2) return;
    setState(() {
      _stationControllers.removeAt(index);
      _walkTimeControllers.removeAt(index - 1); // 対応する乗り換え時間を削除
      _selectedLines.removeAt(index - 1); // 対応する路線を削除
    });
  }

  // 入力フォームからTransitSegmentの配列にコンパイル
  List<TransitSegment> _compileSegments() {
    List<TransitSegment> segments = [];
    for (int i = 0; i < _selectedLines.length; i++) {
      segments.add(
        TransitSegment(
          departureStation: _stationControllers[i].text,
          line: _selectedLines[i] ?? "",
          duration: 15, // 固定値（Dashboard側の時刻表から自動計算されるためダミー）
          arrivalStation: _stationControllers[i + 1].text,
          walkTimeAfter: i < _walkTimeControllers.length
              ? (int.tryParse(_walkTimeControllers[i].text) ?? 0)
              : 0,
        ),
      );
    }
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        title: const Text(
          'ルートの作成',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // ルート名称入力
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: _buildInputField(
                _nameController,
                "ルート名称",
                "例: 平日の帰宅ルート",
                icon: Icons.edit_road,
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // メインタイムライン
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    for (int i = 0; i < _stationControllers.length; i++) ...[
                      // 🚉 駅ノード（出発・経由・到着）
                      _buildStationNode(
                        index: i,
                        isStart: i == 0,
                        isEnd: i == _stationControllers.length - 1,
                      ),

                      // ➔ 路線ノード（最後の駅の後ろには表示しない）
                      if (i < _stationControllers.length - 1)
                        _buildLineNode(index: i),
                    ],

                    const SizedBox(height: 16),
                    // ➕ 経由地追加ボタン
                    _buildAddStepButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // 登録ボタン
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E24),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: SafeArea(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
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
                    "このルートを登録する",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 🚉 UIコンポーネント: 駅ノード ---
  Widget _buildStationNode({
    required int index,
    bool isStart = false,
    bool isEnd = false,
  }) {
    String label = isStart ? "出発駅" : (isEnd ? "到着駅" : "経由駅 $index");
    Color themeColor = isStart
        ? const Color(0xFF00E676)
        : (isEnd ? Colors.redAccent : const Color(0xFF00B0FF));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 左側: タイムラインのピン
        Column(
          children: [
            Container(
              width: 2,
              height: 10,
              color: isStart ? Colors.transparent : Colors.white24,
            ),
            Icon(
              isStart
                  ? Icons.radio_button_checked
                  : (isEnd ? Icons.location_on : Icons.brightness_1),
              color: themeColor,
              size: 22,
            ),
            Container(
              width: 2,
              height: 10,
              color: isEnd ? Colors.transparent : Colors.white24,
            ),
          ],
        ),
        const SizedBox(width: 16),

        // 中央: 駅名入力
        Expanded(
          flex: 4,
          child: _buildInputField(
            _stationControllers[index],
            label,
            "駅名を入力",
            onChanged: (_) => setState(() {}),
          ),
        ),

        // 経由駅のすぐ横に「乗り換え時間入力」を配置
        if (!isStart && !isEnd) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _buildInputField(
              _walkTimeControllers[index - 1],
              "乗換(分)",
              "分",
              isNumber: true,
              icon: Icons.directions_walk,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              color: Colors.redAccent,
            ),
            onPressed: () => _removeTransferStation(index),
          ),
        ] else ...[
          const SizedBox(width: 56), // 出発・到着駅の右側スペース埋め
        ],
      ],
    );
  }

  // --- ➔ UIコンポーネント: 路線ノード ---
  Widget _buildLineNode({required int index}) {
    // String previousStation = _stationControllers[index].text;
    // List<String> availableLines = _getAvailableLines(previousStation);
    List<String> availableLines = _getAvailableLines(index);

    if (!availableLines.contains(_selectedLines[index])) {
      _selectedLines[index] = null;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左側: タイムラインの縦線
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Container(
            width: 2,
            height: 60,
            color: const Color(0xFF00B0FF),
          ),
        ),
        const SizedBox(width: 24),

        // 利用路線選択
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedLines[index],
              hint: Text(
                availableLines.isEmpty ? "上の駅名を入力してください" : "利用路線を選択",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              dropdownColor: const Color(0xFF1E1E24),
              decoration: const InputDecoration(
                labelText: "利用路線",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              ),
              items: availableLines.map((String line) {
                return DropdownMenuItem<String>(
                  value: line,
                  child: Text(
                    line,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedLines[index] = newValue;
                });
              },
              validator: (value) => value == null ? '路線を選択してください' : null,
            ),
          ),
        ),
      ],
    );
  }

  // --- ➕ UIコンポーネント: 経由地追加ボタン ---
  Widget _buildAddStepButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 36.0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF00B0FF),
          side: const BorderSide(color: Color(0xFF00B0FF), width: 1.5),
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: _addTransferStation,
        icon: const Icon(Icons.add_location_alt_outlined, size: 18),
        label: const Text(
          "経由地（乗り換え駅）を追加",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  // 共通テキストフィールド
  Widget _buildInputField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isNumber = false,
    IconData? icon,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 16, color: Colors.orange)
            : null,
        filled: true,
        fillColor: const Color(0xFF121214),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return '必須';
        if (isNumber && int.tryParse(value) == null) return '数値';
        return null;
      },
    );
  }
}
