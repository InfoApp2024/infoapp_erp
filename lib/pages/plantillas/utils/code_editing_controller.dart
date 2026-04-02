import 'package:flutter/material.dart';

class CodeEditingController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];

    // Regex para diferentes componentes
    // 1. Tags HTML: <tag>, </tag>, <tag />
    // 2. Atributos: style="", class=""
    // 3. Comentarios: <!-- ... -->
    // 4. Variables/Tags del sistema: {{...}} o [...]
    final RegExp combinedRegex = RegExp(
      r'(<!--[\s\S]*?-->)|' // 1: Comentarios
      r'(<[^>]+>)|'        // 2: Tags HTML
      r'(\{\{[^}]+\}\})|'   // 3: Tags {{...}}
      r'(\[[^\]]+\])',      // 4: Tags [...]
      caseSensitive: false,
    );

    int lastMatchEnd = 0;

    combinedRegex.allMatches(text).forEach((match) {
      // Texto antes del match
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      final String matchText = match.group(0)!;

      if (match.group(1) != null) {
        // Comentario
        children.add(TextSpan(
          text: matchText,
          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ));
      } else if (match.group(2) != null) {
        // Tag HTML
        children.add(_highlightHtmlTag(matchText));
      } else if (match.group(3) != null || match.group(4) != null) {
        // Tag de sistema {{}} o []
        children.add(TextSpan(
          text: matchText,
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0xFFE3F2FD),
          ),
        ));
      }

      lastMatchEnd = match.end;
    });

    // Texto después del último match
    if (lastMatchEnd < text.length) {
      children.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return TextSpan(style: style, children: children);
  }

  TextSpan _highlightHtmlTag(String tag) {
    final List<TextSpan> parts = [];
    
    // Regex interna para separar el nombre del tag de los atributos
    // <(/?)([a-zA-Z0-9]+)([^>]*)>
    final RegExp tagPartsRegex = RegExp(r'<(/?[a-zA-Z0-9]+)([^>]*)>');
    final match = tagPartsRegex.firstMatch(tag);

    if (match != null) {
      parts.add(const TextSpan(text: '<', style: TextStyle(color: Colors.blueGrey)));
      
      // Nombre del tag (p, div, style, etc)
      parts.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(color: Color(0xFF800000), fontWeight: FontWeight.bold),
      ));

      // Atributos
      final String attrs = match.group(2) ?? '';
      if (attrs.isNotEmpty) {
        // Resaltar atributos: key="value"
        final RegExp attrRegex = RegExp(r'''([a-zA-Z0-9_-]+)(=)("[^"]*"|'[^']*')''');
        int lastAttrEnd = 0;
        
        attrRegex.allMatches(attrs).forEach((attrMatch) {
          if (attrMatch.start > lastAttrEnd) {
            parts.add(TextSpan(text: attrs.substring(lastAttrEnd, attrMatch.start)));
          }
          
          // Nombre atributo
          parts.add(TextSpan(
            text: attrMatch.group(1),
            style: const TextStyle(color: Color(0xFFCC0000)),
          ));
          
          // Signo igual
          parts.add(TextSpan(text: attrMatch.group(2), style: const TextStyle(color: Colors.black)));
          
          // Valor
          parts.add(TextSpan(
            text: attrMatch.group(3),
            style: const TextStyle(color: Color(0xFF0000FF)),
          ));
          
          lastAttrEnd = attrMatch.end;
        });
        
        if (lastAttrEnd < attrs.length) {
          parts.add(TextSpan(text: attrs.substring(lastAttrEnd)));
        }
      }

      parts.add(const TextSpan(text: '>', style: TextStyle(color: Colors.blueGrey)));
    } else {
      parts.add(TextSpan(text: tag, style: const TextStyle(color: Colors.blueGrey)));
    }

    return TextSpan(children: parts);
  }
}
