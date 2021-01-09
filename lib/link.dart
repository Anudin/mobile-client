import 'package:flutter/foundation.dart';

@immutable
class Link {
  final String prefix;
  final String alias;
  final String position;

  Link(this.alias, [this.prefix, this.position]);

  static final _aliasFormat = RegExp('^[-a-zA-Z\\d\\s]+');

  static final _positionFormat = RegExp('#.+\$');

  factory Link.tryParse(String text) {
    text = _autocorrect(text);
    // TODO Check alias format

    // Remove leading or trailing white space - artifacts from OCR
    final p1 = text.split('-').map((s) => s.trim()).toList();
    // Contains a prefix
    if (p1.length == 2) {
      final p2 = _extractValidPosition(p1[1]);
      return Link(p2[0].toLowerCase().trim(), p1[0], p2.length == 2 ? p2[1] : null);
    }
    // Contains no prefix
    else if (p1.length == 1) {
      final p2 = _extractValidPosition(p1[0]);
      return Link(p2[0].toLowerCase().trim(), null, p2.length == 2 ? p2[1] : null);
    }
    // Malformed
    else {
      return null;
    }
  }

  static List<String> _extractValidPosition(String link) {
    final index = link.indexOf(_positionFormat);
    // Whitespaces are introduced as an artifact of OCR, remove those
    final position = link.substring(index + 1).replaceAll(RegExp('\\s'), '');
    if (index != -1) {
      return [link.substring(0, index), position];
    } else {
      return [link];
    }
  }

  static String _autocorrect(String link) {
    return link.replaceAll('チ', '7').replaceAll('×', 'x');
  }

  static bool isValidPosition(String position) {
    // TODO Position should be URI compliant
    return true;
  }

  static bool isValidPageNumber(String pageNumber) {
    return RegExp('^\\d+\$').hasMatch(pageNumber);
  }

  // TODO Falsely requires leading zero for floating point numbers
  static bool isValidTimestamp(String timestamp) {
    if (timestamp.isNotEmpty) {
      final h = RegExp('\\d+\\.?\\d*h').allMatches(timestamp);
      final m = RegExp('\\d+\\.?\\d*m').allMatches(timestamp);
      final s = RegExp('\\d+\\.?\\d*s').allMatches(timestamp);
      if (h.length <= 1 || m.length <= 1 || s.length <= 1) {
        final hMatchLength = h.length == 1 ? h.first.end - h.first.start : 0;
        final mMatchLength = m.length == 1 ? m.first.end - m.first.start : 0;
        final sMatchLength = s.length == 1 ? s.first.end - s.first.start : 0;
        return hMatchLength + mMatchLength + sMatchLength == timestamp.length;
      }
    }
    return false;
  }

  static int convertTimestampToSeconds(String timestamp) {
    assert(isValidTimestamp(timestamp));
    final h = RegExp('\\d+\\.?\\d*h').allMatches(timestamp);
    final m = RegExp('\\d+\\.?\\d*m').allMatches(timestamp);
    final s = RegExp('\\d+\\.?\\d*s').allMatches(timestamp);
    if (h.length <= 1 || m.length <= 1 || s.length <= 1) {
      final hMatch = double.parse(h.length == 1 ? timestamp.substring(h.first.start, h.first.end - 1) : '0');
      final mMatch = double.parse(m.length == 1 ? timestamp.substring(m.first.start, m.first.end - 1) : '0');
      final sMatch = double.parse(s.length == 1 ? timestamp.substring(s.first.start, s.first.end - 1) : '0');
      return (hMatch * 3600 + mMatch * 60 + sMatch).round();
    }
    throw FormatException();
  }

  @override
  String toString() {
    return '(Prefix: $prefix, alias: $alias, position: $position)';
  }
}
