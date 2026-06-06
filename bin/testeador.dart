import 'dart:io';

import 'package:testeador/src/capture/record_cli.dart';
import 'package:testeador/src/discovery/cli.dart';
import 'package:testeador/src/mcp/server.dart';

const _version = '0.3.0';

const _usage =
    '''
testeador $_version

Usage: dart run testeador <command> [options]
       testeador <command> [options]

Commands:
  mcp        Run the Model Context Protocol server over stdio.
  discover   List captured tests and (optionally) scaffold a TestFlow.
  record     Capture a running app's HTTP traffic and draft the missing
             contract tests (--backend web|native).

Top-level flags:
  --version, -V   Print the testeador version and exit.
  --help, -h      Show this help. Pass --help after a command for its options.
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln(_usage);
    return;
  }
  final command = args.first;
  final rest = args.skip(1).toList();

  switch (command) {
    case '-h':
    case '--help':
      stdout.writeln(_usage);
      return;
    case '-V':
    case '--version':
      stdout.writeln('testeador $_version');
      return;
    case 'mcp':
      await runServer(args: rest);
      return;
    case 'discover':
      exitCode = await runDiscoverCli(rest);
      return;
    case 'record':
      exitCode = await runRecordCli(rest);
      return;
    default:
      stderr
        ..writeln('Unknown command: $command')
        ..writeln(_usage);
      exitCode = 64;
  }
}
