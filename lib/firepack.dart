/// Public entry surface for firepack consumers.
///
/// Today the surface is small — parser, lint, viz. As the codegens
/// land we expose `Generators` here so external tooling can plug in
/// without hitting `src/`.
library;

export 'src/spec/spec.dart';
export 'src/spec/parser.dart';
export 'src/spec/lint.dart';
export 'src/viz/mermaid.dart';
export 'src/codegen/indexes_generator.dart';
export 'src/codegen/rules_generator.dart';
export 'src/codegen/dart_model_generator.dart';
export 'src/codegen/repository_generator.dart';
