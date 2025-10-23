import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:hiway_app/widgets/common/node_details.dart';
import 'package:hiway_app/data/models/orchestrator_models.dart';
import 'package:hiway_app/data/services/service_factory.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';

class JobSeekerRoadmap extends StatefulWidget {
  final String title;
  final String email;
  final String? role;
  final bool force;
  final OrchestratorResponse? initialData;

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
  final _svc = ServiceFactory.orchestrator;
  OrchestratorResponse? _data;
  String? _error;
  bool _loading = true;

  List<RoadmapStepDetail> steps = const [];
  String activeLabel = '—';
  int? _currentIndex;
  int? _nextIndex;

  @override
  void initState() {
    super.initState();
    _fetch();
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

      if (_data == null) throw Exception('Failed to get roadmap data.');

      final milestones = resp.roadmap?.milestones ?? [];
      final labels = <String>[];
      final levels = <String>[];
      final resources = <List<Map<String, String>>>[];
      final certs = <List<Map<String, String>>>[];
      final groups = <List<Map<String, String>>>[];

      for (int i = 0; i < milestones.length; i++) {
        final m = milestones[i];
        labels.add(m.title ?? m.milestone ?? 'Milestone ${i + 1}');
        levels.add(m.level ?? '—');
        resources.add(m.resources
            .map((r) => {'title': r.title, 'source': r.source ?? '', 'url': r.url ?? ''})
            .toList());
        certs.add(m.certifications
            .map((r) => {'title': r.title, 'source': r.source ?? '', 'url': r.url ?? ''})
            .toList());
        groups.add(m.networkGroups
            .map((r) => {'title': r.title, 'source': r.source ?? '', 'url': r.url ?? ''})
            .toList());
      }

      steps = List.generate(
        labels.length,
        (i) => RoadmapStepDetail(
          label: labels[i],
          level: levels[i],
          resources: resources[i],
          certifications: certs[i],
          networkGroups: groups[i],
        ),
      );

      final ms = _data?.milestoneStatus;
      activeLabel = ms?.currentMilestone ?? '—';
      _currentIndex = _findIndexByLabel(ms?.currentMilestone, steps);
      _nextIndex = _findIndexByLabel(ms?.nextMilestone, steps);

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
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

  List<Offset> _calculateNodePositions(int count, double width, double height) {
    final positions = <Offset>[];
    if (count <= 0) return positions;

    final centerX = width / 2;
    final startY = 140.0;
    final endY = math.max(startY + 1, height - 180.0);

    final denom = math.max(1, count - 1);
    final spacing = (endY - startY) / denom;

    for (int i = 0; i < count; i++) {
      final progress = denom == 0 ? 0.0 : i / denom;
      final y = startY + spacing * i;
      final amplitude = width * 0.28;
      final x = centerX + amplitude * math.sin(progress * math.pi * 2);
      positions.add(Offset(x, y));
    }
    return positions;
  }

  /// Format label as exactly 3 words per line, up to 2 lines.
  /// If there are more words than 6, add a 3rd line with just "....".
  String _formatLabelTwoLinesThenDots(String text,
      {int wordsPerLine = 3, int maxLines = 2}) {
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
    if (words.isEmpty) return text;

    final lines = <String>[];
    int i = 0;
    for (int line = 0; line < maxLines && i < words.length; line++) {
      final end = math.min(i + wordsPerLine, words.length);
      lines.add(words.sublist(i, end).join(' '));
      i = end;
    }

    if (i < words.length) {
      lines.add('....'); // third line = dots
    }

    return lines.join('\n');
  }

  List<Widget> _buildMilestoneWidgets(
    BuildContext context,
    List<RoadmapStepDetail> steps,
    List<Offset> nodePositions,
    double width,
  ) {
    final widgets = <Widget>[];

    const double nodeDiameter = 30.0;
    const double margin = 8.0;
    const double spacing = 18.0;
    final double labelWidth = math.min(width * 0.45, 260.0);

    for (int i = 0; i < steps.length; i++) {
      final pos = nodePositions[i];
      final step = steps[i];
      final isCompleted = i <= (_currentIndex ?? -1);
      final isNext = i == _nextIndex;

      // Static node color (tap does not change visuals)
      Color nodeColor;
      if (isCompleted) {
        nodeColor = Colors.green;
      } else if (isNext) {
        nodeColor = const Color(0xFFFF6B35);
      } else {
        nodeColor = Colors.white;
      }

      // Node
      widgets.add(Positioned(
        left: pos.dx - (nodeDiameter / 2),
        top: pos.dy - (nodeDiameter / 2),
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (context) => RoadmapStepOverlay(step: step),
            );
          },
          child: Container(
            width: nodeDiameter,
            height: nodeDiameter,
            decoration: BoxDecoration(
              color: nodeColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ));

      // Preferred side (alternate), then auto-flip if border would be hit
      bool placeLeft = i.isEven;
      double candidateX =
          placeLeft ? pos.dx - labelWidth - spacing : pos.dx + (nodeDiameter / 2) + spacing;

      if (candidateX < margin) {
        placeLeft = false;
        candidateX = pos.dx + (nodeDiameter / 2) + spacing;
      }
      if (candidateX + labelWidth > width - margin) {
        placeLeft = true;
        candidateX = pos.dx - labelWidth - spacing;
      }
      final left = candidateX.clamp(margin, width - labelWidth - margin);

      // Two lines of 3 words each, then "...." if more
      final formatted = _formatLabelTwoLinesThenDots(step.label);

      widgets.add(Positioned(
        left: left,
        top: pos.dy - 22,
        width: labelWidth,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color.fromARGB(0, 255, 255, 255).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            step.label,
            textAlign: placeLeft ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: 0.2,
            ),
            maxLines: 2, // show up to 2 lines
            overflow: TextOverflow.ellipsis, // show "...." automatically
            softWrap: true,
          ),
        ),
      ));
    }

    return widgets;
  }

  String _resolveRoleTitle() {
    final fromWidget = widget.role?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;

    final fromRoadmap = _data?.roadmap?.role;
    if (fromRoadmap != null && fromRoadmap.trim().isNotEmpty) return fromRoadmap.trim();

    final fromStatus = _data?.milestoneStatus?.nextMilestone;
    if (fromStatus != null && fromStatus.trim().isNotEmpty) {
      return fromStatus.trim();
    }
    return 'Target Role';
  }

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
                        final nodePositions =
                            _calculateNodePositions(steps.length, width, height);
                        final roleTitle = _resolveRoleTitle();

                        return Stack(
                          children: [
                            // Background gradient
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFF4338CA), Color(0xFF1E1B4B)],
                                ),
                              ),
                            ),

                            // Role title (above roadmap)
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 12,
                              child: SafeArea(
                                bottom: false,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.18),
                                      ),
                                    ),
                                    child: Text(
                                      roleTitle,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Dotted center line
                            Positioned(
                              left: width / 2 - 1,
                              top: 100,
                              bottom: 100,
                              child: CustomPaint(
                                size: Size(2, height - 200),
                                painter: _DottedLinePainter(),
                              ),
                            ),

                            // Curved path
                            CustomPaint(
                              size: Size(width, height),
                              painter: _CurvedPathPainter(nodePositions: nodePositions),
                            ),

                            // Nodes + labels
                            ..._buildMilestoneWidgets(
                                context, steps, nodePositions, width),

                            // Footer hint
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 40,
                              child: Text(
                                'Tap on nodes to view progress, performance and action items',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 2;
    const dashHeight = 5;
    const dashSpace = 5;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CurvedPathPainter extends CustomPainter {
  final List<Offset> nodePositions;
  _CurvedPathPainter({required this.nodePositions});

  @override
  void paint(Canvas canvas, Size size) {
    if (nodePositions.length < 2) return;
    final pathPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(nodePositions[0].dx, nodePositions[0].dy);
    for (int i = 0; i < nodePositions.length - 1; i++) {
      final c = nodePositions[i];
      final n = nodePositions[i + 1];
      final midY = (c.dy + n.dy) / 2;
      path.cubicTo(c.dx, midY, n.dx, midY, n.dx, n.dy);
    }
    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedPathPainter oldDelegate) =>
      oldDelegate.nodePositions != nodePositions;
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
      child: Text('No roadmap milestones yet.', style: TextStyle(color: Colors.white)),
    );
  }
}
