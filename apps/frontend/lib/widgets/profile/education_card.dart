import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'dart:convert';

class EducationCard extends StatelessWidget {
  final String education;

  const EducationCard({super.key, required this.education});

  @override
  Widget build(BuildContext context) {
    final parts = _parseEducation(education);

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
          // Degree
          if (parts.degree.isNotEmpty) ...[
            Text(
              'Degree',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              parts.degree,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // School
          if (parts.school.isNotEmpty) ...[
            Text(
              'School',
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
                  Icons.school_outlined,
                  size: 18,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    parts.school,
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

          // Year
          if (parts.year.isNotEmpty) ...[
            Text(
              'Year',
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
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  parts.year,
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

          // Description (if available)
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
          ] else if (parts.degree.isEmpty && parts.school.isEmpty) ...[
            // Fallback for plain text
            Text(
              education,
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

  _EducationParts _parseEducation(String education) {
    String degree = '';
    String school = '';
    String description = '';
    String year = '';

    try {
      // Try to parse as JSON first
      final jsonData = jsonDecode(education);
      if (jsonData is Map<String, dynamic>) {
        degree =
            jsonData['degree']?.toString() ??
            jsonData['course']?.toString() ??
            jsonData['program']?.toString() ??
            '';
        school =
            jsonData['school']?.toString() ??
            jsonData['university']?.toString() ??
            jsonData['institution']?.toString() ??
            '';
        description =
            jsonData['description']?.toString() ??
            jsonData['desc']?.toString() ??
            '';
        year =
            jsonData['year']?.toString() ??
            jsonData['graduationYear']?.toString() ??
            jsonData['endYear']?.toString() ??
            '';

        return _EducationParts(
          degree: degree,
          school: school,
          description: description,
          year: year,
        );
      }
    } catch (e) {
      // If JSON parsing fails, try to parse the visible format from the screenshot
    }

    // Handle the specific format shown in the screenshot
    // Looking for patterns like "year: 2026", "degree: BS in Computer Science, school: USLS"
    final lines = education.split('\n').map((line) => line.trim()).toList();

    for (final line in lines) {
      if (line.startsWith('year:')) {
        year = line.substring(5).trim();
      } else if (line.startsWith('degree:')) {
        // Handle "degree: BS in Computer Science, school: USLS" format
        final degreeAndSchool = line.substring(7).trim();
        if (degreeAndSchool.contains(', school:')) {
          final parts = degreeAndSchool.split(', school:');
          degree = parts[0].trim();
          if (parts.length > 1) {
            school = parts[1].trim();
          }
        } else {
          degree = degreeAndSchool;
        }
      } else if (line.startsWith('school:')) {
        school = line.substring(7).trim();
      } else if (line.startsWith('desc:') && !line.contains('null')) {
        description = line.substring(5).trim();
      }
    }

    // Also try regex patterns for inline format
    final inlinePatterns = [
      RegExp(r'year:\s*([^,}]+)'),
      RegExp(r'degree:\s*([^,}]+)'),
      RegExp(r'school:\s*([^,}]+)'),
      RegExp(r'desc:\s*([^,}]+)'),
    ];

    final fieldNames = ['year', 'degree', 'school', 'desc'];
    final values = [year, degree, school, description];

    for (int i = 0; i < inlinePatterns.length; i++) {
      final match = inlinePatterns[i].firstMatch(education);
      if (match != null && values[i].isEmpty) {
        final value = match.group(1)?.trim() ?? '';
        if (value != 'null' && value.isNotEmpty) {
          switch (fieldNames[i]) {
            case 'year':
              year = value;
              break;
            case 'degree':
              degree = value;
              break;
            case 'school':
              school = value;
              break;
            case 'desc':
              description = value;
              break;
          }
        }
      }
    }

    return _EducationParts(
      degree: degree,
      school: school,
      description: description,
      year: year,
    );
  }
}

class _EducationParts {
  final String degree;
  final String school;
  final String description;
  final String year;

  const _EducationParts({
    required this.degree,
    required this.school,
    required this.description,
    required this.year,
  });
}
