import 'package:flutter/material.dart';

class RouteLineNode extends StatelessWidget {
  final int segmentIndex;
  final List<String> availableLineNames;
  final List<String> selectedLineNames;
  final ValueChanged<List<String>> onChanged;

  const RouteLineNode({
    super.key,
    required this.segmentIndex,
    required this.availableLineNames,
    required this.selectedLineNames,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
              onTap: availableLineNames.isEmpty
                  ? null
                  : () async {
                      final tempSelected = [...selectedLineNames];

                      final result = await showDialog<List<String>>(
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
                                  children: availableLineNames.map((lineName) {
                                    return CheckboxListTile(
                                      value: tempSelected.contains(lineName),
                                      title: Text(
                                        lineName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            tempSelected.add(lineName);
                                          } else {
                                            tempSelected.remove(lineName);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context, tempSelected);
                                    },
                                    child: const Text('決定'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );

                      if (result != null) {
                        onChanged(result);
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
                child: Text(
                  availableLineNames.isEmpty
                      ? '前後の駅名を確認してください'
                      : selectedLineNames.isEmpty
                      ? '利用路線を選択'
                      : selectedLineNames.join('、'),
                  style: TextStyle(
                    fontSize: 14,
                    color: selectedLineNames.isEmpty
                        ? Colors.grey
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
