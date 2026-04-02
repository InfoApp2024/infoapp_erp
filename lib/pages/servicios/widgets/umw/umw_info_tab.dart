import 'package:flutter/material.dart';

class UmwInfoTab extends StatelessWidget {
  final Widget content;

  const UmwInfoTab({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 0, // El form ya tiene sus propias card o inputs
        color: Colors.transparent,
        child: content,
      ),
    );
  }
}
