import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mobile/levenshtein.dart';
import 'package:mobile/link.dart';

class AliasCubit extends HydratedCubit<BuiltMap<String, Alias>> {
  AliasCubit()
      : super(BuiltMap({
          'pdf': Alias('pdf', 'https://helpx.adobe.com/de/pdf/acrobat_reference.pdf', '15'),
          'wiki': Alias('wiki', 'wikipedia.com/wiki/', 'Bubble_sort#Variations'),
          'yt': Alias('yt', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', '1m30s'),
          'video': Alias('video', 'http://techslides.com/demos/sample-videos/small.ogv'),
          'audio': Alias('audio', 'https://file-examples-com.github.io/uploads/2017/11/file_example_WAV_2MG.wav'),
        }));

  bool isAvailable(String name) {
    return !state.containsKey(name);
  }

  void create(Alias alias) {
    // Validation logic should probably be handled outside of the data class
    assert(Alias.isValidName(alias.name) &&
        Alias.isValidURL(alias.URL) &&
        (alias.position == null || Alias.isValidPosition(alias.position)));
    assert(isAvailable(alias.name));
    emit(
      state.rebuild((builder) => builder.addAll({alias.name: alias})),
    );
  }

  void update(Alias alias, Alias update) {
    assert(alias.name == update.name || (Alias.isValidName(update.name) && isAvailable(update.name)));
    emit(
      state.rebuild((builder) {
        if (alias.name != update.name) builder.remove(alias.name);
        builder[update.name] = update;
      }),
    );
  }

  void delete(Alias alias) {
    emit(
      state.rebuild((builder) => builder.remove(alias.name)),
    );
  }

  Target resolve(Link link) {
    print('Trying to resolve link $link');
    final ocrKey = (link.prefix != null ? '${link.prefix}-' : '') + link.alias;

    // Fuzzy matches recognized text with possible candidates. Fuzzy matching is
    // more robust against mistakes from text recognition than literal matching.
    final distanceThreshold = 2;
    final lengthDifferenceThreshold = (distanceThreshold / 2).floor();
    var alias;
    var aliasDistance = distanceThreshold + 1;
    for (var key in state.keys) {
      if ((ocrKey.length - key.length).abs() > lengthDifferenceThreshold) continue;
      final distance = levenshtein(ocrKey, key, distanceThreshold);
      if (distance < aliasDistance) {
        aliasDistance = distance;
        alias = state[key];
        if (distance == 0) break;
      }
    }
    if (alias != null) {
      final position = link.position ?? alias.position;
      final target = Target(
          alias.URL,
          (position != null && Link.isValidTimestamp(position))
              ? '${Link.convertTimestampToSeconds(position)}'
              : position);
      print('Successfully resolved to $target');
      return target;
    } else {
      print('Failed to resolve $link');
      return null;
    }
  }

  @override
  BuiltMap<String, Alias> fromJson(Map<String, dynamic> json) {
    final state = BuiltMap.of(
      json.map((key, value) => MapEntry(key, Alias.fromJson(value))).cast<String, Alias>(),
    );
    print('State restored: $state');
    return state;
  }

  @override
  Map<String, dynamic> toJson(BuiltMap<String, Alias> state) {
    final json = state.map((key, value) => MapEntry(key, value.toJson())).toMap().cast<String, dynamic>();
    print('State encoded: $json');
    return json;
  }
}

@immutable
class Alias {
  final String name;
  final String URL;
  final String position;

  Alias(this.name, this.URL, [this.position]);

  Alias.fromJson(Map<String, dynamic> json)
      : name = json['name'].toString(),
        URL = json['URL'].toString(),
        position = json['position']?.toString();

  static bool isValidName(String alias) {
    // TODO Implementation
    return alias.isNotEmpty && !alias.contains(RegExp('[A-Z]'));
  }

  static bool isValidURL(String URL) {
    // TODO Implementation
    return URL.isNotEmpty;
  }

  static bool isValidPosition(String position) {
    return true;
  }

  Alias copyWith({String name, String URL, String position}) => Alias(
        name ?? this.name,
        URL ?? this.URL,
        position ?? this.position,
      );

  Map<String, dynamic> toJson() {
    final json = {
      'name': name,
      'URL': URL,
    };
    if (position != null) json.addAll({'position': position});
    print('Alias encoded: $json');
    return json;
  }
}

@immutable
class Target {
  final String URL;
  final String position;

  Target(this.URL, [this.position]);

  @override
  String toString() {
    return '(URL: $URL, position: $position)';
  }

  Map<String, dynamic> toJson() {
    return {
      'URL': URL,
      'position': position ?? '',
    };
  }
}
