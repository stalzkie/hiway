import 'package:flutter/material.dart';

class RoadmapStepDetail {
  final String label;
  final String? level;
  final List<Map<String, String>> resources;
  final List<Map<String, String>> certifications;
  final List<Map<String, String>> networkGroups;

  RoadmapStepDetail({
    required this.label,
    this.level,
    this.resources = const [],
    this.certifications = const [],
    this.networkGroups = const [],
  });
}

class RoadmapStepOverlay extends StatelessWidget {
  final RoadmapStepDetail step;

  const RoadmapStepOverlay({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    Widget buildDetailCard(Map<String, String> item) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.label_important,
                    size: 10,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              if (item['source'] != null) Text('Source: ${item['source']}'),
              if (item['url'] != null)
                InkWell(
                  onTap: () {
                    // You can use url_launcher to open the link
                  },
                  child: Text(
                    item['url']!,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ), // Space between modal and screen edge
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.flag,
                        size: 26,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.label,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  if (step.level != null)
                    Row(
                      children: [
                        Icon(
                          Icons.stars,
                          size: 18,
                          color: step.level == 'Beginner'
                              ? Colors.green
                              : step.level == 'Intermediate'
                              ? Colors.orange
                              : step.level == 'Hard'
                              ? Colors.red
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Level: ${step.level}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.menu_book, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Resources',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ...step.resources.map(buildDetailCard),
                  const SizedBox(height: 12),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium,
                        size: 20,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Certifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ...step.certifications.map(buildDetailCard),
                  const SizedBox(height: 12),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.groups, size: 20, color: Colors.teal),
                      const SizedBox(width: 8),
                      const Text(
                        'Network Groups',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ...step.networkGroups.map(buildDetailCard),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
