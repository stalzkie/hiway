import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/data/models/job_model.dart';
import 'dart:math' as math;

class JobCard extends StatelessWidget {
  final JobModel job;
  final VoidCallback? onTap;

  const JobCard({super.key, required this.job, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildDescription(),
              const SizedBox(height: 16),
              _buildSkillsRow(),
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Header ----------------

  Widget _buildHeader() {
    return Row(
      children: [
        _buildCompanyMark(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkColor,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.company,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (job.location.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(
                      job.location,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildMatchScore(),
      ],
    );
  }

  Widget _buildCompanyMark() {
    final hasLogo = (job.companyLogo != null && job.companyLogo!.trim().isNotEmpty);
    if (hasLogo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          height: 56,
          color: Colors.grey[50],
          child: Image.network(
            job.companyLogo!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackCompanyIcon(),
          ),
        ),
      );
    }
    return _fallbackCompanyIcon();
  }

  Widget _fallbackCompanyIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.secondaryColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Icon(Icons.business_outlined, color: AppTheme.primaryColor, size: 26),
    );
  }

  Widget _buildMatchScore() {
    final score = job.matchPercentage.clamp(0, 100);
    final color = _getScoreColor(score);

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(72, 72),
            painter: _CircularProgressPainter(
              progress: score / 100,
              color: color,
              strokeWidth: 6.0,
              backgroundColor: color.withValues(alpha: 0.1),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  'match',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.8),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Body ----------------

  Widget _buildDescription() {
    final text = job.description.isNotEmpty ? job.description : 'No description provided.';
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
        height: 1.5,
        letterSpacing: 0.1,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSkillsRow() {
    if (job.skills.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSkillChip(job.skills.first, isPrimary: true),
              ...job.skills.skip(1).take(2).map((s) => _buildSkillChip(s, isPrimary: false)),
              if (job.skills.length > 3) _buildMoreSkillsChip(job.skills.length - 3),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkillChip(String skill, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: isPrimary ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)) : null,
      ),
      child: Text(
        skill,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPrimary ? AppTheme.primaryColor : Colors.grey[700],
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMoreSkillsChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+$count more',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600]),
      ),
    );
  }

  // ---------------- Footer ----------------

  Widget _buildFooter() {
    return Row(
      children: [
        _buildSalaryPill(),
        const SizedBox(width: 8),
        _buildVerifiedPill(), // <-- NEW
        const Spacer(),
        if (job.isTrending) _buildTrendingBadge(),
      ],
    );
  }

  Widget _buildSalaryPill() {
    final salaryColor = _getSalaryColor();
    final icon = _getSalaryIcon();
    final trendText = _getSalaryTrendText();

    final label = job.salaryPeriod.isEmpty
        ? job.salaryRange
        : '${job.salaryRange}/${job.salaryPeriod}';

    return Tooltip(
      message: trendText,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: salaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: salaryColor.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: salaryColor),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: salaryColor),
          ],
        ),
      ),
    );
  }

  /// NEW: Verified pill with same UI style as salary pill
  Widget _buildVerifiedPill() {
    final c = AppTheme.successColor;
    return Tooltip(
      message: 'Verified job post',
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 16, color: c),
            const SizedBox(width: 6),
            const Text(
              'Verified',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.successColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 14, color: AppTheme.warningColor),
          const SizedBox(width: 4),
          Text(
            'Trending',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.warningColor),
          ),
        ],
      ),
    );
  }

  // ---------------- Logic helpers ----------------

  Color _getScoreColor(int score) {
    if (score >= 70) return AppTheme.successColor;
    if (score >= 50) return AppTheme.warningColor;
    if (score >= 30) return Colors.orange;
    return AppTheme.errorColor;
  }

  Color _getSalaryColor() {
    // Strip non-digits to handle "₱80,000", "80 000", etc.
    final numeric = job.salaryRange.replaceAll(RegExp(r'[^0-9]'), '');
    final salaryNum = int.tryParse(numeric) ?? 0;
    if (salaryNum >= 80000) return AppTheme.successColor;
    if (salaryNum >= 50000) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  IconData _getSalaryIcon() {
    final color = _getSalaryColor();
    if (color == AppTheme.successColor) return Icons.trending_up_rounded;
    if (color == AppTheme.warningColor) return Icons.trending_flat_rounded;
    return Icons.trending_down_rounded;
  }

  String _getSalaryTrendText() {
    final color = _getSalaryColor();
    if (color == AppTheme.successColor) return 'Above average salary';
    if (color == AppTheme.warningColor) return 'Average salary';
    return 'Below average salary';
  }
}

// ---------------- Painter ----------------

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
