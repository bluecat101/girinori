import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RouteStationNode extends StatelessWidget {
  final int nodeIndex;
  final bool isStart;
  final bool isEnd;

  /// 駅名入力に使うController
  final TextEditingController stationController;

  /// 乗換時間に使うController
  /// 出発駅・到着駅の場合はnull
  final TextEditingController? walkTimeController;

  /// 駅名候補
  final Iterable<String> stationNames;

  /// 駅名が変更されたとき
  final ValueChanged<String> onStationChanged;

  /// 駅名候補が選択されたとき
  final ValueChanged<String> onStationSelected;

  /// 経由駅を削除
  final VoidCallback? onRemove;

  const RouteStationNode({
    super.key,
    required this.nodeIndex,
    this.isStart = false,
    this.isEnd = false,
    required this.stationController,
    this.walkTimeController,
    required this.stationNames,
    required this.onStationChanged,
    required this.onStationSelected,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final String label = isStart ? '出発駅' : (isEnd ? '到着駅' : '経由駅 $nodeIndex');
    final Color themeColor = isStart
        ? const Color(0xFF00E676)
        : (isEnd ? Colors.redAccent : const Color(0xFF00B0FF));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ==================================================
        // 駅ノード
        // ==================================================
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

        // ==================================================
        // 駅名
        // ==================================================
        Expanded(
          flex: 4,
          child: Autocomplete<String>(
            key: ValueKey('auto_${nodeIndex}_${stationController.text}'),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return stationNames.where(
                (String option) => option.contains(textEditingValue.text),
              );
            },

            onSelected: (String selection) {
              onStationSelected(selection);
            },
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
                  // 画面表示時・再構築時に
                  // 親から渡されたControllerの値を同期
                  if (textController.text != stationController.text) {
                    textController.value = stationController.value;
                  }
                  return TextFormField(
                    controller: textController,
                    focusNode: focusNode,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    onChanged: (value) {
                      onStationChanged(value);
                    },
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: '駅名を入力',
                      labelStyle: const TextStyle(color: Colors.grey),
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF121214),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: themeColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '必須';
                      }
                      return null;
                    },
                  );
                },

            // ==================================================
            // 駅候補
            // ==================================================
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
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ==================================================
        // 乗換時間 + 削除
        // ==================================================
        if (!isStart && !isEnd) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _WalkTimeField(controller: walkTimeController!),
          ),

          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              color: Colors.redAccent,
            ),
            onPressed: onRemove,
          ),
        ] else ...[
          const SizedBox(width: 56),
        ],
      ],
    );
  }
}

// ============================================================
// 乗換時間入力
// ============================================================

class _WalkTimeField extends StatelessWidget {
  final TextEditingController controller;
  const _WalkTimeField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                if (newValue.text.isEmpty) {
                  return newValue;
                }
                if (RegExp(r'^[0-9]+$').hasMatch(newValue.text)) {
                  return newValue;
                }
                return oldValue;
              }),
            ],
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              labelText: '乗換(分)',
              suffixText: '分',
              labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              suffixStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              filled: true,
              fillColor: const Color(0xFF121214),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              prefixIcon: const Icon(
                Icons.directions_walk,
                color: Colors.orangeAccent,
                size: 17,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '必須';
              }
              if (int.tryParse(value.trim()) == null) {
                return '数値';
              }
              return null;
            },
          ),
        ),

        const SizedBox(width: 4),

        // 上下ボタン
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNumberButton(
              icon: Icons.keyboard_arrow_up,
              onPressed: () {
                final current = int.tryParse(controller.text) ?? 0;
                controller.text = (current + 1).toString();
              },
            ),
            _buildNumberButton(
              icon: Icons.keyboard_arrow_down,
              onPressed: () {
                final current = int.tryParse(controller.text) ?? 0;

                if (current > 0) {
                  controller.text = (current - 1).toString();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 32,
      height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20, color: Colors.white70),
        onPressed: onPressed,
      ),
    );
  }
}
