import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' show TextPainter;
import 'package:dio/dio.dart';
import 'package:hiway_app/widgets/common/node_details.dart';
import 'package:hiway_app/data/services/orchestrator_service.dart';
import 'package:hiway_app/data/models/orchestrator_models.dart';
import 'package:hiway_app/data/services/service_factory.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';

class JobSeekerRoadmap extends StatefulWidget {
  final String title;
  final String email; // required to resolve seeker
  final String? role; // optional override (else uses seeker.target_role)
  final bool force;   // optional recompute toggle
  final OrchestratorResponse? initialData; // optional: pass pre-fetched response

  const JobSeekerRoadmap({
    super.key,
    this.title = 'Career Roadmap',
    required this.email,
    this.role,
    this.force = false,
    this.initialData,
  });

  @override
  State<JobSeekerRoadmap> createState() => _JobSeekerRoadmapState();
}

class _JobSeekerRoadmapState extends State<JobSeekerRoadmap> {
  // painter node radius (kept constant for painter + hit targets)
  static const double nodeRadius = 16.0;

  // Full list of possible alignments (for up to 10 nodes)
  final List<Alignment> allNodeAlignments = const [
    Alignment(0, -0.8),
    Alignment(-0.55, -0.6),
    Alignment(0, -0.35),
    Alignment(0.55, -0.2),
    Alignment(0.55, 0),
    Alignment(0, 0.2),
    Alignment(-0.55, 0.2),
    Alignment(-0.55, 0.4),
    Alignment(0, 0.5),
    Alignment(0, 0.7),
  ];

  final _svc = ServiceFactory.orchestrator;

  OrchestratorResponse? _data;
  String? _error;
  bool _loading = true;

  // Derived UI state
  List<Alignment> nodeAlignments = const [];
  List<RoadmapStepDetail> steps = const [];
  String activeLabel = '—'; // current milestone title

  // Indices
  int? _currentIndex; // "you are here"
  int? _nextIndex;    // "next target"

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // --- Responsive label helpers ---
  String _responsiveLabel(String label, double canvasWidth) {
    var s = label.replaceAll(RegExp(r'\s*[\(\[].*?[\)\]]'), '').trim();
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    final int maxChars = () {
      if (canvasWidth < 340) return 16;
      if (canvasWidth < 380) return 20;
      if (canvasWidth < 430) return 24;
      if (canvasWidth < 520) return 28;
      return 32;
    }();
    if (s.length <= maxChars) return s;
    final cut = s.lastIndexOf(' ', maxChars);
    final end = (cut >= 10) ? cut : maxChars;
    return s.substring(0, end).trimRight() + '…';
  }

  double _clampDouble(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  double _measureChipWidth(String text, TextStyle style, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return math.min(maxWidth, tp.width + 24); // + horizontal padding
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = widget.initialData ??
          await _svc.runOrchestrator(
            email: widget.email,
            role: widget.role,
            force: widget.force,
          );
      _data = resp;

      if (_data == null) {
        throw Exception('Failed to get roadmap data. Please try again.');
      }

      // Build steps from roadmap milestones
      final milestones = resp.roadmap?.milestones ?? [];

      // Map milestone data to UI models
      final labels = <String>[];
      final levels = <String>[];
      final resources = <List<Map<String, String>>>[];
      final certs = <List<Map<String, String>>>[];
      final groups = <List<Map<String, String>>>[];

      for (int i = 0; i < milestones.length; i++) {
        final m = milestones[i];
        final label = m.title ?? m.milestone ?? 'Milestone ${i + 1}';
        final level = m.level ?? '';

        labels.add(label);
        levels.add(level.isEmpty ? '—' : level);

        resources.add(m.resources
            .map((r) => {
                  'title': r.title,
                  'source': r.source ?? '',
                  'url': r.url ?? '',
                })
            .toList());

        certs.add(m.certifications
            .map((r) => {
                  'title': r.title,
                  'source': r.source ?? '',
                  'url': r.url ?? '',
                })
            .toList());

        groups.add(m.networkGroups
            .map((r) => {
                  'title': r.title,
                  'source': r.source ?? '',
                  'url': r.url ?? '',
                })
            .toList());
      }

      final cappedCount = _capToAlignments(labels.length);
      steps = List.generate(cappedCount, (i) {
        return RoadmapStepDetail(
          label: labels[i],
          level: levels[i],
          resources: resources[i],
          certifications: certs[i],
          networkGroups: groups[i],
        );
      });

      nodeAlignments = List.generate(cappedCount, (i) => allNodeAlignments[i]);

      // Active / Next
      final ms = _data?.milestoneStatus;
      activeLabel = ms?.currentMilestone ??
          ((ms?.milestonesScored.isNotEmpty == true &&
                  ms?.milestonesScored.first.title != null)
              ? ms!.milestonesScored.first.title!
              : '—');

      _currentIndex = _findIndexByLabel(ms?.currentMilestone, steps);
      _nextIndex = _findIndexByLabel(ms?.nextMilestone, steps);

      setState(() {
        _loading = false;
      });
    } catch (e) {
      String errorMessage;
      if (e is DioException) {
        if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage =
              'Request timed out. The server is taking too long to respond. Please try again.';
        } else if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage =
              'Could not connect to the server. Please check your internet connection.';
        } else {
          errorMessage = 'Network error: ${e.message}';
        }
      } else {
        errorMessage = e.toString();
      }

      setState(() {
        _error = errorMessage;
        _loading = false;
      });
    }
  }

  int? _findIndexByLabel(String? label, List<RoadmapStepDetail> items) {
    if (label == null || label.trim().isEmpty) return null;
    final target = label.trim().toLowerCase();
    for (int i = 0; i < items.length; i++) {
      if ((items[i].label).trim().toLowerCase() == target) return i;
    }
    for (int i = 0; i < items.length; i++) {
      final l = items[i].label.toLowerCase();
      if (l.startsWith(target) || target.startsWith(l) || l.contains(target)) {
        return i;
      }
    }
    return null;
  }

  int _capToAlignments(int n) => n.clamp(0, allNodeAlignments.length);

  @override
  Widget build(BuildContext context) {
    final appBarTitle = widget.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 12,
        foregroundColor: Colors.white,
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: AppTheme.primaryColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _fetch)
              : _data == null || steps.isEmpty
                  ? const _EmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;

                        // Node pixel positions
                        final nodePixelPositions = nodeAlignments.map((alignment) {
                          return Offset(
                            (alignment.x + 1) / 2 * width,
                            (alignment.y + 1) / 2 * height,
                          );
                        }).toList();

                        // Colors per node (green = completed, red = next, blue = default)
                        final defaultBlue = const Color(0xFF0E5AA6);
                        final green = const Color(0xFF2E7D32);
                        final red = const Color(0xFFE53935);

                        final List<Color> nodeColors =
                            List<Color>.filled(nodePixelPositions.length, defaultBlue);

                        final completedUpTo = _currentIndex ?? -1;
                        for (int i = 0; i <= completedUpTo && i < nodeColors.length; i++) {
                          nodeColors[i] = green;
                        }
                        if (_nextIndex != null &&
                            _nextIndex! >= 0 &&
                            _nextIndex! < nodeColors.length) {
                          nodeColors[_nextIndex!] = red;
                        }

                        // Responsive labels for chips
                        final painterLabels =
                            steps.map((e) => _responsiveLabel(e.label, width)).toList();

                        // Title chips under nodes (centered, non-overlapping)
                        final List<Widget> titleChips = [];
                        final List<Rect> placed = [];
                        final chipTextStyle = const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        );
                        final double maxChipWidth = math.min(width * 0.75, 280.0);
                        const double chipHeight = 40.0;
                        const double vGap = 8.0;

                        final indexOrder =
                            List<int>.generate(nodePixelPositions.length, (i) => i)
                              ..sort((a, b) => nodePixelPositions[a]
                                  .dy
                                  .compareTo(nodePixelPositions[b].dy));

                        for (final i in indexOrder) {
                          final pos = nodePixelPositions[i];
                          final text = painterLabels[i];
                          final w = _measureChipWidth(text, chipTextStyle, maxChipWidth);

                          double left = _clampDouble(pos.dx - w / 2, 8, width - w - 8);
                          double top =
                              _clampDouble(pos.dy + nodeRadius + 10, 8, height - chipHeight - 8);

                          Rect rect = Rect.fromLTWH(left, top, w, chipHeight);

                          bool collided = true;
                          int safety = 0;
                          while (collided && safety < 50) {
                            collided = false;
                            for (final r in placed) {
                              if (rect.overlaps(r)) {
                                top = r.bottom + vGap;
                                top = _clampDouble(top, 8, height - chipHeight - 8);
                                rect = Rect.fromLTWH(left, top, w, chipHeight);
                                collided = true;
                              }
                            }
                            safety++;
                          }
                          placed.add(rect);

                          titleChips.add(Positioned(
                            left: rect.left,
                            top: rect.top,
                            width: rect.width,
                            height: rect.height,
                            child: const _TitleChipWrapper(),
                          ));
                          titleChips.add(Positioned(
                            left: rect.left,
                            top: rect.top,
                            width: rect.width,
                            height: rect.height,
                            child: _TitleChip(text: text),
                          ));
                        }

                        // Check icons centered on completed (green) nodes
                        final List<Widget> checkIcons = [];
                        for (int i = 0; i <= completedUpTo && i < nodePixelPositions.length; i++) {
                          final pos = nodePixelPositions[i];
                          checkIcons.add(Positioned(
                            left: pos.dx - 10,
                            top: pos.dy - 10,
                            child: const Icon(Icons.check, size: 20, color: Colors.white),
                          ));
                        }

                        return Stack(
                          children: [
                            // Lines + node circles (color per node; edges connect at circle edges)
                            CustomPaint(
                              painter: _RoadmapPainter(
                                nodePixelPositions: nodePixelPositions,
                                nodeRadius: nodeRadius,
                                nodeColors: nodeColors,
                              ),
                              size: Size(width, height),
                            ),

                            // Tap targets (invisible)
                            for (int i = 0; i < nodePixelPositions.length; i++)
                              Positioned(
                                left: nodePixelPositions[i].dx - nodeRadius,
                                top: nodePixelPositions[i].dy - nodeRadius,
                                child: GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.white,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                      ),
                                      builder: (context) {
                                        return RoadmapStepOverlay(step: steps[i]);
                                      },
                                    );
                                  },
                                  child: Container(
                                    width: nodeRadius * 2,
                                    height: nodeRadius * 2,
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),

                            // Check icons on completed nodes
                            ...checkIcons,

                            // Title chips under nodes
                            ...titleChips,
                          ],
                        );
                      },
                    ),
    );
  }
}

class _TitleChipWrapper extends StatelessWidget {
  const _TitleChipWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // subtle shadow layer beneath the chip text
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
    );
  }
}

class _TitleChip extends StatelessWidget {
  final String text;
  const _TitleChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Painter that draws smooth connecting curves between nodes,
/// and the node circles themselves. Labels are drawn by widgets above.
class _RoadmapPainter extends CustomPainter {
  final List<Offset> nodePixelPositions;
  final double nodeRadius;
  final List<Color> nodeColors;

  _RoadmapPainter({
    required this.nodePixelPositions,
    required this.nodeRadius,
    required this.nodeColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodePixelPositions.isEmpty) return;

    // Curve style
    final pathPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Draw smooth connections between consecutive nodes.
    // Start/end on the circle EDGE (not center) so the line visibly meets the node.
    for (int i = 0; i < nodePixelPositions.length - 1; i++) {
      final c0 = nodePixelPositions[i];
      final c1 = nodePixelPositions[i + 1];

      final vec = Offset(c1.dx - c0.dx, c1.dy - c0.dy);
      final len = vec.distance;
      if (len <= 0.0001) continue;
      final u = vec / len;

      final p0 = c0 + u * nodeRadius;      // start at edge of first circle
      final p1 = c1 - u * nodeRadius;      // end at edge of next circle

      final dx = p1.dx - p0.dx;
      final bend = 0.9;
      final cp1 = Offset(p0.dx + dx * bend, p0.dy);
      final cp2 = Offset(p1.dx - dx * bend, p1.dy);

      final path = Path()..moveTo(p0.dx, p0.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      canvas.drawPath(path, pathPaint);
    }

    // Draw nodes (fill per state + white stroke)
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    for (int i = 0; i < nodePixelPositions.length; i++) {
      final p = nodePixelPositions[i];
      final fill = Paint()
        ..color = (i < nodeColors.length) ? nodeColors[i] : const Color(0xFF0E5AA6)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(p, nodeRadius, fill);
      canvas.drawCircle(p, nodeRadius, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadmapPainter oldDelegate) {
    return oldDelegate.nodePixelPositions != nodePixelPositions ||
        oldDelegate.nodeRadius != nodeRadius ||
        oldDelegate.nodeColors != nodeColors;
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 28),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No roadmap milestones yet.',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
