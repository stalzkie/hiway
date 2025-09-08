import 'package:flutter/material.dart';
import 'package:hiway_app/widgets/employer/bottom_nav.dart';
import 'package:hiway_app/widgets/common/app_theme.dart';

class EmployerLayout extends StatefulWidget {
  final List<Widget> pages;
  final List<String> pageTitles;
  final int initialIndex;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;

  const EmployerLayout({
    super.key,
    required this.pages,
    required this.pageTitles,
    this.initialIndex = 0,
    this.appBar,
    this.floatingActionButton,
  });

  @override
  State<EmployerLayout> createState() => _EmployerLayoutState();
}

class _EmployerLayoutState extends State<EmployerLayout> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.appBar ??
          AppBar(
            title: Text(
              widget.pageTitles.isNotEmpty &&
                      _currentIndex < widget.pageTitles.length
                  ? widget.pageTitles[_currentIndex]
                  : 'Employer',
            ),
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.darkColor,
            elevation: 0,
            scrolledUnderElevation: 1,
          ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: widget.pages,
      ),
      bottomNavigationBar: EmployerBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

class EmployerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const EmployerAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.darkColor,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : null,
      actions: [
        ...?actions,
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: Icon(Icons.business),
                title: Text('Company Profile'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, String value) {
    switch (value) {
      case 'profile':
        // Navigate to profile page
        break;
      case 'settings':
        // Navigate to settings page
        break;
      case 'logout':
        _showLogoutDialog(context);
        break;
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Handle logout logic here
                // Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppTheme.darkColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkColor.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onActionPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onActionPressed,
                icon: const Icon(Icons.add),
                label: Text(actionText!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
