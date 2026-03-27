import 'package:flutter/material.dart';

/// Custom TextEditingController that parses Markdown syntax in real-time
/// and applies rich text styling via buildTextSpan.
/// It visualizes markdown syntax when focused, and visually hides it
/// (using fontSize: 0 and transparent color) making it WYSIWYG when unfocused.
class MarkdownHighlightController extends TextEditingController {
  bool hasFocus = false;

  /// Update the focus state from the outside (_NodeFocusWrapper in OutlinerNodeWidget)
  void setFocus(bool focused) {
    if (hasFocus != focused) {
      hasFocus = focused;
      // Trigger a visual update without changing the actual text
      notifyListeners();
    }
  }

  // Define regex constants for markdown elements
  static const String _headingPattern = r'^(#{1,3})\s+(.*)$';
  static const String _boldPattern = r'\*\*(.*?)\*\*';
  static const String _italicPattern = r'\*(.*?)\*|_(.*?)_';
  static const String _strikethroughPattern = r'~~(.*?)~~';
  static const String _codeBlockPattern = r'```([\s\S]*?)```';
  static const String _inlineCodePattern = r'`(.*?)`';

  // Combined Regex using Named Capture Groups for single-pass matching
  static final RegExp _markdownRegex = RegExp(
    '(?<heading>$_headingPattern)|'
    '(?<bold>$_boldPattern)|'
    '(?<italic>$_italicPattern)|'
    '(?<strikethrough>$_strikethroughPattern)|'
    '(?<codeblock>$_codeBlockPattern)|'
    '(?<code>$_inlineCodePattern)',
    multiLine: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final List<TextSpan> children = [];
    int lastMatchEnd = 0;

    // Default style (e.g., standard text)
    final TextStyle defaultStyle = style ?? const TextStyle();

    // The style applied to syntax markers (**, #, etc.)
    final TextStyle syntaxMarkerStyle = hasFocus
        ? defaultStyle.copyWith(color: Colors.grey.withValues(alpha: 0.5)) // Editing mode: faint gray
        : defaultStyle.copyWith(color: Colors.transparent, fontSize: 0, height: 0); // Preview mode: hidden

    // Find all markdown syntax matches in the text
    for (final RegExpMatch match in _markdownRegex.allMatches(text)) {
      // Add plain text before this match
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: defaultStyle,
        ));
      }

      final String matchedString = match.group(0)!;
      TextStyle contentStyle = defaultStyle;
      String prefix = '';
      String content = '';
      String suffix = '';

      if (match.namedGroup('heading') != null) {
        // Heading
        final int hashCount = match.group(2)!.length; // '##' -> length 2
        prefix = '${'#' * hashCount} ';
        content = match.group(3)!;
        suffix = '';

        double sizeMultiplier = 1.0;
        if (hashCount == 1) sizeMultiplier = 1.6;
        else if (hashCount == 2) sizeMultiplier = 1.3;
        else if (hashCount == 3) sizeMultiplier = 1.1;

        contentStyle = defaultStyle.copyWith(
          fontSize: (defaultStyle.fontSize ?? 14.0) * sizeMultiplier,
          fontWeight: FontWeight.bold,
        );
      } else if (match.namedGroup('bold') != null) {
        // Bold
        prefix = '**';
        suffix = '**';
        content = match.group(5)!;
        contentStyle = defaultStyle.copyWith(fontWeight: FontWeight.bold);
      } else if (match.namedGroup('italic') != null) {
        // Italic (*text* or _text_)
        prefix = matchedString.startsWith('_') ? '_' : '*';
        suffix = prefix;
        content = match.group(7) ?? match.group(8) ?? '';
        contentStyle = defaultStyle.copyWith(fontStyle: FontStyle.italic);
      } else if (match.namedGroup('strikethrough') != null) {
        // Strikethrough
        prefix = '~~';
        suffix = '~~';
        content = match.group(10)!;
        contentStyle = defaultStyle.copyWith(decoration: TextDecoration.lineThrough);
      } else if (match.namedGroup('codeblock') != null) {
        // Multi-line code block
        prefix = '```';
        suffix = '```';
        content = match.group(12)!;

        contentStyle = defaultStyle.copyWith(
          fontFamily: 'Courier',
          backgroundColor: Colors.grey.withValues(alpha: 0.1),
        );
      } else if (match.namedGroup('code') != null) {
        // Inline code
        prefix = '`';
        suffix = '`';
        content = match.group(14)!;
        
        contentStyle = defaultStyle.copyWith(
          fontFamily: 'Courier',
          backgroundColor: Colors.grey.withValues(alpha: 0.2),
        );
      }

      // Build the TextSpan sequence for this match
      children.add(TextSpan(text: prefix, style: syntaxMarkerStyle));
      children.add(TextSpan(text: content, style: contentStyle));
      children.add(TextSpan(text: suffix, style: syntaxMarkerStyle));

      lastMatchEnd = match.end;
    }

    // Add any remaining trailing text
    if (lastMatchEnd < text.length) {
      children.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: defaultStyle,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}
