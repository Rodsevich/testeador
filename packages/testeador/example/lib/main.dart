import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:testeador_example/app.dart';
import 'package:testeador_example/pokemon.dart';

void main() {
  runApp(
    TeamApp(api: PokeApi(Dio(), baseUrl: 'https://pokeapi.co/api/v2')),
  );
}
