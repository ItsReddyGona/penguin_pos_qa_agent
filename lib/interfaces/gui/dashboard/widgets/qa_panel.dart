import 'package:flutter/material.dart';

/// Styled container card panel for dashboard content.
class QaPanel extends StatelessWidget {
  const QaPanel({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (titleWidget != null)
            titleWidget!
          else ...<Widget>[
            if (title != null)
              Text(
                title!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ],
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class QaSectionTitle extends StatelessWidget {
  const QaSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1E293B),
    ),
  );
}
