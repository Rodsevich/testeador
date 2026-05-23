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

/// A Pokémon fetched from PokéAPI on the server side.
abstract class Pokemon implements _i1.SerializableModel {
  Pokemon._({
    required this.name,
    required this.types,
    required this.spriteUrl,
  });

  factory Pokemon({
    required String name,
    required List<String> types,
    required String spriteUrl,
  }) = _PokemonImpl;

  factory Pokemon.fromJson(Map<String, dynamic> jsonSerialization) {
    return Pokemon(
      name: jsonSerialization['name'] as String,
      types: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['types'],
      ),
      spriteUrl: jsonSerialization['spriteUrl'] as String,
    );
  }

  String name;

  List<String> types;

  String spriteUrl;

  /// Returns a shallow copy of this [Pokemon]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Pokemon copyWith({
    String? name,
    List<String>? types,
    String? spriteUrl,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Pokemon',
      'name': name,
      'types': types.toJson(),
      'spriteUrl': spriteUrl,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _PokemonImpl extends Pokemon {
  _PokemonImpl({
    required String name,
    required List<String> types,
    required String spriteUrl,
  }) : super._(
         name: name,
         types: types,
         spriteUrl: spriteUrl,
       );

  /// Returns a shallow copy of this [Pokemon]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Pokemon copyWith({
    String? name,
    List<String>? types,
    String? spriteUrl,
  }) {
    return Pokemon(
      name: name ?? this.name,
      types: types ?? this.types.map((e0) => e0).toList(),
      spriteUrl: spriteUrl ?? this.spriteUrl,
    );
  }
}
