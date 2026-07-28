import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:pokebattle_serverpod_flutter/data/pokemon_sprite_cache.dart';

/// Async-loaded square sprite for a Pokémon, served from
/// [PokemonSpriteCache]. Renders a Pokéball icon while the Future is in
/// flight or when the server returned an empty sprite URL.
class PokemonSprite extends StatefulWidget {
  /// Creates a [PokemonSprite] for the Pokémon named [name].
  const PokemonSprite({
    required this.name,
    required this.cache,
    this.size = 32,
    super.key,
  });

  /// The Pokémon name (e.g. `charizard`).
  final String name;

  /// Cache used to resolve [name] to a [Pokemon].
  final PokemonSpriteCache cache;

  /// Edge length of the rendered sprite.
  final double size;

  @override
  State<PokemonSprite> createState() => _PokemonSpriteState();
}

class _PokemonSpriteState extends State<PokemonSprite> {
  late Future<Pokemon> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.cache.get(widget.name);
  }

  @override
  void didUpdateWidget(PokemonSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name || oldWidget.cache != widget.cache) {
      _future = widget.cache.get(widget.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Pokemon>(
      future: _future,
      builder: (context, snapshot) {
        final url = snapshot.data?.spriteUrl ?? '';
        if (url.isEmpty) return _placeholder();
        return Image.network(
          url,
          height: widget.size,
          width: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _placeholder(),
        );
      },
    );
  }

  Widget _placeholder() => Icon(Icons.catching_pokemon, size: widget.size);
}

/// Horizontal row of [PokemonSprite]s separated by a small gap.
class PokemonSpriteRow extends StatelessWidget {
  /// Creates a row of sprites for [names].
  const PokemonSpriteRow({
    required this.names,
    required this.cache,
    this.size = 24,
    this.spacing = 4,
    super.key,
  });

  /// Pokémon names to render, in order.
  final List<String> names;

  /// Cache used by every sprite in the row.
  final PokemonSpriteCache cache;

  /// Sprite edge length.
  final double size;

  /// Gap between sprites.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: names
          .map((n) => PokemonSprite(name: n, cache: cache, size: size))
          .toList(),
    );
  }
}
