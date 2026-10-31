import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Offline vector "photo" for crops and diseases.
///
/// The React app shipped hand-built SVG leaves (`makeLeafSvg`); this painter
/// reproduces the same look — rounded leaf silhouette, midrib, side veins and
/// optional diagnostic spots — with zero image assets.
class LeafIllustration extends StatelessWidget {
  const LeafIllustration({
    super.key,
    required this.leafColor,
    this.spotColor,
    this.showSpots = false,
    this.size = 72,
    this.emoji,
    this.rounded = true,
  });

  final int leafColor;
  final int? spotColor;
  final bool showSpots;
  final double size;
  final String? emoji;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(rounded ? size * 0.22 : 8),
        border: Border.all(color: AppColors.faint(Color(leafColor), 0.25)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size(size, size),
            painter: _LeafPainter(
              leafColor: Color(leafColor),
              spotColor: Color(spotColor ?? 0xFFB71C1C),
              showSpots: showSpots,
            ),
          ),
          if (emoji != null)
            Positioned(
              right: 2,
              bottom: 1,
              child: Text(emoji!, style: TextStyle(fontSize: size * 0.26)),
            ),
        ],
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  _LeafPainter({
    required this.leafColor,
    required this.spotColor,
    required this.showSpots,
  });

  final Color leafColor;
  final Color spotColor;
  final bool showSpots;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final path = Path()
      ..moveTo(w * 0.5, h * 0.12)
      ..cubicTo(w * 0.86, h * 0.32, w * 0.88, h * 0.74, w * 0.5, h * 0.9)
      ..cubicTo(w * 0.12, h * 0.74, w * 0.14, h * 0.32, w * 0.5, h * 0.12)
      ..close();

    canvas.drawPath(path, Paint()..color = leafColor);

    final veinPaint = Paint()
      ..color = const Color(0xFFA7F3D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.012)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.5, h * 0.14),
      Offset(w * 0.5, h * 0.88),
      veinPaint,
    );

    final sideVein = Path()
      ..moveTo(w * 0.5, h * 0.35)
      ..quadraticBezierTo(w * 0.68, h * 0.3, w * 0.76, h * 0.26)
      ..moveTo(w * 0.5, h * 0.52)
      ..quadraticBezierTo(w * 0.32, h * 0.46, w * 0.24, h * 0.4)
      ..moveTo(w * 0.5, h * 0.68)
      ..quadraticBezierTo(w * 0.68, h * 0.62, w * 0.76, h * 0.56);
    canvas.drawPath(sideVein, veinPaint);

    if (!showSpots) return;

    final spotPaint = Paint()..color = spotColor.withAlpha(220);
    final spots = <List<double>>[
      <double>[0.42, 0.38, 0.075],
      <double>[0.62, 0.56, 0.085],
      <double>[0.46, 0.72, 0.055],
    ];
    for (final spot in spots) {
      canvas.drawCircle(
        Offset(w * spot[0], h * spot[1]),
        w * spot[2],
        spotPaint,
      );
    }

    // A subtle highlight so the leaf reads as "glossy" at small sizes.
    canvas.drawCircle(
      Offset(center.dx - w * 0.1, center.dy - h * 0.16),
      w * 0.06,
      Paint()..color = const Color(0x33FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _LeafPainter oldDelegate) =>
      oldDelegate.leafColor != leafColor ||
      oldDelegate.spotColor != spotColor ||
      oldDelegate.showSpots != showSpots;
}
