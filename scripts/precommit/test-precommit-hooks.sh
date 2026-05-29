#!/usr/bin/env bash
# Regression tests for the local pre-commit hook scripts in scripts/precommit/.
#
# Each guard must REJECT (exit 1) known-bad input and PASS (exit 0) known-good
# input — including the multi-file case (a bad file batched with good ones must
# still be caught). Run via `make test-hooks`; wired into `make verify` so CI
# keeps the hooks honest. Pure shell + temp fixtures — no repo mutation.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

# assert_exit <expected-code> "<description>" <command> [args...]
assert_exit() {
  expected="$1"; shift
  desc="$1"; shift
  "$@" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$expected" ]; then
    pass=$((pass + 1))
    echo "  ✓ $desc"
  else
    fail=$((fail + 1))
    echo "  ✗ $desc — expected exit $expected, got $got"
  fi
}

echo "→ core-import-ban (§3 two-layer split)"
printf 'import Foundation\n\nstruct Pure {}\n'        > "$TMP/Good.swift"
printf 'import Foundation\nimport SwiftUI\n'           > "$TMP/BadUI.swift"
printf 'import HealthKit\n'                            > "$TMP/BadHK.swift"
printf 'import struct UIKit.UIEdgeInsets\n'            > "$TMP/BadSubmodule.swift"
printf 'import SwiftUIExtras\n'                        > "$TMP/Lookalike.swift"
assert_exit 0 "pure Foundation passes"                "$HERE/check-core-imports.sh" "$TMP/Good.swift"
assert_exit 1 "import SwiftUI rejected"               "$HERE/check-core-imports.sh" "$TMP/BadUI.swift"
assert_exit 1 "import HealthKit rejected"             "$HERE/check-core-imports.sh" "$TMP/BadHK.swift"
assert_exit 1 "import struct UIKit.X rejected"        "$HERE/check-core-imports.sh" "$TMP/BadSubmodule.swift"
assert_exit 0 "SwiftUIExtras lookalike passes"        "$HERE/check-core-imports.sh" "$TMP/Lookalike.swift"
assert_exit 1 "bad among good (multi-file) rejected"  "$HERE/check-core-imports.sh" "$TMP/Good.swift" "$TMP/BadUI.swift"

echo "→ swiftdata-unique-ban (§5 SwiftData/CloudKit)"
printf '@Model final class Foo {\n  var id: UUID?\n}\n'                      > "$TMP/GoodModel.swift"
printf '@Model final class Bar {\n  @Attribute(.unique) var id: UUID?\n}\n' > "$TMP/BadModel.swift"
assert_exit 0 "no unique constraint passes"           "$HERE/check-swiftdata-rules.sh" "$TMP/GoodModel.swift"
assert_exit 1 "@Attribute(.unique) rejected"          "$HERE/check-swiftdata-rules.sh" "$TMP/BadModel.swift"

echo "→ forbidden-paths (CONTRACT.md / *.xcodeproj)"
assert_exit 0 "no staged forbidden paths passes"      "$HERE/check-forbidden-paths.sh"
assert_exit 1 "CONTRACT.md rejected"                  "$HERE/check-forbidden-paths.sh" "CONTRACT.md"
assert_exit 1 "*.xcodeproj rejected"                  "$HERE/check-forbidden-paths.sh" "NeonSaga.xcodeproj/project.pbxproj"

# Note: swift-format lint itself is covered by the upstream `swift-format-lint`
# pre-commit hook (`swift format lint --strict`, which works multi-file on this
# toolchain — the S6b "multi-file no-op" was a misdiagnosis; the real false-green
# was a missing `--strict` + the hook never being git-installed). No wrapper to
# test here.

echo ""
echo "precommit hooks: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
