import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';

class InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isEmpty;

  const InfoCard({
    super.key,
    required this.label,
    required this.value,
    this.isEmpty = false,
  });

  factory InfoCard.empty(String label, String emptyText) {
    return InfoCard(label: label, value: emptyText, isEmpty: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmpty ? Colors.grey[50] : AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmpty
              ? Colors.grey[200]!
              : AppTheme.primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isEmpty ? Colors.grey[500] : AppTheme.darkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
