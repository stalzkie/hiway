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
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoadingIndicator(size: 32, strokeWidth: 3),
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
