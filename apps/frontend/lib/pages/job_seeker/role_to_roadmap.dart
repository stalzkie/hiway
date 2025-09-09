// lib/pages/job_seeker/role_to_roadmap.dart
import 'package:flutter/material.dart';
import 'package:hiway_app/data/models/orchestrator_models.dart';
import 'package:hiway_app/data/services/service_factory.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';
import 'package:hiway_app/pages/job_seeker/roadmap.dart';
import 'package:hiway_app/pages/job_seeker/dashboard.dart'; // for fallback back-nav

class RoleToRoadmapScreen extends StatefulWidget {
  final String email;   // seeker email
  final bool force;     // recompute flag (default true to ensure generation)

  const RoleToRoadmapScreen({
    super.key,
    required this.email,
    this.force = true,
  });

  @override
  State<RoleToRoadmapScreen> createState() => _RoleToRoadmapScreenState();
}

class _RoleToRoadmapScreenState extends State<RoleToRoadmapScreen> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _svc = ServiceFactory.orchestrator;

  bool _loading = false;
  String? _error;

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const JobSeekerDashboard()),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final role = _ctrl.text.trim();

    // Show the note immediately upon clicking "Create Roadmap"
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Note: We are scraping the web and analyzing in real-time, so it may take some time. Thank you!',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final OrchestratorResponse resp = await _svc.runOrchestrator(
        email: widget.email,
        role: role,
        force: widget.force,
      );

      if (!mounted) return;

      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => JobSeekerRoadmap(
          email: widget.email,
          role: role,
          force: false,
          initialData: resp, // avoids an extra fetch
          title: 'Career Roadmap',
        ),
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.secondaryColor,
              AppTheme.primaryColor.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Header with back button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _handleBack,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Create Roadmap',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Centered input card
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    20 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _buildRoleCard(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.flag_rounded, color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'What role are you aiming for?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Example: “Data Scientist”, “Frontend Developer”, “Bookkeeper”, “Project Manager”.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ctrl,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter a role';
                if (v.trim().length < 2) return 'Role is too short';
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Target Role',
                hintText: 'e.g., Data Analyst',
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.6),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.route),
                label: Text(_loading ? 'Creating...' : 'Create Roadmap'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
