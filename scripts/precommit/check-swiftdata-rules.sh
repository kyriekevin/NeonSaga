#!/usr/bin/env bash
# §5 SwiftData + CloudKit — @Model classes in NeonSaga/Models/ must NOT use
# @Attribute(.unique): CloudKit's private DB rejects unique constraints, so the
# constraint would silently break the (dormant) CloudKit sync path. Enforce
# uniqueness at the insert site instead (FetchDescriptor → update / insert).
# See CLAUDE.md §5.
#
# The scan is attribute-span aware: it strips `//` line comments, then flags
# `.unique` anywhere inside an `@Attribute( … )` span — including when the
# attribute is split across lines. (Block comments / string literals containing
# a literal ".unique" inside an @Attribute(...) are a documented, vanishingly
# rare false-positive we accept rather than parse Swift in shell.)
set -u

status=0
for f in "$@"; do
  matches=$(awk '
    { raw = $0; sub(/\/\/.*/, "", raw); doc = doc raw "\n" }
    END {
      idx = 1
      while ((p = index(substr(doc, idx), "@Attribute(")) > 0) {
        start = idx + p - 1
        rest = substr(doc, start)
        # Walk to the MATCHING close paren (depth-aware) so nested parens inside
        # the attribute args — e.g. @Attribute(originalName: foo("id"), .unique) —
        # do not truncate the span at the first ")" and hide a later .unique.
        depth = 0
        cp = 0
        for (i = 1; i <= length(rest); i++) {
          ch = substr(rest, i, 1)
          if (ch == "(") depth++
          else if (ch == ")") {
            depth--
            if (depth == 0) { cp = i; break }
          }
        }
        if (cp == 0) break                       # unterminated span — stop
        span = substr(rest, 1, cp)
        if (span ~ /\.unique/) {
          pre = substr(doc, 1, start - 1)
          n = gsub(/\n/, "\n", pre) + 1          # 1-based line of the span start
          gsub(/[[:space:]]+/, " ", span)
          print n ": " span
        }
        idx = start + cp
      }
    }
  ' "$f" 2>/dev/null)
  if [ -n "$matches" ]; then
    echo "✗ $f — @Attribute(.unique) is forbidden (CloudKit rejects unique constraints, CLAUDE.md §5):"
    printf '%s\n' "$matches" | sed 's/^/      /'
    echo "      Enforce uniqueness at the insert site (FetchDescriptor → update / insert)."
    status=1
  fi
done
exit "$status"
