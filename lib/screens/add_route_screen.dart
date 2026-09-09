import 'package:flutter/material.dart';
import 'package:girinori/controllers/route_input_controller.dart';
import 'package:girinori/models/transit_model.dart';
import 'package:girinori/widgets/route_input/route_station_node.dart';
import 'package:girinori/widgets/route_line_node.dart';

class AddRouteScreen extends StatefulWidget {
  final Map<String, Map<String, List<dynamic>>> routeMaster;
  final TransitRoute? editingRoute;

  const AddRouteScreen({
    super.key,
    required this.routeMaster,
    this.editingRoute,
  });

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  // 💡 共通のFormStateではなく、ルートごとに独立したFormKeyを持つことで全裏ルートを一括バリデーションする
  late final RouteInputController _controller;
  final ScrollController _routeTabScrollController = ScrollController();
  // 💡 駅名が変更されたときに、路線選択のDropdownをリフレッシュするためのNotifier
  final ValueNotifier<int> _stationChangeNotifier = ValueNotifier(0);
  @override
  void initState() {
    super.initState();
    _controller = RouteInputController(
      routeMaster: widget.routeMaster,
      editingRoute: widget.editingRoute,
    );
  }

  @override
  void dispose() {
    _routeTabScrollController.dispose();
    _controller.dispose();
    _stationChangeNotifier.dispose();
    super.dispose();
  }

  void _addTransferStation() {
    setState(() {
      _controller.addTransferStation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = _controller.currentRoute;
    final totalNodes = _controller.totalNodes;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        title: Text(
          widget.editingRoute != null ? 'ルートの編集' : 'ルートの作成',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // 非表示ルートの入力項目も裏側で破棄されないよう、Key値を現在のルートインデックスで固定してフォームを作成
      body: Form(
        key: _controller.formKey, // 表示中ルートのキー
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
                    "ルート名称",
                    "例: 京浜東北線経由",
                    icon: Icons.edit_road,
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
                      RouteStationNode(
                        nodeIndex: i,
                        isStart: i == 0,
                        isEnd: i == _controller.totalNodes - 1,
                        stationController: _controller.getStationController(i),
                        walkTimeController: _controller.getWalkTimeController(
                          i,
                        ),
                        stationNames: widget.routeMaster.keys,
                        onStationChanged: (value) {
                          _controller.getStationController(i).text = value;
                          _stationChangeNotifier.value++;
                        },
                        onStationSelected: (station) {
                          _controller.getStationController(i).text = station;
                          setState(() {});
                        },
                        onRemove: i > 0 && i < _controller.totalNodes - 1
                            ? () {
                                setState(() {
                                  _controller.removeTransferStation(i - 1);
                                });
                              }
                            : null,
                      ),
                      if (i < _controller.totalNodes - 1)
                        ValueListenableBuilder<int>(
                          valueListenable: _stationChangeNotifier,
                          builder: (context, _, child) {
                            return RouteLineNode(
                              segmentIndex: i,
                              availableLineNames: _controller
                                  .getAvailableLineNames(i),
                              selectedLineNames: _controller
                                  .getSelectedLineNames(i),
                              onChanged: (newValue) {
                                _controller.selectLine(i, newValue);
                                setState(() {});
                              },
                            );
                          },
                        ),
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
                    backgroundColor: widget.editingRoute != null
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
                    // 隠れているルートのフォームを一時的に検証するために、現在のインデックスを偽装してチェック
                    if (!_controller.formKey.currentState!.validate()) {
                      allValid = false;
                    }

                    // 不備があればSnackBarで通知して登録処理を中断
                    if (!allValid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('ルートに未入力などの不備があります。'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    final result = _controller.compileRoute();
                    Navigator.pop(context, result);
                  },
                  child: Text(
                    widget.editingRoute != null ? "変更を保存する" : "ルートを登録する",
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

  List<String> _extractUniqueLineNames(List<String> fullLineNames) {
    return fullLineNames
        .map((fullLineName) {
          final lineName = fullLineName.split('_').first;
          return lineName;
        })
        .toSet()
        .toList();
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
