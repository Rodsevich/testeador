/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'package:pokebattle_serverpod_client/src/protocol/protocol.dart' as _i2;

/// A registered trainer with their 6-Pokémon pool.
abstract class Player implements _i1.SerializableModel {
  Player._({
    required this.id,
    required this.name,
    required this.pokemonNames,
  });

  factory Player({
    required String id,
    required String name,
    required List<String> pokemonNames,
  }) = _PlayerImpl;

  factory Player.fromJson(Map<String, dynamic> jsonSerialization) {
    return Player(
      id: jsonSerialization['id'] as String,
      name: jsonSerialization['name'] as String,
      pokemonNames: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['pokemonNames'],
      ),
    );
  }

  String id;

  String name;

  List<String> pokemonNames;

  /// Returns a shallow copy of this [Player]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Player copyWith({
    String? id,
    String? name,
    List<String>? pokemonNames,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Player',
      'id': id,
      'name': name,
      'pokemonNames': pokemonNames.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _PlayerImpl extends Player {
  _PlayerImpl({
    required String id,
    required String name,
    required List<String> pokemonNames,
  }) : super._(
         id: id,
         name: name,
         pokemonNames: pokemonNames,
       );

  /// Returns a shallow copy of this [Player]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Player copyWith({
    String? id,
    String? name,
    List<String>? pokemonNames,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      pokemonNames: pokemonNames ?? this.pokemonNames.map((e0) => e0).toList(),
    );
  }
}
