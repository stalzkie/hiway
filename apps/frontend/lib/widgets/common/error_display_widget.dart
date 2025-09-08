import 'package:flutter/material.dart';
import 'package:hiway_app/core/utils/error_messages.dart';

enum ErrorDisplayType { inline, card, banner }

class ErrorDisplayWidget extends StatelessWidget {
  final String error;
  final String? customMessage;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final VoidCallback? onDismiss;
  final ErrorDisplayType displayType;

  const ErrorDisplayWidget({
    super.key,
    required this.error,
    this.customMessage,
    this.margin,
    this.padding,
    this.onDismiss,
    this.displayType = ErrorDisplayType.inline,
  });

  factory ErrorDisplayWidget.inline({
    required String error,
    String? customMessage,
    EdgeInsets? margin,
    EdgeInsets? padding,
    VoidCallback? onDismiss,
  }) {
    return ErrorDisplayWidget(
      error: error,
      customMessage: customMessage,
      margin: margin,
      padding: padding,
      onDismiss: onDismiss,
      displayType: ErrorDisplayType.inline,
    );
  }

  factory ErrorDisplayWidget.card({
    required String error,
    String? customMessage,
    EdgeInsets? margin,
    EdgeInsets? padding,
    VoidCallback? onDismiss,
  }) {
    return ErrorDisplayWidget(
      error: error,
      customMessage: customMessage,
      margin: margin,
      padding: padding,
      onDismiss: onDismiss,
      displayType: ErrorDisplayType.card,
    );
  }

  factory ErrorDisplayWidget.banner({
    required String error,
    String? customMessage,
    EdgeInsets? margin,
    EdgeInsets? padding,
    VoidCallback? onDismiss,
  }) {
    return ErrorDisplayWidget(
      error: error,
      customMessage: customMessage,
      margin: margin,
      padding: padding,
      onDismiss: onDismiss,
      displayType: ErrorDisplayType.banner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorMessage =
        customMessage ?? ErrorMessages.getUserFriendlyMessage(error);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: theme.colorScheme.error.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
