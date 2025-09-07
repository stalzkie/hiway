import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'dart:convert';

class ExperienceCard extends StatelessWidget {
  final String experience;

  const ExperienceCard({super.key, required this.experience});

  @override
  Widget build(BuildContext context) {
    final parts = _parseExperience(experience);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Position
          if (parts.title.isNotEmpty) ...[
            Text(
              'Position',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              parts.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Company Name
          if (parts.company.isNotEmpty) ...[
            Text(
              'Company Name',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.business_outlined,
                  size: 18,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    parts.company,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Year Experience
          if (parts.startDate.isNotEmpty || parts.endDate.isNotEmpty) ...[
            Text(
              'Duration',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateRange(parts.startDate, parts.endDate),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Description
          if (parts.description.isNotEmpty) ...[
            Text(
              'Description',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                parts.description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkColor,
                  height: 1.5,
                ),
              ),
            ),
          ] else if (parts.title.isEmpty && parts.company.isEmpty) ...[
            // Fallback for plain text
            Text(
              experience,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.darkColor,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _ExperienceParts _parseExperience(String experience) {
    String title = '';
    String company = '';
    String description = '';
    String startDate = '';
    String endDate = '';

    try {
      // Try to parse as JSON first
      final jsonData = jsonDecode(experience);
      if (jsonData is Map<String, dynamic>) {
        title =
            jsonData['title']?.toString() ??
            jsonData['position']?.toString() ??
            '';
        company = jsonData['company']?.toString() ?? '';
        description =
            jsonData['description']?.toString() ??
            jsonData['desc']?.toString() ??
            '';
        startDate =
            jsonData['start']?.toString() ??
            jsonData['startDate']?.toString() ??
            '';
        endDate =
            jsonData['end']?.toString() ??
            jsonData['endDate']?.toString() ??
            '';

        return _ExperienceParts(
          title: title,
          company: company,
          description: description,
          startDate: startDate,
          endDate: endDate,
        );
      }
    } catch (e) {
      // If JSON parsing fails, try to parse the visible format from the screenshot
    }

    // Handle the specific format shown in the screenshot
    // Looking for patterns like "end: 2025-02", "desc: null, start: 2023"
    final lines = experience.split('\n').map((line) => line.trim()).toList();

    for (final line in lines) {
      if (line.startsWith('end:')) {
        endDate = line.substring(4).trim();
      } else if (line.startsWith('start:')) {
        startDate = line.substring(6).trim();
      } else if (line.startsWith('title:')) {
        title = line.substring(6).trim();
      } else if (line.startsWith('company:')) {
        company = line.substring(8).trim();
      } else if (line.startsWith('desc:') && !line.contains('null')) {
        description = line.substring(5).trim();
      }
    }

    // Also try regex patterns for inline format like "desc: null, start: 2023"
    final inlinePatterns = [
      RegExp(r'end:\s*([^,}]+)'),
      RegExp(r'start:\s*([^,}]+)'),
      RegExp(r'title:\s*([^,}]+)'),
      RegExp(r'company:\s*([^,}]+)'),
      RegExp(r'desc:\s*([^,}]+)'),
    ];

    final fieldNames = ['end', 'start', 'title', 'company', 'desc'];
    final values = [endDate, startDate, title, company, description];

    for (int i = 0; i < inlinePatterns.length; i++) {
      final match = inlinePatterns[i].firstMatch(experience);
      if (match != null && values[i].isEmpty) {
        final value = match.group(1)?.trim() ?? '';
        if (value != 'null' && value.isNotEmpty) {
          switch (fieldNames[i]) {
            case 'end':
              endDate = value;
              break;
            case 'start':
              startDate = value;
              break;
            case 'title':
              title = value;
              break;
            case 'company':
              company = value;
              break;
            case 'desc':
              description = value;
              break;
          }
        }
      }
    }

    return _ExperienceParts(
      title: title,
      company: company,
      description: description,
      startDate: startDate,
      endDate: endDate,
    );
  }

  String _formatDateRange(String start, String end) {
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return end;
    if (end.isEmpty ||
        end.toLowerCase() == 'present' ||
        end.toLowerCase() == 'current') {
      return '$start - Present';
    }
    return '$start - $end';
  }
}

class _ExperienceParts {
  final String title;
  final String company;
  final String description;
  final String startDate;
  final String endDate;

  const _ExperienceParts({
    required this.title,
    required this.company,
    required this.description,
    required this.startDate,
    required this.endDate,
  });
}
