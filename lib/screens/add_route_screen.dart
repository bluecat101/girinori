import 'package:flutter/material.dart';
import 'package:girinori/models/transit_model.dart';

// 💡 画面内で複数ルートの入力状態を管理する内部クラス
class _RouteInputData {
  late TextEditingController nameController;
  final List<TextEditingController> viaStationControllers = [];
  final List<TextEditingController> walkTimeControllers = [];
  final List<String?> selectedLines = [];

  _RouteInputData({required String defaultName}) {
    nameController = TextEditingController(text: defaultName);
    selectedLines.add(null);
  }

  void dispose() {
    nameController.dispose();
    for (var c in viaStationControllers) {
      c.dispose();
    }
    for (var c in walkTimeControllers) {
      c.dispose();
    }
  }
}

class AddRouteScreen extends StatefulWidget {
  final Map<String, Map<String, List<dynamic>>> routeMaster;
  final List<TransitRoute>? editingRoutes;

  const AddRouteScreen({
    super.key,
    required this.routeMaster,
    this.editingRoutes,
  });

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  // 💡 共通のFormStateではなく、ルートごとに独立したFormKeyを持つことで全裏ルートを一括バリデーションする
  final List<GlobalKey<FormState>> _formKeys = [];

  late TextEditingController _departureController;
  late TextEditingController _arrivalController;

  final List<_RouteInputData> _routes = [];
  int _currentRouteIndex = 0;

  @override
  void initState() {
    super.initState();

    if (widget.editingRoutes != null && widget.editingRoutes!.isNotEmpty) {
      final firstRoute = widget.editingRoutes!.first;
      _departureController = TextEditingController(
        text: firstRoute.segments.first.departureStation,
      );
      _arrivalController = TextEditingController(
        text: firstRoute.segments.last.arrivalStation,
      );

      for (var route in widget.editingRoutes!) {
        _formKeys.add(GlobalKey<FormState>()); // 各ルート用のキーを追加
        final inputData = _RouteInputData(defaultName: route.name);

        for (int i = 0; i < route.segments.length; i++) {
          if (i == 0) {
            inputData.selectedLines[0] = route.segments[0].line;
          } else {
            inputData.viaStationControllers.add(
              TextEditingController(text: route.segments[i].departureStation),
            );
            inputData.selectedLines.add(route.segments[i].line);
          }

          if (i < route.segments.length - 1) {
            inputData.walkTimeControllers.add(
              TextEditingController(
                text: route.segments[i].walkTimeAfter.toString(),
              ),
            );
          }
        }
        _routes.add(inputData);
      }
    } else {
      _departureController = TextEditingController(text: "中野");
      _arrivalController = TextEditingController(text: "渋谷");

      _formKeys.add(GlobalKey<FormState>());
      _routes.add(_RouteInputData(defaultName: "ルート 1"));
    }
  }

  @override
  void dispose() {
    _departureController.dispose();
    _arrivalController.dispose();
    for (var route in _routes) {
      route.dispose();
    }
    super.dispose();
  }

  void _addNewRouteTemplate() {
    setState(() {
      int nextNumber = _routes.length + 1;
      _formKeys.add(GlobalKey<FormState>()); // 新しいルート用のフォームキー
      _routes.add(_RouteInputData(defaultName: "ルート $nextNumber"));
      _currentRouteIndex = _routes.length - 1;
    });
  }

  // 💡 【改善①】削除時の「次ルート選択」ロジックを変更
  void _removeRoute(int index) {
    if (_routes.length <= 1) return;

    setState(() {
      _routes[index].dispose();
      _routes.removeAt(index);
      _formKeys.removeAt(index);

      // ご提示いただいたルールを完全に再現
      if (index >= _routes.length) {
        // 末尾（例: ルート3）を消した場合は、新しい末尾（実質2番目）を選択
        _currentRouteIndex = _routes.length - 1;
      } else {
        // 途中（例: ルート2）を消した場合は、元ルート3（詰まって新ルート2になる場所）を選択
        _currentRouteIndex = index;
      }
    });
  }

  void _addTransferStation() {
    setState(() {
      final currentRoute = _routes[_currentRouteIndex];
      currentRoute.viaStationControllers.add(TextEditingController(text: ""));
      currentRoute.walkTimeControllers.add(TextEditingController(text: "3"));
      currentRoute.selectedLines.add(null);
    });
  }

  void _removeTransferStation(int viaIndex) {
    setState(() {
      final currentRoute = _routes[_currentRouteIndex];
      currentRoute.viaStationControllers.removeAt(viaIndex);
      currentRoute.walkTimeControllers.removeAt(viaIndex);
      currentRoute.selectedLines.removeAt(viaIndex + 1);
    });
  }

  List<String> _getAvailableLines(int segmentIndex) {
    final currentRoute = _routes[_currentRouteIndex];

    String depStation = segmentIndex == 0
        ? _departureController.text.trim()
        : currentRoute.viaStationControllers[segmentIndex - 1].text.trim();

    String arrStation = segmentIndex == currentRoute.selectedLines.length - 1
        ? _arrivalController.text.trim()
        : currentRoute.viaStationControllers[segmentIndex].text.trim();

    if (depStation.isEmpty || arrStation.isEmpty) return [];

    final depStationData = widget.routeMaster[depStation];
    if (depStationData == null) return [];

    List<String> validLines = [];
    depStationData.forEach((lineId, stopStations) {
      if (stopStations.contains(arrStation)) {
        validLines.add(lineId);
      }
    });

    return validLines;
  }

  List<TransitRoute> _compileAllRoutes() {
    List<TransitRoute> compiledRoutes = [];

    for (var routeData in _routes) {
      List<TransitSegment> segments = [];
      int totalSegments = routeData.selectedLines.length;

      for (int i = 0; i < totalSegments; i++) {
        String dep = (i == 0)
            ? _departureController.text
            : routeData.viaStationControllers[i - 1].text;
        String arr = (i == totalSegments - 1)
            ? _arrivalController.text
            : routeData.viaStationControllers[i].text;
        int walk = (i < routeData.walkTimeControllers.length)
            ? (int.tryParse(routeData.walkTimeControllers[i].text) ?? 0)
            : 0;

        segments.add(
          TransitSegment(
            departureStation: dep,
            line: routeData.selectedLines[i] ?? "",
            duration: 15,
            arrivalStation: arr,
            walkTimeAfter: walk,
          ),
        );
      }

      compiledRoutes.add(
        TransitRoute(
          id:
              DateTime.now().millisecondsSinceEpoch.toString() +
              _routes.indexOf(routeData).toString(),
          name: routeData.nameController.text,
          segments: segments,
        ),
      );
    }
    return compiledRoutes;
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = _routes[_currentRouteIndex];
    int totalNodes = 1 + currentRoute.viaStationControllers.length + 1;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        title: Text(
          widget.editingRoutes != null ? 'ルートの一括編集' : 'ルートの一括作成',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // 💡 【改善②】横スクロール（SingleChildScrollView）にインジケータ（スクロールバー）を配置
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Scrollbar(
              thumbVisibility: true, // 常にスクロールバー（カーソル）を表示
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 6), // バーと被らないよう隙間を空ける
                child: Row(
                  children: [
                    for (int i = 0; i < _routes.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text('ルート ${i + 1}'),
                          selected: _currentRouteIndex == i,
                          selectedColor: const Color(0xFF00B0FF),
                          labelStyle: TextStyle(
                            color: _currentRouteIndex == i
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _currentRouteIndex = i;
                              });
                            }
                          },
                        ),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF00E676),
                      ),
                      onPressed: _addNewRouteTemplate,
                      tooltip: "別のルートを追加",
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // 💡 【改善③】非表示ルートの入力項目も裏側で破棄されないよう、Key値を現在のルートインデックスで固定してフォームを作成
      body: Form(
        key: _formKeys[_currentRouteIndex], // 表示中ルートのキー
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  _buildInputField(
                    currentRoute.nameController,
                    "ルート名称 (編集中のルート番号: ${_currentRouteIndex + 1})",
                    "例: 京浜東北線経由",
                    icon: Icons.edit_road,
                  ),
                  if (_routes.length > 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text("このルートを破棄"),
                        onPressed: () => _removeRoute(_currentRouteIndex),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    for (int i = 0; i < totalNodes; i++) ...[
                      _buildStationNode(
                        nodeIndex: i,
                        isStart: i == 0,
                        isEnd: i == totalNodes - 1,
                      ),
                      if (i < totalNodes - 1) _buildLineNode(segmentIndex: i),
                    ],
                    const SizedBox(height: 16),
                    _buildAddStepButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E24),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: SafeArea(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.editingRoutes != null
                        ? Colors.orangeAccent
                        : const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // 💡 【改善④】すべてのルート（非表示含む）のバリデーションを一括チェック
                    bool allValid = true;
                    int firstErrorIndex = -1;

                    for (int i = 0; i < _formKeys.length; i++) {
                      // 隠れているルートのフォームを一時的に検証するために、現在のインデックスを偽装してチェック
                      if (!_formKeys[i].currentState!.validate()) {
                        allValid = false;
                        if (firstErrorIndex == -1) {
                          firstErrorIndex = i; // 最初に不備が見つかったルート番号を記憶
                        }
                      }
                    }

                    if (!allValid) {
                      // 不備がある最初のルートへ自動ジャンプしてユーザーに知らせる
                      setState(() {
                        _currentRouteIndex = firstErrorIndex;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'ルート ${firstErrorIndex + 1} に未入力などの不備があります。',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    List<TransitRoute> results = _compileAllRoutes();
                    Navigator.pop(context, results);
                  },
                  child: Text(
                    widget.editingRoutes != null
                        ? "全 ${_routes.length} 個の変更を保存する"
                        : "全 ${_routes.length} 個のルートを一括登録する",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
  // --- 🚉 UIコンポーネント: 駅ノード ---
  Widget _buildStationNode({
    required int nodeIndex,
    bool isStart = false,
    bool isEnd = false,
  }) {
    String label = isStart ? "出発駅" : (isEnd ? "到着駅" : "経由駅 $nodeIndex");
    Color themeColor = isStart
        ? const Color(0xFF00E676)
        : (isEnd ? Colors.redAccent : const Color(0xFF00B0FF));

    final currentRoute = _routes[_currentRouteIndex];

    // 💡 どのコントローラーを対象にするかを先に確定させる
    TextEditingController targetCtrl = isStart
        ? _departureController
        : (isEnd
              ? _arrivalController
              : currentRoute.viaStationControllers[nodeIndex - 1]);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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

        Expanded(
          flex: 4,
          child: Autocomplete<String>(
            key: ValueKey('auto_${_currentRouteIndex}_$nodeIndex'),
            // 💡 テキスト値もKeyに含めて状態を完全にクリアに保つ
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty)
                return const Iterable<String>.empty();
              return widget.routeMaster.keys.where(
                (String option) => option.contains(textEditingValue.text),
              );
            },
            onSelected: (String selection) {
              setState(() {
                targetCtrl.text = selection; // 💡 共通化された対象にシンプルに代入
              });
            },
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
                  // 💡 画面が開いた時やタブ切り替え時に初期値を同期
                  if (textController.text != targetCtrl.text) {
                    textController.text = targetCtrl.text;
                  }

                  return TextFormField(
                    controller: textController,
                    focusNode: focusNode,
                    style: const TextStyle(fontSize: 14),
                    // 💡 危険な addListener は完全に排除し、onChanged だけで裏の変数と100%確実に同期させる
                    onChanged: (val) {
                      targetCtrl.text = val;
                      setState(() {}); // 路線ドロップダウンの再計算用
                    },
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: "駅名を入力",
                      filled: true,
                      fillColor: const Color(0xFF121214),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? '必須' : null,
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 220,
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);
                        return ListTile(
                          title: Text(
                            option,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        if (!isStart && !isEnd) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _buildInputField(
              currentRoute.walkTimeControllers[nodeIndex - 1],
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
            onPressed: () => _removeTransferStation(nodeIndex - 1),
          ),
        ] else ...[
          const SizedBox(width: 56),
        ],
      ],
    );
  }

  // --- ➔ UIコンポーネント: 路線ノード ---
  Widget _buildLineNode({required int segmentIndex}) {
    final currentRoute = _routes[_currentRouteIndex];
    List<String> availableLines = _getAvailableLines(segmentIndex);

    if (!availableLines.contains(currentRoute.selectedLines[segmentIndex])) {
      currentRoute.selectedLines[segmentIndex] = null;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Container(
            width: 2,
            height: 60,
            color: const Color(0xFF00B0FF),
          ),
        ),
        const SizedBox(width: 24),

        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonFormField<String>(
              // 💡 【改善⑥に関連】タブを切り替えた時にDropdownの状態を強制リフレッシュさせるためのKey
              key: ValueKey(
                'line_${_currentRouteIndex}_$segmentIndex${availableLines.length}',
              ),
              value: currentRoute.selectedLines[segmentIndex],
              hint: Text(
                availableLines.isEmpty ? "前後の駅名を確認してください" : "利用路線を選択",
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
                  currentRoute.selectedLines[segmentIndex] = newValue;
                });
              },
              validator: (value) => value == null ? '路線を選択してください' : null,
            ),
          ),
        ),
      ],
    );
  }

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
          "このルートに経由地を追加",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isNumber = false,
    IconData? icon,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      // 💡 タブ切り替え時に状態がごちゃ混ぜにならないようにKeyを追加
      key: ValueKey(controller.hashCode),
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
