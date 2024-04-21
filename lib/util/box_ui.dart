import 'package:flutter/material.dart';

class OverlayPainter extends CustomPainter {
  final List<Rect> rectangles;
  final Size imageSize;
  final Size widgetSize;

  OverlayPainter(this.rectangles, this.imageSize, this.widgetSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var rect in rectangles) {
      // Scale the rectangle coordinates to the widget size
      double scaleX = widgetSize.width / imageSize.width;
      double scaleY = widgetSize.height / imageSize.height;
      Rect scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );
      canvas.drawRect(scaledRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}