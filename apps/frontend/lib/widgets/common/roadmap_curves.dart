import 'package:flutter/material.dart';
import 'dart:math';

class CurveCustomPainter extends CustomPainter {
  final List<Offset> nodePositions;
  final double nodeRadius;
  final List<String>? labels;
  final String? activeIndex; // Now a String, matches a label

  CurveCustomPainter(
    this.nodePositions, {
    this.nodeRadius = 16,
    this.labels,
    this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    const elbowRadius = 24.0;

    // Draw lines (as before)
    if (nodePositions.length >= 2) {
      for (var i = 0; i < nodePositions.length - 1; i++) {
        var p1 = nodePositions[i];
        var p2 = nodePositions[i + 1];

        bool isDiagonal = (p1.dx != p2.dx) && (p1.dy != p2.dy);

        if (isDiagonal) {
          final path = Path();
          path.moveTo(p1.dx, p1.dy);

          bool horizontalFirst = (p2.dx - p1.dx).abs() > (p2.dy - p1.dy).abs();

          Offset corner;
          if (horizontalFirst) {
            corner = Offset(p2.dx, p1.dy);
          } else {
            corner = Offset(p1.dx, p2.dy);
          }

          Offset beforeCorner, afterCorner;
          if (horizontalFirst) {
            beforeCorner = Offset(
              corner.dx - elbowRadius * (p2.dx > p1.dx ? 1 : -1),
              corner.dy,
            );
            afterCorner = Offset(
              corner.dx,
              corner.dy + elbowRadius * (p2.dy > p1.dy ? 1 : -1),
            );
          } else {
            beforeCorner = Offset(
              corner.dx,
              corner.dy - elbowRadius * (p2.dy > p1.dy ? 1 : -1),
            );
            afterCorner = Offset(
              corner.dx + elbowRadius * (p2.dx > p1.dx ? 1 : -1),
              corner.dy,
            );
          }

          path.lineTo(beforeCorner.dx, beforeCorner.dy);
          path.quadraticBezierTo(
            corner.dx,
            corner.dy,
            afterCorner.dx,
            afterCorner.dy,
          );
          path.lineTo(p2.dx, p2.dy);

          canvas.drawPath(path, paint);
        } else {
          canvas.drawLine(p1, p2, paint);
        }
      }
    }

    // Draw filled circles (all green up to and including activeIndex, next step red)
    int lastGreenIndex = -1;
    int nextRedIndex = -1;
    if (activeIndex != null && labels != null) {
      lastGreenIndex = labels!.indexOf(activeIndex!);
      if (lastGreenIndex != -1 && lastGreenIndex + 1 < nodePositions.length) {
        nextRedIndex = lastGreenIndex + 1;
      }
    }

    for (int i = 0; i < nodePositions.length; i++) {
      final center = nodePositions[i];
      final isGreen = (lastGreenIndex != -1 && i <= lastGreenIndex);
      final isRed = (i == nextRedIndex);
      final fillPaint = Paint()
        ..color = isGreen
            ? const Color.fromARGB(255, 10, 220, 94)
            : isRed
            ? const Color.fromARGB(255, 181, 17, 5)
            : Colors.blue.shade900
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, nodeRadius, fillPaint);
    }

    // Draw white-bordered circles
    var circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    for (final center in nodePositions) {
      canvas.drawCircle(center, nodeRadius, circlePaint);
    }

    // --- Label placement (unchanged) ---
    if (labels != null && labels!.length == nodePositions.length) {
      List<Rect> labelRects = [];

      for (int i = 0; i < nodePositions.length; i++) {
        final label = labels![i];
        final center = nodePositions[i];

        final textSpan = TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        );
        tp.layout();

        // Candidate positions: right, left, top, bottom, and diagonals (more options)
        final candidates = [
          Offset(
            center.dx + nodeRadius + 8,
            center.dy - tp.height / 2,
          ), // right
          Offset(
            center.dx - nodeRadius - 8 - tp.width,
            center.dy - tp.height / 2,
          ), // left
          Offset(
            center.dx - tp.width / 2,
            center.dy - nodeRadius - 8 - tp.height,
          ), // top
          Offset(
            center.dx - tp.width / 2,
            center.dy + nodeRadius + 8,
          ), // bottom
          Offset(
            center.dx + nodeRadius + 8,
            center.dy - nodeRadius - 8 - tp.height,
          ), // top-right
          Offset(
            center.dx + nodeRadius + 8,
            center.dy + nodeRadius + 8,
          ), // bottom-right
          Offset(
            center.dx - nodeRadius - 8 - tp.width,
            center.dy - nodeRadius - 8 - tp.height,
          ), // top-left
          Offset(
            center.dx - nodeRadius - 8 - tp.width,
            center.dy + nodeRadius + 8,
          ), // bottom-left
          // Extra diagonals for more flexibility
          Offset(
            center.dx + nodeRadius + 8,
            center.dy - 1.5 * nodeRadius - 8 - tp.height,
          ), // far top-right
          Offset(
            center.dx - nodeRadius - 8 - tp.width,
            center.dy - 1.5 * nodeRadius - 8 - tp.height,
          ), // far top-left
          Offset(
            center.dx + nodeRadius + 8,
            center.dy + 1.5 * nodeRadius + 8,
          ), // far bottom-right
          Offset(
            center.dx - nodeRadius - 8 - tp.width,
            center.dy + 1.5 * nodeRadius + 8,
          ), // far bottom-left
        ];

        // Rotate candidate order based on node index for better distribution
        final rotatedCandidates = [
          for (int k = 0; k < candidates.length; k++)
            candidates[(k + i) % candidates.length],
        ];

        Offset? chosen;
        double minOverlapArea = double.infinity;
        double minPenalty = double.infinity;

        for (final candidate in rotatedCandidates) {
          final rect = Rect.fromLTWH(
            candidate.dx,
            candidate.dy,
            tp.width,
            tp.height,
          );

          // Out of bounds
          bool offCanvas =
              rect.left < 0 ||
              rect.top < 0 ||
              rect.right > size.width ||
              rect.bottom > size.height;
          if (offCanvas) continue;

          // Overlap with lines
          bool overlapsLine = false;
          for (int j = 0; j < nodePositions.length - 1; j++) {
            if (i == j || i == j + 1) continue;
            final pA = nodePositions[j];
            final pB = nodePositions[j + 1];
            if (_rectLineDistance(rect, pA, pB) < 12) {
              overlapsLine = true;
              break;
            }
          }

          // Overlap area with other labels
          double overlapArea = 0;
          for (final r in labelRects) {
            if (r.overlaps(rect)) {
              final overlapRect = r.intersect(rect);
              overlapArea += overlapRect.width * overlapRect.height;
            }
          }

          // If no overlap with labels, pick this immediately (prefer less line overlap)
          if (overlapArea == 0) {
            double penalty = overlapsLine ? 100 : 0;
            penalty += rotatedCandidates.indexOf(candidate);
            if (penalty < minPenalty) {
              minPenalty = penalty;
              chosen = candidate;
            }
          } else if (chosen == null && overlapArea < minOverlapArea) {
            // If all candidates overlap, pick the one with the least overlap area
            minOverlapArea = overlapArea;
            chosen = candidate;
          }
        }

        // Fallback: if all candidates are off-canvas, pick the first candidate
        chosen ??= rotatedCandidates.first;

        final rect = Rect.fromLTWH(chosen.dx, chosen.dy, tp.width, tp.height);
        labelRects.add(rect);

        // Draw blue background behind the text
        final bgRect = RRect.fromRectAndRadius(
          rect.inflate(4), // padding around text
          const Radius.circular(6),
        );
        canvas.drawRRect(bgRect, Paint()..color = const Color(0xFF352DC3));

        tp.paint(canvas, chosen);
      }
    }
  }

  // Helper: minimum distance from a rect to a line segment
  double _rectLineDistance(Rect rect, Offset a, Offset b) {
    final points = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
      rect.center,
    ];
    return points.map((p) => _pointLineDistance(p, a, b)).reduce(min);
  }

  // Helper: distance from point p to line segment ab
  double _pointLineDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    double t = ab2 == 0 ? 0 : (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
    t = t.clamp(0, 1);
    final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - closest).distance;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
