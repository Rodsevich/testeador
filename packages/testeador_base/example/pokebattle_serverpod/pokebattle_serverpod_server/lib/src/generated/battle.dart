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
import 'package:serverpod/serverpod.dart' as _i1;
import 'package:pokebattle_serverpod_server/src/generated/protocol.dart' as _i2;

/// A battle challenge from one trainer to another.
abstract class Battle
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  Battle._({
    required this.id,
    required this.challengerName,
    required this.opponentName,
    required this.challengerTeam,
  });

  factory Battle({
    required String id,
    required String challengerName,
    required String opponentName,
    required List<String> challengerTeam,
  }) = _BattleImpl;

  factory Battle.fromJson(Map<String, dynamic> jsonSerialization) {
    return Battle(
      id: jsonSerialization['id'] as String,
      challengerName: jsonSerialization['challengerName'] as String,
      opponentName: jsonSerialization['opponentName'] as String,
      challengerTeam: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['challengerTeam'],
      ),
    );
  }

  String id;

  String challengerName;

  String opponentName;

  List<String> challengerTeam;

  /// Returns a shallow copy of this [Battle]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Battle copyWith({
    String? id,
    String? challengerName,
    String? opponentName,
    List<String>? challengerTeam,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Battle',
      'id': id,
      'challengerName': challengerName,
      'opponentName': opponentName,
      'challengerTeam': challengerTeam.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Battle',
      'id': id,
      'challengerName': challengerName,
      'opponentName': opponentName,
      'challengerTeam': challengerTeam.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _BattleImpl extends Battle {
  _BattleImpl({
    required String id,
    required String challengerName,
    required String opponentName,
    required List<String> challengerTeam,
  }) : super._(
         id: id,
         challengerName: challengerName,
         opponentName: opponentName,
         challengerTeam: challengerTeam,
       );

  /// Returns a shallow copy of this [Battle]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Battle copyWith({
    String? id,
    String? challengerName,
    String? opponentName,
    List<String>? challengerTeam,
  }) {
    return Battle(
      id: id ?? this.id,
      challengerName: challengerName ?? this.challengerName,
      opponentName: opponentName ?? this.opponentName,
      challengerTeam:
          challengerTeam ?? this.challengerTeam.map((e0) => e0).toList(),
    );
  }
}
