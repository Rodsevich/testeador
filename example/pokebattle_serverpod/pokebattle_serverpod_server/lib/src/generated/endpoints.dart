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
import '../endpoints/admin_endpoint.dart' as _i2;
import '../endpoints/auth_endpoint.dart' as _i3;
import '../endpoints/battles_endpoint.dart' as _i4;
import '../endpoints/players_endpoint.dart' as _i5;
import '../endpoints/pokemon_endpoint.dart' as _i6;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'admin': _i2.AdminEndpoint()
        ..initialize(
          server,
          'admin',
          null,
        ),
      'auth': _i3.AuthEndpoint()
        ..initialize(
          server,
          'auth',
          null,
        ),
      'battles': _i4.BattlesEndpoint()
        ..initialize(
          server,
          'battles',
          null,
        ),
      'players': _i5.PlayersEndpoint()
        ..initialize(
          server,
          'players',
          null,
        ),
      'pokemon': _i6.PokemonEndpoint()
        ..initialize(
          server,
          'pokemon',
          null,
        ),
    };
    connectors['admin'] = _i1.EndpointConnector(
      name: 'admin',
      endpoint: endpoints['admin']!,
      methodConnectors: {
        'reset': _i1.MethodConnector(
          name: 'reset',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['admin'] as _i2.AdminEndpoint).reset(session),
        ),
        'seedPlayers': _i1.MethodConnector(
          name: 'seedPlayers',
          params: {
            'count': _i1.ParameterDescription(
              name: 'count',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['admin'] as _i2.AdminEndpoint).seedPlayers(
                session,
                params['count'],
              ),
        ),
        'seedBattle': _i1.MethodConnector(
          name: 'seedBattle',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['admin'] as _i2.AdminEndpoint).seedBattle(session),
        ),
      },
    );
    connectors['auth'] = _i1.EndpointConnector(
      name: 'auth',
      endpoint: endpoints['auth']!,
      methodConnectors: {
        'register': _i1.MethodConnector(
          name: 'register',
          params: {
            'name': _i1.ParameterDescription(
              name: 'name',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'password': _i1.ParameterDescription(
              name: 'password',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['auth'] as _i3.AuthEndpoint).register(
                session,
                params['name'],
                params['email'],
                params['password'],
              ),
        ),
        'login': _i1.MethodConnector(
          name: 'login',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'password': _i1.ParameterDescription(
              name: 'password',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['auth'] as _i3.AuthEndpoint).login(
                session,
                params['email'],
                params['password'],
              ),
        ),
      },
    );
    connectors['battles'] = _i1.EndpointConnector(
      name: 'battles',
      endpoint: endpoints['battles']!,
      methodConnectors: {
        'createBattle': _i1.MethodConnector(
          name: 'createBattle',
          params: {
            'challengerName': _i1.ParameterDescription(
              name: 'challengerName',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'opponentName': _i1.ParameterDescription(
              name: 'opponentName',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'challengerTeam': _i1.ParameterDescription(
              name: 'challengerTeam',
              type: _i1.getType<List<String>>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['battles'] as _i4.BattlesEndpoint).createBattle(
                    session,
                    params['challengerName'],
                    params['opponentName'],
                    params['challengerTeam'],
                  ),
        ),
        'getBattle': _i1.MethodConnector(
          name: 'getBattle',
          params: {
            'id': _i1.ParameterDescription(
              name: 'id',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['battles'] as _i4.BattlesEndpoint).getBattle(
                    session,
                    params['id'],
                  ),
        ),
        'listBattles': _i1.MethodConnector(
          name: 'listBattles',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['battles'] as _i4.BattlesEndpoint)
                  .listBattles(session),
        ),
        'battleAdded': _i1.MethodStreamConnector(
          name: 'battleAdded',
          params: {},
          streamParams: {},
          returnType: _i1.MethodStreamReturnType.streamType,
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['battles'] as _i4.BattlesEndpoint).battleAdded(
                session,
              ),
        ),
        'battleUpdates': _i1.MethodStreamConnector(
          name: 'battleUpdates',
          params: {
            'id': _i1.ParameterDescription(
              name: 'id',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          streamParams: {},
          returnType: _i1.MethodStreamReturnType.streamType,
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['battles'] as _i4.BattlesEndpoint).battleUpdates(
                session,
                params['id'],
              ),
        ),
      },
    );
    connectors['players'] = _i1.EndpointConnector(
      name: 'players',
      endpoint: endpoints['players']!,
      methodConnectors: {
        'registerPlayer': _i1.MethodConnector(
          name: 'registerPlayer',
          params: {
            'name': _i1.ParameterDescription(
              name: 'name',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'pokemonNames': _i1.ParameterDescription(
              name: 'pokemonNames',
              type: _i1.getType<List<String>>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['players'] as _i5.PlayersEndpoint).registerPlayer(
                    session,
                    params['name'],
                    params['pokemonNames'],
                  ),
        ),
        'listPlayers': _i1.MethodConnector(
          name: 'listPlayers',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['players'] as _i5.PlayersEndpoint)
                  .listPlayers(session),
        ),
        'playerAdded': _i1.MethodStreamConnector(
          name: 'playerAdded',
          params: {},
          streamParams: {},
          returnType: _i1.MethodStreamReturnType.streamType,
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['players'] as _i5.PlayersEndpoint).playerAdded(
                session,
              ),
        ),
      },
    );
    connectors['pokemon'] = _i1.EndpointConnector(
      name: 'pokemon',
      endpoint: endpoints['pokemon']!,
      methodConnectors: {
        'getPokemon': _i1.MethodConnector(
          name: 'getPokemon',
          params: {
            'name': _i1.ParameterDescription(
              name: 'name',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['pokemon'] as _i6.PokemonEndpoint).getPokemon(
                    session,
                    params['name'],
                  ),
        ),
      },
    );
  }
}
