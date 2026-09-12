import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';

class SpendingSparklineChart extends StatelessWidget {
  const SpendingSparklineChart({
    super.key,
    required this.spentAmount,
    required this.dailyCap,
    this.height = 70,
  });

  final double spentAmount;
  final double dailyCap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          percent: dailyCap > 0 ? (spentAmount / dailyCap).clamp(0.05, 1.0) : 0.05,
          color: AppColors.allow,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final double percent;
  final Color color;

  _SparklinePainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // Generate smooth bezier points representing today's cumulative spending flow
    final p0 = Offset(0, h * 0.85);
    final p1 = Offset(w * 0.25, h * 0.75);
    final p2 = Offset(w * 0.45, h * 0.55);
    final p3 = Offset(w * 0.65, h * 0.60);
    final p4 = Offset(w * 0.85, h * (0.85 - (0.75 * percent)));
    final pEnd = Offset(w, h * (0.80 - (0.75 * percent)));

    path.moveTo(p0.dx, p0.dy);
    path.cubicTo(p1.dx, p1.dy, p1.dx, p2.dy, p2.dx, p2.dy);
    path.cubicTo(p2.dx, p3.dy, p3.dx, p3.dy, p3.dx, p3.dy);
    path.cubicTo(p3.dx, p4.dy, p4.dx, p4.dy, p4.dx, p4.dy);
    path.cubicTo(p4.dx, pEnd.dy, pEnd.dx, pEnd.dy, pEnd.dx, pEnd.dy);

    fillPath.addPath(path, Offset.zero);
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.color != color;
  }
}
