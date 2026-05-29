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

# Match an `import` declaration whose MODULE position is a forbidden module:
#   ^  optional leading space
#      zero+ import attributes:  @testable / @preconcurrency / @_implementationOnly / @objc(Foo)
#      `import`
#      optional import kind:     class / struct / enum / protocol / func / typealias / var
#      the forbidden module, followed by space, `.` (submodule import), or EOL.
# Requiring the module in MODULE position means a trailing comment like
# `import Foundation // SwiftUI` does NOT false-positive (BSD-grep ERE, macOS).
re='^[[:space:]]*(@[A-Za-z_][A-Za-z0-9_]*(\([^)]*\))?[[:space:]]+)*import[[:space:]]+((class|struct|enum|protocol|func|typealias|var)[[:space:]]+)?('"$modules"')([[:space:].]|$)'

status=0
for f in "$@"; do
  matches=$(grep -nE "$re" -- "$f" 2>/dev/null)
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
