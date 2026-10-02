#!/usr/bin/env bash
# Create tools/verify/.venv with Python 3.11 and install requirements.txt.
# Usage (Git Bash, from anywhere): bash tools/verify/make_venv.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VENV="$HERE/.venv"

find_py311() {
  # 1. base interpreter of the project venv, if it is 3.11
  local pv="$ROOT/.venv/Scripts/python"
  [ -x "$pv" ] || pv="$ROOT/.venv/bin/python"
  if [ -x "$pv" ] || [ -x "$pv.exe" ]; then
    local base
    base="$("$pv" -c 'import sys; print(sys.base_prefix)' 2>/dev/null | tr -d '\r')" || base=""
    for cand in "$base/python.exe" "$base/bin/python3.11" "$base/bin/python3"; do
      if [ -n "$base" ] && [ -x "$cand" ] && "$cand" -c 'import sys; sys.exit(0 if sys.version_info[:2]==(3,11) else 1)' 2>/dev/null; then
        echo "$cand"; return 0
      fi
    done
  fi
  # 2. Windows py launcher
  if command -v py >/dev/null 2>&1 && py -3.11 -c 'import sys' >/dev/null 2>&1; then
    py -3.11 -c 'import sys; print(sys.executable)' | tr -d '\r'; return 0
  fi
  # 3. python3.11 on PATH
  if command -v python3.11 >/dev/null 2>&1; then command -v python3.11; return 0; fi
  return 1
}

PY="$(find_py311)" || { echo "make_venv.sh: no Python 3.11 found" >&2; exit 1; }
echo "Using Python 3.11: $PY"
if [ ! -d "$VENV" ]; then "$PY" -m venv "$VENV"; fi
VPY="$VENV/Scripts/python"; [ -x "$VPY" ] || [ -x "$VPY.exe" ] || VPY="$VENV/bin/python"
"$VPY" -m pip install --upgrade pip >/dev/null
"$VPY" -m pip install -r "$HERE/requirements.txt"
"$VPY" -c 'import pysdmx, lxml; print("pysdmx", pysdmx.__version__)'
