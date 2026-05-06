#!/usr/bin/env bash
set -euo pipefail

info()    { echo -e "${CYAN}[INFO]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

if ! utils::resolve_target_user; then
    if [[ "$EUID" -eq 0 ]]; then
        error "Refusing to run as root without an invoking user. Run as your user, or use sudo from your account."
    fi
fi

run_as_target() {
    utils::run_as_target "$1"
}

DEFAULT_PYVER="3.14.2"
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
            echo "Example: $0 --verbose 3.14.2"
            exit 0
        ;;
        -*)
            warn "Unknown option: $1 (ignoring)"
            shift
        ;;
        *)
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

export PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto"
export PYTHON_CFLAGS="-march=native -mtune=native"

run_as_target 'command -v pyenv >/dev/null 2>&1' || error "pyenv not found for $TARGET_USER."

info "Searching for IDA installations..."
ida_candidates=()
for pattern in /opt/*IDA* /opt/*ida* /usr/local/*IDA* /usr/local/*ida* "$TARGET_HOME"/.local/*IDA* "$TARGET_HOME"/.local/*ida* "$TARGET_HOME"/IDA* "$TARGET_HOME"/*IDA* "$TARGET_HOME"/*ida*; do
    for p in $pattern; do
        [[ -e "$p" ]] && ida_candidates+=("$p")
    done
done

tmp=()
for p in "${ida_candidates[@]:-}"; do
    [[ -d "$p" ]] && tmp+=("$p")
done
ida_candidates=("${tmp[@]}")

if [ ${#ida_candidates[@]} -eq 0 ]; then
    while IFS= read -r -d $'\0' d; do
        ida_candidates+=("$d")
    done < <(find /opt /usr/local "$TARGET_HOME" -maxdepth 4 \( -type d -name "*IDA*" -o -type d -name "*ida*" \) -print0 2>/dev/null || true)
fi

[ ${#ida_candidates[@]} -gt 0 ] || error "No IDA installations found under /opt, /usr/local, or home."

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
        mtime="$(stat -c %Y "$p" 2>/dev/null || echo 0)"
        if (( mtime > newest_mtime )); then
            newest_mtime=$mtime
            newest="$p"
        fi
    done
    best="$newest"
fi

IDA_APP="$best"
IDA_SWITCH=""

if [ -n "$IDA_APP" ]; then
    found_switch="$(find "$IDA_APP" -maxdepth 6 -type f -name "idapyswitch" -executable -print -quit 2>/dev/null || true)"
    if [[ -n "$found_switch" ]]; then
        IDA_SWITCH="$found_switch"
    else
        found_switch="$(find "$IDA_APP" -maxdepth 6 -type f -iname "idapyswitch*" -print -quit 2>/dev/null || true)"
        IDA_SWITCH="$found_switch"
    fi
fi

info "Detected IDA: ${GREEN}$IDA_APP${RESET}"
[ -n "$IDA_SWITCH" ] || error "idapyswitch not found under $IDA_APP"
[ -x "$IDA_SWITCH" ] || warn "idapyswitch found but not executable: $IDA_SWITCH"

if run_as_target "pyenv versions --bare | grep -qx '$PYVER'"; then
    warn "Existing pyenv version $PYVER found — removing for clean rebuild."
    run_as_target "pyenv uninstall -f '$PYVER'"
fi

info "Building python $PYVER..."
if [ "$VERBOSE" = true ]; then
    run_as_target "pyenv install --verbose '$PYVER'"
else
    run_as_target "pyenv install '$PYVER'"
fi

PYENV_PFX="$(run_as_target "pyenv prefix '$PYVER'")"
LIBPY=""

shopt -s nullglob
candidates=( "$PYENV_PFX"/lib/libpython${PYVER%.*}*.so* "$PYENV_PFX"/lib/libpython${PYVER%.*}.so* )
shopt -u nullglob

if [ ${#candidates[@]} -gt 0 ]; then
    IFS=$'\n' sorted=($(printf '%s\n' "${candidates[@]}" | sort -V))
    LIBPY="${sorted[0]}"
else
    LIBPY="$(find "$PYENV_PFX/lib" -maxdepth 1 -type f -name "libpython${PYVER%.*}*.so*" -print | sort -V | head -n1 || true)"
fi

info "Build complete: $PYENV_PFX"
if [ -z "$LIBPY" ]; then
    error "libpython shared object not found under $PYENV_PFX/lib for python $PYVER"
fi

info "Switching IDA python version..."
if [ -x "$IDA_SWITCH" ]; then
    "$IDA_SWITCH" --force-path "$LIBPY" || {
        warn "idapyswitch failed. Try manually:"
        echo "  $IDA_SWITCH --force-path $LIBPY"
        error "Registration failed."
    }
else
    warn "idapyswitch is not executable: $IDA_SWITCH"
    echo "Try: chmod +x \"$IDA_SWITCH\" && \"$IDA_SWITCH\" --force-path \"$LIBPY\""
    error "Registration failed."
fi

success "IDA successfully registered with Python $PYVER."
