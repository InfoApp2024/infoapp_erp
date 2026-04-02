import 'package:flutter/material.dart';
import '../design/workflow_theme.dart';
import '../design/design_constants.dart';

/// Selector de color mejorado con grid de colores predefinidos
class ColorPickerWidget extends StatelessWidget {
  final String? selectedColor;
  final ValueChanged<String> onColorSelected;
  final List<Color>? customColors;

  const ColorPickerWidget({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
    this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    final colors = customColors ?? WorkflowTheme.predefinedColors;

    return Wrap(
      spacing: WorkflowDesignConstants.spacingSm,
      runSpacing: WorkflowDesignConstants.spacingSm,
      children: colors.map((color) {
        final colorHex = WorkflowTheme.colorToHex(color);
        final isSelected = selectedColor == colorHex;

        return GestureDetector(
          onTap: () => onColorSelected(colorHex),
          child: AnimatedContainer(
            duration: WorkflowDesignConstants.animationFast,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                width: isSelected ? 3 : 1,
                color: isSelected
                    ? WorkflowTheme.textPrimary
                    : WorkflowTheme.border,
              ),
              boxShadow: isSelected
                  ? WorkflowDesignConstants.shadowMd
                  : WorkflowDesignConstants.shadowSm,
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    size: 18,
                    color: Colors.white,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}
