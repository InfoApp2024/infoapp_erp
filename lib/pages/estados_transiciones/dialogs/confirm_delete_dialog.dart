import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';

/// Diálogo de confirmación para eliminar estados o transiciones
class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? warningMessage;
  final VoidCallback onConfirm;
  final String confirmButtonText;
  final bool isDangerous;

  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    this.warningMessage,
    required this.onConfirm,
    this.confirmButtonText = 'Eliminar',
    this.isDangerous = true,
  });

  /// Factory para confirmar eliminación de estado
  factory ConfirmDeleteDialog.deleteState({
    required String stateName,
    required VoidCallback onConfirm,
    int? transitionCount,
  }) {
    return ConfirmDeleteDialog(
      title: 'Eliminar Estado',
      message: '¿Está seguro que desea eliminar el estado "$stateName"?',
      warningMessage: transitionCount != null && transitionCount > 0
          ? 'Este estado tiene $transitionCount transiciones asociadas que también serán eliminadas.'
          : null,
      onConfirm: onConfirm,
    );
  }

  /// Factory para confirmar eliminación de transición
  factory ConfirmDeleteDialog.deleteTransition({
    required String originState,
    required String destinationState,
    required VoidCallback onConfirm,
  }) {
    return ConfirmDeleteDialog(
      title: 'Eliminar Transición',
      message: '¿Está seguro que desea eliminar la transición "$originState → $destinationState"?',
      onConfirm: onConfirm,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WorkflowDesignConstants.radiusLg),
      ),
      child: Container(
        width: 400,
        decoration: WorkflowTheme.dialogDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
              decoration: BoxDecoration(
                color: isDangerous
                    ? WorkflowTheme.error
                    : WorkflowTheme.primaryPurple,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(WorkflowDesignConstants.radiusLg),
                  topRight: Radius.circular(WorkflowDesignConstants.radiusLg),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDangerous ? Icons.warning : Icons.help_outline,
                    color: Colors.white,
                    size: WorkflowDesignConstants.iconLg,
                  ),
                  const SizedBox(width: WorkflowDesignConstants.spacingMd),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: WorkflowDesignConstants.title,
                        fontWeight: WorkflowDesignConstants.fontBold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.all(WorkflowDesignConstants.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: WorkflowTheme.bodyText,
                  ),
                  
                  if (warningMessage != null) ...[
                    const SizedBox(height: WorkflowDesignConstants.spacing),
                    Container(
                      padding: const EdgeInsets.all(WorkflowDesignConstants.spacingMd),
                      decoration: BoxDecoration(
                        color: WorkflowTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          WorkflowDesignConstants.radiusMd,
                        ),
                        border: Border.all(
                          color: WorkflowTheme.warning.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: WorkflowTheme.warning,
                            size: WorkflowDesignConstants.iconMd,
                          ),
                          const SizedBox(width: WorkflowDesignConstants.spacingMd),
                          Expanded(
                            child: Text(
                              warningMessage!,
                              style: WorkflowTheme.caption.copyWith(
                                color: WorkflowTheme.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: WorkflowDesignConstants.spacingMd),
                  
                  Text(
                    'Esta acción no se puede deshacer.',
                    style: WorkflowTheme.caption.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(WorkflowDesignConstants.spacing),
              decoration: BoxDecoration(
                color: WorkflowTheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(WorkflowDesignConstants.radiusLg),
                  bottomRight: Radius.circular(WorkflowDesignConstants.radiusLg),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: WorkflowTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: WorkflowDesignConstants.spacingMd),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDangerous
                          ? WorkflowTheme.error
                          : WorkflowTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: WorkflowDesignConstants.spacingLg,
                        vertical: WorkflowDesignConstants.spacingMd,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          WorkflowDesignConstants.radiusMd,
                        ),
                      ),
                    ),
                    child: Text(confirmButtonText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
