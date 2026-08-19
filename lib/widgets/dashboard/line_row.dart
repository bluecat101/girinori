import 'package:flutter/material.dart';

class LineRow extends StatelessWidget {
  final String lineName;

  const LineRow({super.key, required this.lineName});

  @override
  Widget build(BuildContext context) {
    // 画面表示用に prefix
    // 「ＪＲ根岸線_大宮・南浦和方面」→「ＪＲ根岸線」
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
