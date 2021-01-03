import 'package:flutter/foundation.dart';

@immutable
class Link {
  final String prefix;
  final String alias;
  final String position;

  Link(this.alias, [this.prefix, this.position]);

  // Only accept alphanumeric (latin) characters, hyphen, hash symbol and space
  static final forbiddenCharacters = RegExp('[^-\\#a-zA-Z\\d\\s]');

  factory Link.tryParse(String text) {
    if (forbiddenCharacters.hasMatch(text)) return null;

    final p1 = text.split('-').map((s) => s.trim()).toList();
    // Contains a prefix
    if (p1.length == 2) {
      final p2 = _extractValidPosition(p1[0]);
      return Link(p2[0], p1[0], p2.length == 2 ? p2[1] : null);
    }
    // Contains no prefix
    else if (p1.length == 1) {
      final p2 = _extractValidPosition(p1[0]);
      return Link(p2[0], null, p2.length == 2 ? p2[1] : null);
    }
    // Malformed
    else {
      return null;
    }
  }

  static List<String> _extractValidPosition(String link) {
    final index = link.indexOf(RegExp('\\s#[a-zA-Z\\d]+\$'));
    if (index != -1 && isValidPosition(link.substring(index))) {
      return [link.substring(0, index), link.substring(index + 1)];
    } else {
      return [link];
    }
  }

  static bool isValidPosition(String position) {
    return RegExp('#\\d+\$').hasMatch(position);
  }
}
