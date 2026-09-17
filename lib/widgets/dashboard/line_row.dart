import 'package:flutter/material.dart';

class LineRow extends StatelessWidget {
  final List<String> lineNames;
  final Color lineColor;

  const LineRow({super.key, required this.lineNames, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    // 表示する路線名
    final cleanName = lineNames.isNotEmpty ? lineNames.first.split('_')[0] : '';

    // 複数の路線がある場合は「...」を追加
    final displayName = lineNames.length > 1 ? '$cleanName...' : cleanName;

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6.0),
          child: Container(
            width: 1,
            height: 16,
            color: lineColor.withOpacity(0.5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: lineColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
