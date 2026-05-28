import 'package:testeador/src/mcp/templates/actor.dart';
import 'package:testeador/src/mcp/templates/contract_test.dart';
import 'package:testeador/src/mcp/templates/fixture.dart';
import 'package:testeador/src/mcp/templates/flow_lasting.dart';
import 'package:testeador/src/mcp/templates/flow_transient.dart';
import 'package:testeador/src/mcp/templates/multidev_fleet.dart';
import 'package:testeador/src/mcp/templates/run_tests_cli.dart';

/// Catalog of every scaffolding template available to the MCP server.
///
/// The key is the slug used in MCP resource URIs (`testeador://templates/<key>`)
/// and as the discriminator in `scaffold_*` tool inputs. The value is the raw
/// template body — placeholder substitution is performed by [renderTemplate].
const Map<String, String> templates = {
  'actor': actorTemplate,
  'fixture': fixtureTemplate,
  'flow_lasting': flowLastingTemplate,
  'flow_transient': flowTransientTemplate,
  'run_tests_cli': runTestsCliTemplate,
  'contract_test': contractTestTemplate,
  'multidev_fleet': multidevFleetTemplate,
};

/// Substitutes `{{key}}` placeholders in [template] with [values].
///
/// Keys missing from [values] are left intact so callers can see what they
/// forgot to fill in. A missing key is therefore visible in the output, not
/// silently dropped.
String renderTemplate(String template, Map<String, String> values) {
  var out = template;
  values.forEach((k, v) {
    out = out.replaceAll('{{$k}}', v);
  });
  return out;
}
