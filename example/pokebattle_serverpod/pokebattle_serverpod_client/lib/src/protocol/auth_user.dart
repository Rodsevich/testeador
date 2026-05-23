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

/// Authenticated trainer. Lasts only for the in-memory dev server.
abstract class AuthUser implements _i1.SerializableModel {
  AuthUser._({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
  });

  factory AuthUser({
    required String id,
    required String name,
    required String email,
    required String token,
  }) = _AuthUserImpl;

  factory AuthUser.fromJson(Map<String, dynamic> jsonSerialization) {
    return AuthUser(
      id: jsonSerialization['id'] as String,
      name: jsonSerialization['name'] as String,
      email: jsonSerialization['email'] as String,
      token: jsonSerialization['token'] as String,
    );
  }

  String id;

  String name;

  String email;

  String token;

  /// Returns a shallow copy of this [AuthUser]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AuthUser copyWith({
    String? id,
    String? name,
    String? email,
    String? token,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AuthUser',
      'id': id,
      'name': name,
      'email': email,
      'token': token,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _AuthUserImpl extends AuthUser {
  _AuthUserImpl({
    required String id,
    required String name,
    required String email,
    required String token,
  }) : super._(
         id: id,
         name: name,
         email: email,
         token: token,
       );

  /// Returns a shallow copy of this [AuthUser]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AuthUser copyWith({
    String? id,
    String? name,
    String? email,
    String? token,
  }) {
    return AuthUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      token: token ?? this.token,
    );
  }
}
