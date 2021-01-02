import 'package:flutter/foundation.dart';

@immutable
class Alias {
  final String alias;
  final String URL;
  final String position;

  Alias(this.alias, this.URL, [this.position]);
}
