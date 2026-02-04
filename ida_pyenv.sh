#!/usr/bin/env bash

set -euo pipefail

RED="\033[1;31m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
RESET="\033[0m"

info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }

DEFAULT_PYVER="3.13.8"
PYVER=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--verbose|-v] [PYVER]"
      echo "Example: $0 --verbose 3.13.8"
      exit 0
      ;;
    -*)
      warn "Unknown option: $1 (ignoring)"
      shift
      ;;
    *)
      # first non-option argument is PYVER
      if [[ -z "$PYVER" ]]; then
        PYVER="$1"
      else
        warn "Extra argument: $1 (ignoring)"
      fi
      shift
      ;;
  esac
done

PYVER="${PYVER:-$DEFAULT_PYVER}"

export PYTHON_CONFIGURE_OPTS="--enable-framework --enable-optimizations --with-lto"
export PYTHON_CFLAGS="-march=native -mtune=native"

command -v pyenv >/dev/null 2>&1 || error "pyenv not found."

info "Searching for IDA app bundles in /Applications..."
ida_candidates=()
while IFS= read -r line; do
  ida_candidates+=("$line")
done < <(printf "%s\n" /Applications/*IDA*.app /Applications/*ida*.app 2>/dev/null | sed '/\/Applications\/\*IDA\*/d' || true)

tmp=()
for p in "${ida_candidates[@]:-}"; do
  [[ -d "$p" ]] && tmp+=("$p")
done
ida_candidates=("${tmp[@]}")

if [ ${#ida_candidates[@]} -eq 0 ]; then
  while IFS= read -r -d $'\0' d; do
    ida_candidates+=("$d")
  done < <(find /Applications -maxdepth 3 -type d -name "*IDA*.app" -print0 2>/dev/null || true)
fi

[ ${#ida_candidates[@]} -gt 0 ] || error "No IDA app bundles found under /Applications."

best=""
best_ver=""

for p in "${ida_candidates[@]}"; do
  name="$(basename "$p")"
  ver="$(echo "$name" | grep -oE '[0-9]+(\.[0-9]+)+' || true)"
  if [[ -n "$ver" ]]; then
    if [[ -z "$best_ver" || "$(printf "%s\n%s\n" "$ver" "$best_ver" | sort -V | tail -n1)" == "$ver" ]]; then
      best="$p"
      best_ver="$ver"
    fi
  fi
done

if [[ -z "$best" ]]; then
  info "No numeric version found — picking most recent by modification time."
  newest=""
  newest_mtime=0
  for p in "${ida_candidates[@]}"; do
    mtime="$(stat -f %m "$p" 2>/dev/null || stat -c %Y "$p" 2>/dev/null || echo 0)"
    (( mtime > newest_mtime )) && { newest_mtime=$mtime; newest="$p"; }
  done
  best="$newest"
fi

IDA_APP="$best"
IDA_SWITCH="$IDA_APP/Contents/MacOS/idapyswitch"

info "Detected IDA: ${GREEN}$IDA_APP${RESET}"
[ -x "$IDA_SWITCH" ] || error "idapyswitch not found or not executable at $IDA_SWITCH"

if pyenv versions --bare | grep -qx "$PYVER"; then
  warn "Existing pyenv version $PYVER found — removing for clean rebuild."
  pyenv uninstall -f "$PYVER"
fi

info "Building python $PYVER..."
[ "$VERBOSE" = true ] && pyenv install --verbose "$PYVER" || pyenv install "$PYVER"

PYENV_PFX="$(pyenv prefix "$PYVER")"
shopt -s nullglob
LIBPY=("$PYENV_PFX"/lib/libpython${PYVER%.*}*.dylib); LIBPY="${LIBPY[0]:-}"
shopt -u nullglob

info "Build complete: $PYENV_PFX"
if [ -z "$LIBPY" ] || [ ! -f "$LIBPY" ]; then
  error "libpython dylib not found at $PYENV_PFX/lib/libpython${PYVER%.*}*.dylib"
fi

info "Switching IDA python version..."
"$IDA_SWITCH" --force-path "$LIBPY" || {
  warn "idapyswitch failed. Try manually:"
  echo "  \"$IDA_SWITCH\" --force-path \"$LIBPY\""
  error "Registration failed."
}

success "IDA successfully registered with Python $PYVER."
