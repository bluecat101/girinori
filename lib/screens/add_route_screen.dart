import 'package:flutter/material.dart';
import 'package:girinori/models/transit_model.dart';

// 💡 もし TransitRoute や TransitSegment の定義が別の場所（modelsなど）にある場合は、ここにそのimportを足してください。
// 例: import '../models/transit_model.dart';
// main.dartに残したままなら: import '../main.dart'; （※構成に合わせて調整）

class AddRouteScreen extends StatefulWidget {
  const AddRouteScreen({super.key});

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: "マイ即帰宅ルート");

  final _startStationController = TextEditingController(text: "中野");
  final _firstLineController = TextEditingController(text: "東西線");
  final _firstDurationController = TextEditingController(text: "20");

  final List<Map<String, TextEditingController>> _transferSteps = [];
  final _endStationController = TextEditingController(text: "表参道");

  @override
  void initState() {
    super.initState();
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

  List<TransitSegment> _compileSegments() {
    List<TransitSegment> segments = [];

    if (_transferSteps.isEmpty) {
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
      segments.add(
        TransitSegment(
          departureStation: _startStationController.text,
          line: _firstLineController.text,
          duration: int.tryParse(_firstDurationController.text) ?? 0,
          arrivalStation: _transferSteps.first["station"]!.text,
          walkTimeAfter: int.tryParse(_transferSteps.first["walk"]!.text) ?? 0,
        ),
      );

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
                                  step["station"]!,
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

            // 下部プレビュー
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
        style: const TextStyle(
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
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
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
