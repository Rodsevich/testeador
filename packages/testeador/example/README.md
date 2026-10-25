# testeador example — team builder

A two-screen Flutter app that adds Pokémon to a team using the real [PokéAPI](https://pokeapi.co). No mocks.

The showcase is [`test/team_flow_test.dart`](test/team_flow_test.dart). It has one `UiTestFlow` made of five steps. Each step states its `intent`, and the flow photographs the result. It runs once for each actor: `ana` uses the light theme and `ben` the dark one. It also carries one documented `knownDefects` entry, the overflowing abilities row, which you can see in `ana-i_look_up_pikachu.png`.

Run every command from this directory:

```bash
flutter test                                    # run the flow; photos land in test_evidence/runs/current/
dart run testeador_base:mirador review          # open http://127.0.0.1:4771 and judge new or drifted photos
S=i_open_my_team_and_it_is_empty,i_open_the_add_screen,i_look_up_a_name_that_does_not_exist,i_look_up_pikachu,i_add_pikachu_to_my_team
for a in ana ben; do dart run testeador_base:mirador promote --scenario build_my_team --actor $a --slugs $S; done   # accept as baseline
```

The mirador queue lists only captures that are `~new` or drifted. If the run matches the committed baseline in `test_evidence/baseline/`, there is nothing to review. To see the queue fill up, change `colorSchemeSeed` in `lib/app.dart` and run `flutter test` again. The run still passes, because drift never fails a run, and all 10 photos come back marked.
