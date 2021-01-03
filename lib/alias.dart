import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class AliasCubit extends Cubit<BuiltMap<String, Alias>> {
  AliasCubit() : super(BuiltMap());

  bool isAvailable(String name) {
    return !state.containsKey(name);
  }

  void create(Alias alias) {
    assert(isAvailable(alias.name));
    emit(
      state.rebuild((builder) => builder.addAll({alias.name: alias})),
    );
  }

  void update(Alias alias, Alias update) {
    assert(isAvailable(alias.name));
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
}

@immutable
class Alias {
  final String name;
  final String URL;
  final String position;

  Alias(this.name, this.URL, [this.position]);

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
}
