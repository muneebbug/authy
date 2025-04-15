import 'package:flutter/material.dart';

/// A reusable widget that draws a Nothing OS-style dot pattern background
class DotPatternBackground extends StatelessWidget {
  /// The opacity of the dots, defaults to 0.15
  final double opacity;

  /// The spacing between dots, defaults to 16
  final double spacing;

  /// The color of the dots, defaults to white
  final Color color;

  /// Creates a dot pattern background
  const DotPatternBackground({
    Key? key,
    this.opacity = 0.05,
    this.spacing = 16,
    this.color = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to get the screen size
    final size = MediaQuery.of(context).size;

    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        painter: DotPatternPainter(
          dotColor: color.withOpacity(opacity),
          spacing: spacing,
        ),
        size: size,
      ),
    );
  }
}

/// Custom painter to draw the dot pattern background
class DotPatternPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;
  final double dotRadius = 1.0; // Increased dot size to 2px diameter

  DotPatternPainter({required this.dotColor, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true; // Enable anti-aliasing for smoother dots

    // Calculate the number of dots needed
    final numDotsX = (size.width / spacing).ceil() + 1;
    final numDotsY = (size.height / spacing).ceil() + 1;

    // Draw the dots
    for (var y = 0; y < numDotsY; y++) {
      for (var x = 0; x < numDotsX; x++) {
        canvas.drawCircle(Offset(x * spacing, y * spacing), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotPatternPainter oldDelegate) =>
      oldDelegate.dotColor != dotColor || oldDelegate.spacing != spacing;
}
