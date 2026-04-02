import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';

/// Badge visual para mostrar propiedades de estados
/// Ejemplos: "Inicial", "Final", "Requiere Firma", "Bloquea Cierre"
class StateBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const StateBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  /// Badge para estado inicial
  factory StateBadge.initial() {
    return const StateBadge(
      label: 'Inicial',
      color: WorkflowTheme.stateInitial,
    );
  }

  /// Badge para estado final
  factory StateBadge.final_() {
    return const StateBadge(
      label: 'Final',
      color: WorkflowTheme.stateFinal,
    );
  }

  /// Badge para estados que requieren firma
  factory StateBadge.requiresSignature() {
    return StateBadge(
      label: 'Requiere Firma',
      color: WorkflowTheme.stateReview,
      icon: Icons.draw,
    );
  }

  /// Badge para estados que bloquean cierre
  factory StateBadge.blocksClosure() {
    return const StateBadge(
      label: 'Bloquea Cierre',
      color: WorkflowTheme.warning,
      icon: Icons.lock_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? WorkflowTheme.textSecondary;

    return Container(
      height: WorkflowDesignConstants.badgeHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: WorkflowDesignConstants.spacingSm,
        vertical: WorkflowDesignConstants.spacingXs,
      ),
      decoration: WorkflowTheme.badgeDecoration(badgeColor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: WorkflowDesignConstants.iconSm - 2,
              color: WorkflowTheme.background,
            ),
            const SizedBox(width: WorkflowDesignConstants.spacingXs),
          ],
          Text(
            label,
            style: WorkflowTheme.badge,
          ),
        ],
      ),
    );
  }
}
