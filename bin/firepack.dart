import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:firepack/firepack.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>(
    'firepack',
    'Spec-driven Firestore + Flutter codegen.',
  )
    ..addCommand(_LintCommand())
    ..addCommand(_VizCommand())
    ..addCommand(_RegenCommand());

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

class _RegenCommand extends _SpecCommand {
  static const _supportedTargets = {'indexes'};

  _RegenCommand() {
    argParser
      ..addOption(
        'target',
        abbr: 't',
        help: 'What to regenerate. Today: indexes. '
            'Future: rules, models, repos, types.',
        allowed: ['indexes', 'rules', 'models', 'repos', 'types'],
        defaultsTo: 'indexes',
      )
      ..addOption(
        'out',
        abbr: 'o',
        help: 'Output file. "-" for stdout.',
      );
  }

  @override
  String get name => 'regen';

  @override
  String get description =>
      'Regenerates an artifact from the spec '
      '(indexes today, more targets coming via firepack ROADMAP).';

  @override
  Future<int> run() async {
    final target = argResults!['target'] as String;
    if (!_supportedTargets.contains(target)) {
      stderr.writeln(
        'firepack regen: target "$target" not yet implemented '
        '— see docs/ROADMAP.md.',
      );
      return 64; // EX_USAGE
    }

    final spec = readSpec();
    String content;
    String defaultOut;
    switch (target) {
      case 'indexes':
        content = generateIndexesJson(spec);
        defaultOut = 'firestore.indexes.json';
      default:
        return 64;
    }

    final outPath = (argResults!['out'] as String?) ?? defaultOut;
    if (outPath == '-') {
      stdout.write(content);
    } else {
      File(outPath).writeAsStringSync(content);
      stdout.writeln('firepack regen: wrote $outPath '
          '(${content.length} chars)');
    }
    return 0;
  }
}
