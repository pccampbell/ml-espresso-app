import 'package:flutter/material.dart';

class CustomBoxPainter extends CustomPainter {
  final List<Rect> boxes;

  CustomBoxPainter(this.boxes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var box in boxes) {
      canvas.drawRect(box, paint);
    }
  }

  @override
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Implement your logic to determine if the painter should repaint
    // For simplicity, you can just return true
    return true;
  }
}
