import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';
import '../../../core/enums/modulo_enum.dart';

/// Selector de módulo con dropdown estilizado
class ModuleSelector extends StatelessWidget {
  final ModuloEnum selectedModule;
  final ValueChanged<ModuloEnum?> onModuleChanged;
  final List<ModuloEnum>? availableModules;

  const ModuleSelector({
    super.key,
    required this.selectedModule,
    required this.onModuleChanged,
    this.availableModules,
  });

  @override
  Widget build(BuildContext context) {
    final modules = availableModules ?? [
      ModuloEnum.servicios,
      ModuloEnum.equipos,
      ModuloEnum.inspecciones,
      ModuloEnum.financiero,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: WorkflowDesignConstants.spacing,
        vertical: WorkflowDesignConstants.spacingSm,
      ),
      decoration: WorkflowTheme.cardDecoration(),
      child: Row(
        children: [
          Icon(
            Icons.widgets_outlined,
            size: WorkflowDesignConstants.iconMd,
            color: WorkflowTheme.primaryPurple,
          ),
          const SizedBox(width: WorkflowDesignConstants.spacingSm),
          Text(
            'Módulo:',
            style: WorkflowTheme.bodyTextSecondary,
          ),
          const SizedBox(width: WorkflowDesignConstants.spacingSm),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ModuloEnum>(
                value: selectedModule,
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: WorkflowTheme.primaryPurple,
                ),
                style: WorkflowTheme.bodyText.copyWith(
                  fontWeight: WorkflowDesignConstants.fontSemiBold,
                ),
                items: modules.map((module) {
                  return DropdownMenuItem<ModuloEnum>(
                    value: module,
                    child: Text(_getModuleName(module)),
                  );
                }).toList(),
                onChanged: onModuleChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getModuleName(ModuloEnum module) {
    switch (module) {
      case ModuloEnum.servicios:
        return 'Servicios';
      case ModuloEnum.equipos:
        return 'Equipos';
      case ModuloEnum.inspecciones:
        return 'Inspecciones';
      case ModuloEnum.financiero:
        return 'Financiero';
      default:
        return module.displayName;
    }
  }
}
