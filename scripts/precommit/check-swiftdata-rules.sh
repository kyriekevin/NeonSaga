#!/usr/bin/env bash
# §5 SwiftData + CloudKit — @Model classes in NeonSaga/Models/ must NOT use
# @Attribute(.unique): CloudKit's private DB rejects unique constraints, so the
# constraint would silently break the (dormant) CloudKit sync path. Enforce
# uniqueness at the insert site instead (FetchDescriptor → update / insert).
# See CLAUDE.md §5.
set -u

status=0
for f in "$@"; do
  matches=$(grep -nE '@Attribute\([^)]*\.unique' "$f" 2>/dev/null)
  if [ -n "$matches" ]; then
    echo "✗ $f — @Attribute(.unique) is forbidden (CloudKit rejects unique constraints, CLAUDE.md §5):"
    printf '%s\n' "$matches" | sed 's/^/      /'
    echo "      Enforce uniqueness at the insert site (FetchDescriptor → update / insert)."
    status=1
  fi
done
exit "$status"
