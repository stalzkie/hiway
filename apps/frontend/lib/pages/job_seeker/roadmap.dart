import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/roadmap_curves.dart';
import 'package:hiway_app/widgets/common/node_details.dart';

class JobSeekerRoadmap extends StatefulWidget {
  final String title;
  const JobSeekerRoadmap({super.key, this.title = 'Career Roadmap'});

  @override
  State<JobSeekerRoadmap> createState() => _JobSeekerRoadmapState();
}

final int nodeCount = 4; //ADD HERE VARIABLE OF THE NUMBER OF MILESTONES
final double nodeRadius = 16.0;

class _JobSeekerRoadmapState extends State<JobSeekerRoadmap> {
  // Full list of possible alignments (for up to 10 nodes)
  final List<Alignment> allNodeAlignments = [
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

  // Use a loop to create the nodeAlignments array for the current nodeCount
  late final List<Alignment> nodeAlignments = List.generate(
    nodeCount,
    (i) => allNodeAlignments[i],
  );

  final List<String> labels = [
    'Start',
    'Step 1',
    'Step 2',
    'Step 3',
    'Step 4',
    'Step 5',
    'Step 6',
    'Step 7',
    'Step 8',
    'Step 9',
  ]; //REPLACE WITH LIST OF MILESTONES FROM THE DATABASE

  final List<String> level = [
    'Beginner',
    'Intermediate',
    'Hard',
    'Beginner',
    'Intermediate',
    'Hard',
    'Beginner',
    'Intermediate',
    'Hard',
    'Beginner',
  ]; //REPLACE WITH LIST OF LEVELS FROM THE DATABASE AND SAME WITH RESOURCES, CERTS, AND NETWORK GROUPS

  final List<List<Map<String, String>>> resources = [
    [
      {
        'title': 'Flutter Docs',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {
        'title': 'Resource 1',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {
        'title': 'Resource 2',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {
        'title': 'Resource 3',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {
        'title': 'Resource 4',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {
        'title': 'Resource 5',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {
        'title': 'Resource 6',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {
        'title': 'Resource 7',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {
        'title': 'Resource 8',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {
        'title': 'Resource 9',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
  ];

  final List<List<Map<String, String>>> certifications = [
    [
      {
        'title': 'Flutter Cert',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {'title': 'Cert 1', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Cert 2', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Cert 3', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Cert 4', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Cert 5', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Cert 6', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Cert 7', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Cert 8', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Cert 9', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
  ];

  final List<List<Map<String, String>>> networkGroups = [
    [
      {
        'title': 'Flutter Group',
        'source': 'Official',
        'url': 'https://flutter.dev',
      },
    ],
    [
      {'title': 'Group 1', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Group 2', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Group 3', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Group 4', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Group 5', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Group 6', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Group 7', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Group 8', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
    [
      {'title': 'Group 9', 'source': 'Official', 'url': 'https://flutter.dev'},
    ],
  ];

  // Generate the steps list using a for loop (List.generate)
  late final List<RoadmapStepDetail> steps = List.generate(
    nodeCount,
    (i) => RoadmapStepDetail(
      label: labels[i],
      level: level[i],
      resources: resources[i],
      certifications: certifications[i],
      networkGroups: networkGroups[i],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sample'),
        elevation: 14,
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF352DC3),
      ),
      backgroundColor: const Color(0xFF352DC3),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          // Convert alignments to pixel offsets
          final nodePixelPositions = nodeAlignments.map((alignment) {
            return Offset(
              (alignment.x + 1) / 2 * width,
              (alignment.y + 1) / 2 * height,
            );
          }).toList();

          return Stack(
            children: [
              // 1. Draw lines and circles with CustomPaint
              CustomPaint(
                painter: CurveCustomPainter(
                  nodePixelPositions,
                  nodeRadius: nodeRadius,
                  labels: steps.map((e) => e.label).toList(),
                  activeIndex:
                      'Step 2', //INSERT CURRENT INDEX VALUE OF THE ROADMAP HERE
                ),
                size: Size(width, height),
              ),
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
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.transparent, width: 0),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
