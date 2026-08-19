import 'package:flutter/material.dart';

import 'package:girinori/models/transit_model.dart';
import 'package:girinori/utils/format_time.dart';

class DashboardStationRow extends StatelessWidget {
  final String routeId;
  final int segmentIndex;

  final String stationName;

  final TimeOfDay? arrivalTime;
  final TimeOfDay? departureTime;

  final TransitSegment segment;

  final bool isStart;
  final bool isEnd;

  /// 現在の列車から何本ずれているか
  ///
  /// 0 なら表示なし
  /// +1 なら「1本後」
  /// -1 なら「1本前」
  final int shiftCount;

  /// 1本前・1本後のボタンが押されたとき
  final ValueChanged<bool>? onShiftTrain;

  const DashboardStationRow({
    super.key,
    required this.routeId,
    required this.segmentIndex,
    required this.stationName,
    required this.arrivalTime,
    required this.departureTime,
    required this.segment,
    required this.isStart,
    required this.isEnd,
    this.shiftCount = 0,
    this.onShiftTrain,
  });

  @override
  Widget build(BuildContext context) {
    final Color nodeColor = isStart
        ? const Color(0xFF00E676)
        : (isEnd ? Colors.redAccent : const Color(0xFF00B0FF));

    final String shiftLabel = _buildShiftLabel();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ==================================================
        // 駅ノード
        // ==================================================
        Icon(
          isStart
              ? Icons.radio_button_checked
              : (isEnd ? Icons.location_on : Icons.brightness_1),
          color: nodeColor,
          size: 14,
        ),

        const SizedBox(width: 8),

        // ==================================================
        // 駅情報
        // ==================================================
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (arrivalTime != null)
                Text(
                  '${formatTime(arrivalTime!)}着',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),

              const SizedBox(height: 1),

              Text(
                stationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isEnd ? Colors.redAccent : Colors.white,
                ),
              ),

              const SizedBox(height: 1),

              if (departureTime != null)
                Row(
                  children: [
                    Text(
                      '${formatTime(departureTime!)}発',
                      style: TextStyle(
                        color: isStart
                            ? const Color(0xFF00E676)
                            : const Color(0xFF00B0FF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (shiftLabel.isNotEmpty)
                      Text(
                        shiftLabel,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),

        // ==================================================
        // 列車変更ボタン
        // ==================================================
        if (!isEnd) _buildShiftButtons(),
      ],
    );
  }

  // ============================================================
  // シフト表示
  // ============================================================

  String _buildShiftLabel() {
    if (shiftCount > 0) {
      return ' [$shiftCount本後]';
    }

    if (shiftCount < 0) {
      return ' [${shiftCount.abs()}本前]';
    }

    return '';
  }

  // ============================================================
  // 前後ボタン
  // ============================================================

  Widget _buildShiftButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_left,
            color: Colors.white38,
            size: 16,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),

          // false = 1本前
          onPressed: onShiftTrain == null ? null : () => onShiftTrain!(false),
        ),

        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_right,
            color: Colors.white38,
            size: 16,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),

          // true = 1本後
          onPressed: onShiftTrain == null ? null : () => onShiftTrain!(true),
        ),
      ],
    );
  }
}
