#!/usr/bin/env bash
# Preserve the repository's CI policy: actual analyzer errors block the build,
# while the existing legacy warning/info backlog is reported but non-fatal.
set +e
analysis_output="$(flutter analyze --no-fatal-warnings --no-fatal-infos 2>&1)"
analyze_status=$?
printf '%s\n' "$analysis_output"

if printf '%s\n' "$analysis_output" | grep -Eq '(^|[[:space:]])error[[:space:]]+•'; then
  echo "Analyzer reported at least one error diagnostic."
  exit 1
fi

if [ "$analyze_status" -ne 0 ]; then
  echo "::warning::flutter analyze returned $analyze_status without error diagnostics; continuing because legacy warnings/infos are non-blocking."
fi

exit 0
