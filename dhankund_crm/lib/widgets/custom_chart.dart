import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final String title;

  const CustomChart({
    super.key,
    required this.data,
    required this.labels,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _ChartPainter(data: data, labels: labels),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;

  _ChartPainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double paddingLeft = 40.0;
    final double paddingBottom = 30.0;
    final double paddingTop = 10.0;
    final double paddingRight = 10.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Find min and max values to scale
    double maxVal = data.reduce((a, b) => a > b ? a : b);
    double minVal = data.reduce((a, b) => a < b ? a : b);
    if (maxVal == minVal) {
      maxVal += 1.0;
    }
    // Round max value to next nice number for clean grid lines
    double ceiling = (maxVal / 50000).ceil() * 50000;
    if (ceiling == 0) ceiling = 100000;

    // Grid lines (horizontal)
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..strokeWidth = 1.0;

    final labelStyle = TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 10,
    );

    int horizontalGridCount = 4;
    for (int i = 0; i <= horizontalGridCount; i++) {
      double ratio = i / horizontalGridCount;
      double y = paddingTop + chartHeight * (1 - ratio);
      
      // Draw line
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );

      // Draw Y label
      double valueLabel = ceiling * ratio;
      String formattedValue = valueLabel >= 1000 ? '${(valueLabel / 1000).toStringAsFixed(0)}k' : '${valueLabel.toStringAsFixed(0)}';
      
      final textPainter = TextPainter(
        text: TextSpan(text: formattedValue, style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    // Coordinates points list
    final List<Offset> points = [];
    final double stepX = chartWidth / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      double x = paddingLeft + i * stepX;
      double ratio = data[i] / ceiling;
      double y = paddingTop + chartHeight * (1 - ratio);
      points.add(Offset(x, y));
    }

    // Draw grid columns & X labels
    for (int i = 0; i < labels.length; i++) {
      double x = paddingLeft + i * stepX;
      
      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - paddingBottom + 8),
      );
    }

    // Gradient fill under the line path
    if (points.length > 1) {
      final Path fillPath = Path();
      fillPath.moveTo(points.first.dx, paddingTop + chartHeight);
      for (var point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, paddingTop + chartHeight);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, paddingTop),
          Offset(size.width / 2, paddingTop + chartHeight),
          [
            AppTheme.royalGold.withOpacity(0.25),
            AppTheme.royalGold.withOpacity(0.0),
          ],
        )
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);

      // Draw line chart path
      final Path linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        // Curve to make it smooth instead of sharp angles
        final prev = points[i - 1];
        final curr = points[i];
        final controlX1 = prev.dx + (curr.dx - prev.dx) / 2;
        final controlY1 = prev.dy;
        final controlX2 = prev.dx + (curr.dx - prev.dx) / 2;
        final controlY2 = curr.dy;
        
        linePath.cubicTo(controlX1, controlY1, controlX2, controlY2, curr.dx, curr.dy);
      }

      final linePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(paddingLeft, 0),
          Offset(size.width - paddingRight, 0),
          [
            AppTheme.royalGold,
            AppTheme.brightGold,
          ],
        )
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(linePath, linePaint);

      // Draw point markers
      final pointPaint = Paint()
        ..color = AppTheme.brightGold
        ..style = PaintingStyle.fill;

      final pointOutlinePaint = Paint()
        ..color = AppTheme.obsidianMedium
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      for (var point in points) {
        canvas.drawCircle(point, 5.0, pointPaint);
        canvas.drawCircle(point, 5.0, pointOutlinePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
