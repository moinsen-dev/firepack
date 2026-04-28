import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:firepack/firepack.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>(
    'firepack',
    'Spec-driven Firestore + Flutter codegen.',
  )
    ..addCommand(_LintCommand())
    ..addCommand(_VizCommand());
  // ..addCommand(_RegenCommand());   // T0DO once codegens land

  final exitCode = await runner.run(args) ?? 0;
  exit(exitCode);
}

abstract class _SpecCommand extends Command<int> {
  _SpecCommand() {
    argParser.addOption(
      'spec',
      abbr: 's',
      help: 'Path to firepack.yaml',
      defaultsTo: 'firepack.yaml',
    );
  }

  Spec readSpec() {
    final path = argResults!['spec'] as String;
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('firepack: spec file not found: $path');
      throw _CliError(2);
    }
    return FirepackParser().parse(
      file.readAsStringSync(),
      sourceName: path,
    );
  }
}

class _LintCommand extends _SpecCommand {
  @override
  String get name => 'lint';
  @override
  String get description => 'Validates the spec — orphan refs, dup indexes, …';

  @override
  Future<int> run() async {
    final spec = readSpec();
    final issues = lint(spec);
    if (issues.isEmpty) {
      stdout.writeln('firepack lint: ok '
          '(${spec.collections.length} collections, '
          '${spec.collections.values.fold(0, (s, c) => s + c.fields.length)} fields)');
      return 0;
    }
    for (final issue in issues) {
      stdout.writeln(issue);
    }
    stdout.writeln('firepack lint: ${issues.length} issue(s)');
    return 1;
  }
}

class _VizCommand extends _SpecCommand {
  _VizCommand() {
    argParser.addOption(
      'out',
      abbr: 'o',
      help: 'Output Mermaid file (default: stdout)',
    );
  }

  @override
  String get name => 'viz';
  @override
  String get description =>
      'Renders the spec as a Mermaid erDiagram (paste into Markdown).';

  @override
  Future<int> run() async {
    final spec = readSpec();
    final mermaid = renderMermaid(spec);
    final outPath = argResults!['out'] as String?;
    if (outPath == null) {
      stdout.writeln(mermaid);
    } else {
      File(outPath).writeAsStringSync(mermaid);
      stdout.writeln('firepack viz: wrote $outPath '
          '(${mermaid.length} chars)');
    }
    return 0;
  }
}

class _CliError implements Exception {
  final int exitCode;
  _CliError(this.exitCode);
}
