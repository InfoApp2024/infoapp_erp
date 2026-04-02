import 'package:flutter/material.dart';

class SearchableSelectField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final List<String> items;
  final String? hint;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final void Function(String value)? onChanged;

  const SearchableSelectField({
    super.key,
    required this.label,
    required this.controller,
    required this.items,
    this.hint,
    this.prefixIcon,
    this.validator,
    this.onChanged,
  });

  @override
  State<SearchableSelectField> createState() => _SearchableSelectFieldState();
}

class _SearchableSelectFieldState extends State<SearchableSelectField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        final q = _normalizeKey(value.text);
        final filtered = <String>[];
        for (final it in widget.items) {
          if (q.isEmpty || _normalizeKey(it).contains(q)) {
            filtered.add(it);
          }
        }
        return filtered;
      },
      onSelected: (String selection) {
        widget.controller.text = selection;
        widget.onChanged?.call(selection);
      },
      fieldViewBuilder: (ctx, textCtrl, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textCtrl,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon:
                widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onChanged: widget.onChanged,
          validator: widget.validator,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 240,
                maxWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opt = options.elementAt(index);
                  return ListTile(
                    title: Text(opt),
                    dense: true,
                    onTap: () => onSelected(opt),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _normalizeKey(String v) {
    var s = v.trim();
    const repl = {
      'Á': 'A',
      'À': 'A',
      'Â': 'A',
      'Ä': 'A',
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'É': 'E',
      'È': 'E',
      'Ê': 'E',
      'Ë': 'E',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'Í': 'I',
      'Ì': 'I',
      'Î': 'I',
      'Ï': 'I',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'Ó': 'O',
      'Ò': 'O',
      'Ô': 'O',
      'Ö': 'O',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'Ú': 'U',
      'Ù': 'U',
      'Û': 'U',
      'Ü': 'U',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'Ñ': 'N',
      'ñ': 'n',
    };
    repl.forEach((a, b) => s = s.replaceAll(a, b));
    s = s.replaceAll(RegExp(r"\s+"), ' ');
    return s.toLowerCase();
  }
}
