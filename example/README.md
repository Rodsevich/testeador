# testeador — Example

Demonstrates `testeador` with a Pokémon battle scenario using two actors and a real HTTP backend (`restful-api.dev`).

## Actors

| Actor | Type | Pokémon pool (6) |
|---|---|---|
| **Firesh** | Fire | Charizard, Arcanine, Flareon, Rapidash, Magmar, Ninetales |
| **Watersh** | Water | Blastoise, Vaporeon, Gyarados, Starmie, Lapras, Cloyster |

## Flows

| Flow | Tags | Description |
|---|---|---|
| Firesh — registers fire team | `fire`, `registration`, `smoke` | Firesh registers on the battle API with her 6 fire Pokémon and verifies visibility |
| Watersh — registers water team | `water`, `registration`, `smoke` | Watersh registers and verifies she can see Firesh |
| Firesh challenges Watersh to a battle | `battle`, `smoke` | Firesh selects 3 Pokémon and issues a challenge; Watersh views it and confirms she sees who she fights and with what |

## Running

```bash
# From the repo root:
dart run example/bin/run_tests.dart

# Only smoke tests:
dart run example/bin/run_tests.dart --include-tags smoke

# Verbose output:
dart run example/bin/run_tests.dart --verbose

# Only the battle flow:
dart run example/bin/run_tests.dart --include-flows "Firesh challenges Watersh to a battle"

# Don't exit with error code on failure (useful for local dev):
dart run example/bin/run_tests.dart --no-exit-on-failure
```

## Structure

```
example/
├── bin/
│   └── run_tests.dart              # CLI entry point
├── lib/
│   ├── data/
│   │   └── api_client.dart         # PokeApiClient + BattleApiClient (restful-api.dev)
│   └── domain/
│       ├── models.dart             # Pokemon, Player, Battle
│       └── repositories.dart      # PokemonRepository, BattleRepository
└── test/
    ├── actors.dart                 # FireshActor, WatershActor
    ├── fixtures/
    │   └── pokemon_fixture.dart    # Pre-loads Pokémon from PokéAPI
    └── flows/
        ├── fire_team_flow.dart     # Firesh registration flow
        ├── water_team_flow.dart    # Watersh registration flow
        └── battle_flow.dart        # Battle challenge flow
```

## No mocks

All HTTP calls go to real APIs:
- **PokéAPI** (`https://pokeapi.co/api/v2`) — Pokémon data
- **restful-api.dev** (`https://api.restful-api.dev`) — player registration and battles

`testeador` is for integration tests. Mocks defeat the purpose.
