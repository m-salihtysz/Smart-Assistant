import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Boş liste durumu: ikon, açıklama ve isteğe bağlı tek dokunuşluk eylem.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: pal.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: pal.subtle),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: pal.ink,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: pal.muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: pal.ink,
                  side: BorderSide(color: pal.ink.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
