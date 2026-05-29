#!/usr/bin/env bash
# §3 two-layer split — NeonSagaCore must stay pure Swift.
#
# Forbidden imports in NeonSagaCore/Sources/NeonSagaCore/: SwiftUI, SwiftData,
# UIKit, HealthKit, CoreLocation. Anything testable on the Command Line Tools
# alone lives in Core; UI / persistence / health / location live in the
# NeonSaga app target. This invariant is load-bearing for the pure-logic
# custom-runner eval and `make build-core`. See CLAUDE.md §3.
set -u

modules='SwiftUI|SwiftData|UIKit|HealthKit|CoreLocation'
status=0
for f in "$@"; do
  # `import` statements that reference a forbidden module as a whole word.
  # Two-stage grep avoids \b / \s portability gaps in BSD grep (macOS).
  matches=$(grep -nE '^[[:space:]]*import[[:space:]]+' "$f" 2>/dev/null | grep -Ew "$modules")
  if [ -n "$matches" ]; then
    echo "✗ $f — forbidden import (NeonSagaCore must stay pure Swift, CLAUDE.md §3):"
    printf '%s\n' "$matches" | sed 's/^/      /'
    status=1
  fi
done

if [ "$status" -ne 0 ]; then
  echo ""
  echo "  Move SwiftUI / SwiftData / UIKit / HealthKit / CoreLocation code to the"
  echo "  NeonSaga app target (a protocol can live in Core; its concrete impl moves out)."
fi
exit "$status"
