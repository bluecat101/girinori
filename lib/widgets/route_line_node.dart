import 'package:flutter/material.dart';

class RouteLineNode extends StatelessWidget {
  final int segmentIndex;
  final List<String> availableLineNames;
  final String? selectedLineName;
  final ValueChanged<String?> onChanged;
  const RouteLineNode({
    super.key,
    required this.segmentIndex,
    required this.availableLineNames,
    required this.selectedLineName,
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

            child: DropdownButtonFormField<String>(
              // タブ切り替えや候補変更時に
              // Dropdownの状態をリフレッシュ
              key: ValueKey(
                'line_${segmentIndex}_${availableLineNames.length}',
              ),

              value: availableLineNames.contains(selectedLineName)
                  ? selectedLineName
                  : null,

              hint: Text(
                availableLineNames.isEmpty ? '前後の駅名を確認してください' : '利用路線を選択',

                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),

              dropdownColor: const Color(0xFF1E1E24),
              decoration: const InputDecoration(
                labelText: '利用路線',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              ),

              items: availableLineNames.map((String lineName) {
                return DropdownMenuItem<String>(
                  value: lineName,
                  child: Text(
                    lineName,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              validator: (value) {
                return value == null ? '路線を選択してください' : null;
              },
            ),
          ),
        ),
      ],
    );
  }
}
