import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class AliasCubit extends HydratedCubit<BuiltMap<String, Alias>> {
  AliasCubit() : super(BuiltMap());

  bool isAvailable(String name) {
    return !state.containsKey(name);
  }

  void create(Alias alias) {
    // Validation logic should probably be handled outside of the data class
    assert(Alias.isValidName(alias.name) && Alias.isValidURL(alias.URL) && Alias.isValidPosition(alias.position));
    assert(isAvailable(alias.name));
    emit(
      state.rebuild((builder) => builder.addAll({alias.name: alias})),
    );
  }

  void update(Alias alias, Alias update) {
    assert(alias.name == update.name || isAvailable(alias.name));
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
    return true;
  }

  static bool isValidURL(String URL) {
    // TODO Implementation
    return true;
  }

  static bool isValidPosition(String position) {
    // TODO Implementation
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
