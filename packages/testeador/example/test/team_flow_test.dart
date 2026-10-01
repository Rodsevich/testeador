import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testeador/testeador.dart';
import 'package:testeador_example/app.dart';
import 'package:testeador_example/pokemon.dart';

/// The world: where the real PokéAPI lives.
final class PokeWorld {
  const PokeWorld(this.baseUrl);
  final String baseUrl;
}

/// Prepares the world. No mocks: if PokéAPI is down, the suite says so here
/// instead of failing on a mysterious empty screen later.
final class PokeFixture extends Fixture<PokeWorld> {
  @override
  Future<PokeWorld> load() async {
    const baseUrl = 'https://pokeapi.co/api/v2';
    await Dio().get<void>('$baseUrl/pokemon/pikachu');
    return const PokeWorld(baseUrl);
  }
}

/// A trainer: opens the app with her own Dio (so her curls are recorded) and
/// her own look.
final class Trainer extends UiActor<PokeWorld> {
  Trainer(String name, {required this.themeMode})
    : super(
        name: name,
        // Idle keep-alive sockets leave a 3 s fake-time timer behind, which
        // flutter_test reports as a pending timer.
        dio: Dio()
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => HttpClient()..idleTimeout = Duration.zero,
          ),
      );

  final ThemeMode themeMode;

  @override
  Future<Widget Function()> session(PokeWorld world) async =>
      () => TeamApp(
        api: PokeApi(dio, baseUrl: world.baseUrl),
        themeMode: themeMode,
      );
}

/// One user journey: a trainer builds the first slot of her team.
UiTestFlow<PokeWorld> buildMyTeam() {
  // Shared between steps through closure capture: steps never call the
  // camera, the flow photographs after each one.
  String? foundName;

  return UiTestFlow<PokeWorld>(
    name: 'build my team',
    knownDefects: {
      'RenderFlex overflowed':
          'The abilities row of the result card does not '
          'wrap, so it overflows on phone width. Visible in the photo',
    },
    steps: [
      (
        description: 'I open my team and it is empty',
        intent:
            'The team screen shows the message "No Pokémon yet. Add your '
            'first one!" and an "Add Pokémon" button, and no Pokémon cards.',
        body: (_, $) async {
          expect($('No Pokémon yet. Add your first one!'), findsOneWidget);
        },
      ),
      (
        description: 'I open the add screen',
        intent:
            'The "Add Pokémon" screen shows an empty name field and a '
            'Search button, with no error and no result card.',
        body: (_, $) async {
          await $('Add Pokémon').tap();
        },
      ),
      (
        description: 'I look up a name that does not exist',
        intent:
            'The message "No Pokémon called missingno" is shown in the '
            'error color under the Search button, and no result card appears.',
        body: (_, $) async {
          await $(#nameField).enterText('missingno');
          await $('Search').tap();
          await waitFor($, find.text('No Pokémon called missingno'));
        },
      ),
      (
        description: 'I look up Pikachu',
        intent:
            'A result card titled "pikachu #25" with type "electric" and '
            'an "Add to team" button is shown; the error message is gone.',
        body: (_, $) async {
          await $(#nameField).enterText('pikachu');
          await $('Search').tap();
          await waitFor($, find.text('pikachu #25'));
          foundName = 'pikachu';
        },
      ),
      (
        description: 'I add Pikachu to my team',
        intent:
            'Back on the team screen there is exactly one card, '
            '"pikachu #25" with "electric", and the empty-state message is '
            'gone.',
        body: (_, $) async {
          await $('Add to team').tap();
          expect($('$foundName #25'), findsOneWidget);
        },
      ),
    ],
  );
}

/// Real HTTP takes real time, and `flutter_test` runs on fake time: let the
/// real event loop turn between pumps until [finder] appears.
Future<void> waitFor(PatrolTester $, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await $.tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    // A real duration: Dio schedules a zero-delay timer on fake time.
    await $.tester.pump(const Duration(milliseconds: 50));
  }
  throw TimeoutException('$finder never appeared');
}

void main() {
  setUpAll(() async {
    await setUpEvidence();
    // flutter_test draws icons as empty squares unless their font is loaded.
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    // flutter_test answers every HTTP request with 400; this example talks
    // to the real PokéAPI, so switch that override off.
    HttpOverrides.global = null;
  });

  TestSuite(
    name: 'Team builder',
    entries: [
      TestSuite.entry<PokeWorld>(
        fixture: PokeFixture(),
        actors: [
          Trainer('ana', themeMode: ThemeMode.light),
          Trainer('ben', themeMode: ThemeMode.dark),
        ],
        flows: [buildMyTeam()],
      ),
    ],
  ).register();
}
