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
import 'dart:async' as _i2;
import 'package:pokebattle_serverpod_client/src/protocol/auth_user.dart' as _i3;
import 'package:pokebattle_serverpod_client/src/protocol/battle.dart' as _i4;
import 'package:pokebattle_serverpod_client/src/protocol/player.dart' as _i5;
import 'package:pokebattle_serverpod_client/src/protocol/pokemon.dart' as _i6;
import 'protocol.dart' as _i7;

/// Auth endpoint exposed to clients as `client.auth`.
///
/// Demo-grade: passwords are kept in plaintext in memory and tokens are random
/// strings. The point of the example is the streaming endpoints downstream,
/// not real authentication.
/// {@category Endpoint}
class EndpointAuth extends _i1.EndpointRef {
  EndpointAuth(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'auth';

  /// Creates a new account and returns an [AuthUser] with a fresh token.
  _i2.Future<_i3.AuthUser> register(
    String name,
    String email,
    String password,
  ) => caller.callServerEndpoint<_i3.AuthUser>(
    'auth',
    'register',
    {
      'name': name,
      'email': email,
      'password': password,
    },
  );

  /// Authenticates an existing account, issuing a fresh token.
  _i2.Future<_i3.AuthUser> login(
    String email,
    String password,
  ) => caller.callServerEndpoint<_i3.AuthUser>(
    'auth',
    'login',
    {
      'email': email,
      'password': password,
    },
  );
}

/// Battles endpoint exposed to clients as `client.battles`.
///
/// Two streams: [battleAdded] (every new challenge) and
/// [battleUpdates] (updates to a specific battle). Both are fed by
/// [createBattle] via MessageCentral.
/// {@category Endpoint}
class EndpointBattles extends _i1.EndpointRef {
  EndpointBattles(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'battles';

  /// Persists a battle challenge and broadcasts on both channels.
  _i2.Future<_i4.Battle> createBattle(
    String challengerName,
    String opponentName,
    List<String> challengerTeam,
  ) => caller.callServerEndpoint<_i4.Battle>(
    'battles',
    'createBattle',
    {
      'challengerName': challengerName,
      'opponentName': opponentName,
      'challengerTeam': challengerTeam,
    },
  );

  /// Returns the battle with [id] or throws if unknown.
  _i2.Future<_i4.Battle> getBattle(String id) =>
      caller.callServerEndpoint<_i4.Battle>(
        'battles',
        'getBattle',
        {'id': id},
      );

  /// Snapshot of currently active battles.
  _i2.Future<List<_i4.Battle>> listBattles() =>
      caller.callServerEndpoint<List<_i4.Battle>>(
        'battles',
        'listBattles',
        {},
      );

  /// Emits each new battle as it is created.
  _i2.Stream<_i4.Battle> battleAdded() =>
      caller.callStreamingServerEndpoint<_i2.Stream<_i4.Battle>, _i4.Battle>(
        'battles',
        'battleAdded',
        {},
        {},
      );

  /// Emits updates to a specific battle [id].
  _i2.Stream<_i4.Battle> battleUpdates(String id) =>
      caller.callStreamingServerEndpoint<_i2.Stream<_i4.Battle>, _i4.Battle>(
        'battles',
        'battleUpdates',
        {'id': id},
        {},
      );
}

/// Players endpoint exposed to clients as `client.players`.
///
/// The streaming method [playerAdded] is the centerpiece: any client
/// subscribed to it receives every new player as soon as another client
/// calls [registerPlayer]. Fan-out is in-memory via MessageCentral
/// (`session.messages.postMessage` + `createStream`), no DB triggers needed.
/// {@category Endpoint}
class EndpointPlayers extends _i1.EndpointRef {
  EndpointPlayers(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'players';

  /// Persists a player and broadcasts a `playerAdded` event.
  _i2.Future<_i5.Player> registerPlayer(
    String name,
    List<String> pokemonNames,
  ) => caller.callServerEndpoint<_i5.Player>(
    'players',
    'registerPlayer',
    {
      'name': name,
      'pokemonNames': pokemonNames,
    },
  );

  /// Snapshot of currently registered players. Pair with [playerAdded] to
  /// initialise the lobby on subscribe.
  _i2.Future<List<_i5.Player>> listPlayers() =>
      caller.callServerEndpoint<List<_i5.Player>>(
        'players',
        'listPlayers',
        {},
      );

  /// Emits each new player as it is registered, until the client disconnects.
  _i2.Stream<_i5.Player> playerAdded() =>
      caller.callStreamingServerEndpoint<_i2.Stream<_i5.Player>, _i5.Player>(
        'players',
        'playerAdded',
        {},
        {},
      );
}

/// Server-side proxy to PokéAPI.
///
/// Going through the server (rather than letting the Flutter client hit
/// PokéAPI directly) keeps the client transport-uniform — every screen calls
/// `client.X.method(...)` — and lets us cache or rewrite the response later
/// without touching the UI.
/// {@category Endpoint}
class EndpointPokemon extends _i1.EndpointRef {
  EndpointPokemon(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'pokemon';

  /// Returns the Pokémon with [name] from PokéAPI.
  _i2.Future<_i6.Pokemon> getPokemon(String name) =>
      caller.callServerEndpoint<_i6.Pokemon>(
        'pokemon',
        'getPokemon',
        {'name': name},
      );
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i1.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i7.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    auth = EndpointAuth(this);
    battles = EndpointBattles(this);
    players = EndpointPlayers(this);
    pokemon = EndpointPokemon(this);
  }

  late final EndpointAuth auth;

  late final EndpointBattles battles;

  late final EndpointPlayers players;

  late final EndpointPokemon pokemon;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'auth': auth,
    'battles': battles,
    'players': players,
    'pokemon': pokemon,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
