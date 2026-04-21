class Pokemon {
  final int id;
  final String name;
  final String imageUrl;
  final String firstAbilityName;

  Pokemon({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.firstAbilityName,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final abilities = json['abilities'] as List;
    final firstAbility = abilities.isNotEmpty
        ? abilities[0]['ability']['name'] as String
        : '';

    return Pokemon(
      id: json['id'] as int,
      name: json['name'] as String,
      imageUrl: json['sprites']['front_default'] as String,
      firstAbilityName: firstAbility,
    );
  }

  Map<String, dynamic> toJson() {
    // Note: restful-api.dev limits the string lengths occasionally causing 500
    // so we omit the imageUrl since PokeAPI sprites are predictable via ID.
    return {
      'p_id': id.toString(),
      'name': name,
      'firstAbilityName': firstAbilityName,
    };
  }

  factory Pokemon.fromTeamJson(Map<String, dynamic> json) {
    final pId = json['p_id'].toString();
    return Pokemon(
      id: int.parse(pId),
      name: json['name'] as String,
      imageUrl:
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$pId.png',
      firstAbilityName: json['firstAbilityName'] as String,
    );
  }
}

class Ability {
  final String name;
  final String effect;

  Ability({required this.name, required this.effect});

  factory Ability.fromJson(Map<String, dynamic> json) {
    final effectEntries = json['effect_entries'] as List;
    final effectEntry = effectEntries.firstWhere(
      (e) => e['language']['name'] == 'en',
      orElse: () => {'effect': 'No effect available'},
    );
    return Ability(
      name: json['name'] as String,
      effect: effectEntry['effect'] as String,
    );
  }
}
