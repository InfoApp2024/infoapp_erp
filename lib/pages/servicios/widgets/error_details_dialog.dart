import 'package:flutter/material.dart';

class ErrorDetailsDialog extends StatelessWidget {
  final String title;
  final String details;

  const ErrorDetailsDialog({
    super.key,
    required this.title,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: SelectableText(details)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
