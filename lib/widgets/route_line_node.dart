import 'package:flutter/material.dart';
import 'package:girinori/models/transit_model.dart';

class RouteLineNode extends StatelessWidget {
  final int segmentIndex;
  final List<String> availableLineIds;
  final List<String> selectedLineIds;
  final ValueChanged<List<String>> onChanged;
  final bool selectedLineValid;

  const RouteLineNode({
    super.key,
    required this.segmentIndex,
    required this.availableLineIds,
    required this.selectedLineIds,
    required this.onChanged,
    required this.selectedLineValid,
  });

  @override
  Widget build(BuildContext context) {
    // 選択された路線の表示名を取得
    List<String> selectedDisplayLineNames = TransitSegment.extractUniqueLineIds(
      selectedLineIds,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==================================================
        // 路線の縦線
        // ==================================================
        Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Container(
            width: 2,
            height: 60,
            color: const Color(0xFF00B0FF),
          ),
        ),

        const SizedBox(width: 24),

        // ==================================================
        // 路線選択
        // ==================================================
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: availableLineIds.isEmpty
                  ? null
                  : () async {
                      final selectedLineNames = await _showLineSelectDialog(
                        context: context,
                      );
                      if (selectedLineNames != null) {
                        onChanged(selectedLineNames);
                      }
                    },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '利用路線',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // 必要な高さだけ使う
                  children: [
                    // 既存の選択テキスト
                    Text(
                      availableLineIds.isEmpty
                          ? '前後の駅名を確認してください'
                          : selectedDisplayLineNames.isEmpty
                          ? '利用路線を選択'
                          : selectedDisplayLineNames.join('、'),
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedDisplayLineNames.isEmpty
                            ? Colors.grey
                            : Colors.white,
                      ),
                    ),

                    // エラー時（未選択かつ保存押下後）のみ中に「必須」を表示
                    if (!selectedLineValid) ...[
                      const SizedBox(height: 4), // テキストとの微小な隙間
                      const Text(
                        '必須',
                        style: TextStyle(
                          color: Color(0xFFB3261E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<String>?> _showLineSelectDialog({
    required BuildContext context,
  }) async {
    // 利用可能な路線IDを表示名ごとにグループ化する
    final Map<String, List<String>> displayedLines = {};
    for (final availableLineId in availableLineIds) {
      final displayName = TransitSegment.extractUniqueLineId(availableLineId);
      displayedLines.putIfAbsent(displayName, () => []).add(availableLineId);
    }

    final tempSelected = [...selectedLineIds];

    return await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E24),
              title: const Text(
                '利用路線を選択',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: displayedLines.entries.map((entry) {
                  final lineName = entry.key; // 表示名
                  final lineIds = entry.value; // 路線Id

                  // すべての詳細名が選択されているかでチェック状態を判定
                  final isAllSelected = lineIds.every(
                    (name) => tempSelected.contains(name),
                  );

                  return CheckboxListTile(
                    value: isAllSelected,
                    title: Text(
                      lineName,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          // チェック時：紐づく詳細名をすべて追加
                          for (final name in lineIds) {
                            if (!tempSelected.contains(name)) {
                              tempSelected.add(name);
                            }
                          }
                        } else {
                          // チェック解除時：紐づく詳細名をすべて削除
                          for (final name in lineIds) {
                            tempSelected.remove(name);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, tempSelected),
                  child: const Text('決定'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
