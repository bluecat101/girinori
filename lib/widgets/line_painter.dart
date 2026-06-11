import 'package:flutter/material.dart';

class LinePainter extends CustomPainter {
  final bool isWalk;
  LinePainter({required this.isWalk});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isWalk ? Colors.orange : const Color(0xFF00B0FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (!isWalk) {
      canvas.drawLine(const Offset(0, -10), Offset(0, size.height + 10), paint);
    } else {
      double dashHeight = 4, dashSpace = 4, startY = -10;
      while (startY < size.height + 10) {
        canvas.drawLine(
          Offset(0, startY),
          Offset(0, startY + dashHeight),
          paint,
        );
        startY += dashHeight + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
