# pokebattle_serverpod_server

Serverpod backend for the PokéBattle streaming example.

This server runs in-memory: no Postgres, no Redis. State lives in
`lib/src/store/in_memory_store.dart` and is reset every time the server
restarts.

To start it:

    dart bin/main.dart

Stop with `Ctrl-C`.
