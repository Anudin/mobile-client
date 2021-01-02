import 'package:flutter/foundation.dart';

@immutable
class Alias {
  final String alias;
  final String URL;
  final String position;

  Alias(this.alias, this.URL, [this.position]);

  Alias copyWith({String alias, String URL, String position}) => Alias(
        alias ?? this.alias,
        URL ?? this.URL,
        position ?? this.position,
      );
}
