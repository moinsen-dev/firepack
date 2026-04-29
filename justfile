set shell := ["bash", "-cu"]

# Default: list available recipes
default:
    @just --list

# Fetch Dart dependencies
deps:
    dart pub get

# Install firepack globally from this working tree.
# Path-source activations track the working tree — re-run after spec changes
# only if you want the activation snapshot to match HEAD. Day-to-day,
# `git pull` is enough; the binary always reads current source.
install: deps
    dart pub global activate --source path .
    @echo ""
    @echo "Make sure ~/.pub-cache/bin is in your PATH:"
    @echo '  export PATH="$PATH:$HOME/.pub-cache/bin"'

# Remove the global activation
uninstall:
    dart pub global deactivate firepack

# Compile a standalone native binary into ./build/firepack
build: deps
    mkdir -p build
    dart compile exe bin/firepack.dart -o build/firepack
    @echo "→ build/firepack"

# Run the CLI from source (e.g. `just run lint --spec example/firepack.yaml`)
run *ARGS:
    dart run bin/firepack.dart {{ARGS}}

# Run the test suite
test:
    dart test

# Static analysis
analyze:
    dart analyze

# Format check (no writes)
fmt-check:
    dart format --output=none --set-exit-if-changed .

# Apply formatting
fmt:
    dart format .

# Full CI-style check: format + analyze + tests + example smoke-test
check: fmt-check analyze test example-analyze

# Lint the example spec — sanity check the toolchain
lint-example:
    dart run bin/firepack.dart lint --spec example/firepack.yaml

# Render the example spec as Mermaid (stdout)
viz-example:
    dart run bin/firepack.dart viz --spec example/firepack.yaml

# Regenerate models / repos / storage paths into example/.
# Run after touching a generator or the example spec — the generated tree
# is checked in so `flutter analyze` works on a fresh clone.
example-regen:
    dart run bin/firepack.dart regen --target paths              --spec example/firepack.yaml --out example/lib/firepack/paths.dart
    dart run bin/firepack.dart regen --target firestore_provider --spec example/firepack.yaml --out example/lib/firepack/firestore_provider.dart
    dart run bin/firepack.dart regen --target models             --spec example/firepack.yaml --out example/lib/firepack/models
    dart run bin/firepack.dart regen --target repos              --spec example/firepack.yaml --out example/lib/firepack/repositories
    dart run bin/firepack.dart regen --target storage            --spec example/firepack.yaml --out example/lib/firepack/storage_paths.dart
    dart run bin/firepack.dart regen --target rules              --spec example/firepack.yaml --out example/firestore.rules
    dart run bin/firepack.dart regen --target indexes            --spec example/firepack.yaml --out example/firestore.indexes.json

# Pull Flutter deps for the example app
example-deps:
    cd example && flutter pub get

# Compile-smoke-test: prove generated code analyses cleanly inside a
# real Flutter app. Runs `flutter pub get` if the lockfile is missing.
example-analyze:
    cd example && [ -f pubspec.lock ] || flutter pub get
    cd example && flutter analyze

# Start the Firebase emulator suite for the example app (Firestore +
# Auth + UI). Run in a separate terminal — leaves the foreground.
# UI: http://localhost:4000  ·  Firestore: localhost:8080
#
# firebase-tools 15+ needs JDK 21+. Auto-pick brew's openjdk@21 if it
# exists so we don't force a system-wide JDK switch on the user. If you
# don't have it: `brew install openjdk@21`.
example-emulator-up:
    #!/usr/bin/env bash
    set -eu
    if [ -d /opt/homebrew/opt/openjdk@21 ]; then
      export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
      export PATH="$JAVA_HOME/bin:$PATH"
    fi
    cd example && firebase emulators:start

# Run the example app (Chrome) against the running emulator. Pair with
# `just example-emulator-up` in another terminal.
example-run:
    cd example && flutter run -d chrome

# Clean build artefacts and the pub cache for this package
clean:
    rm -rf .dart_tool build
    rm -f pubspec.lock
    @echo "cleaned: .dart_tool/, build/, pubspec.lock"

# Nuke everything clean + remove global activation
distclean: clean uninstall
