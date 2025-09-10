import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF352DC3);
  static const Color secondary = Color(0xFF291676);
  static const Color surface = Color(0xFFD9D9D9);
  static const Color dark = Color(0xFF292929);
}

class LoadingIndicator extends StatelessWidget {
  final double? size;
  final Color? color;
  final double strokeWidth;

  const LoadingIndicator({
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? AppColors.primary),
      ),
    );
  }
}

class LoadingWidget extends StatefulWidget {
  final Widget nextScreen;
  final String? splashText;
  final Duration duration;

  const LoadingWidget({
    super.key,
    required this.nextScreen,
    this.splashText,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _rotationController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Slide animation controller for the vector logo
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Fade animation controller for the text logo
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Subtle rotation animation for extra smoothness
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Slide animation with elastic bounce effect
    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1.2, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    // Smooth fade animation for text
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOutQuart),
    );

    // Subtle rotation animation
    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOutSine),
    );

    // Start animations
    _startAnimations();
  }

  void _startAnimations() async {
    // Start both animations with a slight delay for smoother effect
    await Future.delayed(const Duration(milliseconds: 200));

    // Start slide animation with bounce effect
    _slideController.forward();

    // Start subtle rotation animation
    _rotationController.repeat(reverse: true);

    // Start fade animation slightly after slide starts
    await Future.delayed(const Duration(milliseconds: 400));
    _fadeController.forward();

    // Wait for remaining duration
    await Future.delayed(
      Duration(milliseconds: widget.duration.inMilliseconds - 600),
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, _) => widget.nextScreen,
          transitionsBuilder: (context, animation, _, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutQuart,
                    ),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([
                _slideController,
                _rotationController,
              ]),
              builder: (context, child) {
                return SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                      CurvedAnimation(
                        parent: _slideController,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Image.asset(
                        'assets/images/hiway-logo.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _fadeController,
                          curve: Curves.easeOutQuart,
                        ),
                      ),
                );
              },
            ),

            if (widget.splashText != null) ...[
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  widget.splashText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? loadingText;
  final Color? overlayColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.loadingText,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [child, if (isLoading) _buildLoadingOverlay(context)],
    );
  }

  Widget _buildLoadingOverlay(BuildContext context) {
    return Container(
      color: overlayColor ?? Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoadingIndicator(size: 24, strokeWidth: 2),
              if (loadingText != null) ...[
                const SizedBox(height: 16),
                Text(
                  loadingText!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.dark,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final double? width;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderRadius? borderRadius;
  final bool isPrimary;

  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.width,
    this.height = 48.0,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !isLoading && onPressed != null;

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getBackgroundColor(isEnabled),
          foregroundColor: _getForegroundColor(),
          disabledBackgroundColor: AppColors.surface.withValues(alpha: 0.6),
          disabledForegroundColor: AppColors.dark.withValues(alpha: 0.4),
          elevation: isPrimary && isEnabled ? 2 : 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(12),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading ? _buildLoadingContent() : child,
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isEnabled) {
    if (backgroundColor != null) return backgroundColor!;
    if (!isEnabled) return AppColors.surface.withValues(alpha: 0.6);
    return isPrimary ? AppColors.primary : Colors.white;
  }

  Color _getForegroundColor() {
    if (foregroundColor != null) return foregroundColor!;
    return isPrimary ? Colors.white : AppColors.primary;
  }

  Widget _buildLoadingContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LoadingIndicator(
          size: 20,
          strokeWidth: 2.5,
          color: _getForegroundColor(),
        ),
        const SizedBox(width: 8),
        Text(
          'Loading...',
          style: TextStyle(
            color: _getForegroundColor(),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
