import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:uuid/uuid.dart';

class AliasCubit extends Cubit<BuiltMap<String, Alias>> {
  final uuidGenerator = Uuid();

  AliasCubit() : super(BuiltMap());

  String create(Alias alias) {
    final uuid = uuidGenerator.v4();
    emit(
      state.rebuild((builder) => builder.addAll({uuid: alias})),
    );
    return uuid;
  }

  void update(String uuid, Alias alias) {
    emit(
      state.rebuild((builder) => builder[uuid] = alias),
    );
  }

  void delete(String uuid) {
    emit(
      state.rebuild((builder) => builder.remove(uuid)),
    );
  }
}

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
