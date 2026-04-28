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
  static const _supportedTargets = {'indexes', 'rules', 'models'};

  _RegenCommand() {
    argParser
      ..addOption(
        'target',
        abbr: 't',
        help: 'What to regenerate. Today: indexes, rules, models. '
            'Future: repos, types.',
        allowed: ['indexes', 'rules', 'models', 'repos', 'types'],
        defaultsTo: 'indexes',
      )
      ..addOption(
        'out',
        abbr: 'o',
        help: 'Output file (single-file targets) or directory '
            '(multi-file targets like models). "-" for stdout '
            '(single-file targets only).',
      )
      ..addOption(
        'collection',
        abbr: 'c',
        help: 'For multi-file targets, restrict to one collection '
            '(e.g. --collection errorReports). Empty = all.',
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

    // Multi-file target: models.
    if (target == 'models') {
      final outDir = (argResults!['out'] as String?) ?? 'lib/firepack/models';
      final filter = argResults!['collection'] as String?;
      final dir = Directory(outDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final files = generateAllDartModels(
        spec,
        sourceFile: argResults!['spec'] as String?,
      );
      var written = 0;
      files.forEach((fileName, content) {
        if (filter != null && filter.isNotEmpty) {
          // skip collections that don't match the filter (matches the
          // collection-name root, not the file-name)
          final inferredCollection = fileName.replaceAll('.dart', '');
          // crude — filter matches if it starts with inferredCollection-stem
          if (!filter.toLowerCase().startsWith(inferredCollection.replaceAll('_', ''))) {
            return;
          }
        }
        final fullPath = '$outDir/$fileName';
        File(fullPath).writeAsStringSync(content);
        written++;
      });
      stdout.writeln('firepack regen models: wrote $written file(s) into $outDir/');
      return 0;
    }

    // Single-file targets.
    String content;
    String defaultOut;
    switch (target) {
      case 'indexes':
        content = generateIndexesJson(spec);
        defaultOut = 'firestore.indexes.json';
      case 'rules':
        content = generateRulesFile(spec);
        defaultOut = 'firestore.rules';
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
