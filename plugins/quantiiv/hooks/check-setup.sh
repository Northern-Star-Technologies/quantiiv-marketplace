#!/bin/bash
set -euo pipefail

missing=()

# Check SDK installation
if ! node -e "require('@quantiiv-ai/sdk')" 2>/dev/null; then
  missing+=("SDK not installed globally (run /quantiiv:setup)")
fi

# Check environment variables
if [ -z "${QUANTIIV_API_KEY:-}" ]; then
  missing+=("QUANTIIV_API_KEY not set")
fi

if [ ${#missing[@]} -gt 0 ]; then
  issues=$(printf ', %s' "${missing[@]}")
  issues=${issues:2}
  echo "{\"systemMessage\": \"Quantiiv plugin: ${issues}. Run /quantiiv:setup to configure.\"}"
fi
