#!/usr/bin/env bash
# Island's offline gate. Everything here runs without a compositor, so it is
# safe to run before a commit and in CI.
#
#   scripts/check.sh          # run every check
#
# Exit status is 0 only when every hard check passes. Lint *warnings* are
# reported but not fatal: they are almost all "unqualified access" noise from
# qmllint's static analysis and cleaning them would mean adding ids that QML
# does not need. Lint *errors* are fatal.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root" || exit 1

fail=0
hard() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=1; }
pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
note() { printf '  \033[90m..\033[0m   %s\n' "$1"; }

# A file list used by the grep gates. Bounded to QML sources.
mapfile -t qml_files < <(find island -name '*.qml' | sort)
mapfile -t design_files < <(
  find island -name '*.qml' \
    ! -path 'island/config/Theme.qml' \
    ! -path 'island/config/Config.qml' \
    | sort
)

echo "Island checks ($root)"

# --- 1. syntax / type check ---------------------------------------------------
# Arch ships Qt5's qmllint at /usr/bin and Qt6's under /usr/lib/qt6/bin, and the
# Qt5 one cannot parse this code at all. Pick the Qt6 binary explicitly.
lint=""
for candidate in "${QMLINT:-}" qmllint6 /usr/lib/qt6/bin/qmllint; do
  [ -n "$candidate" ] || continue
  command -v "$candidate" >/dev/null 2>&1 || continue
  version=$("$candidate" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
  case "$version" in 6.*) lint=$candidate; break ;; esac
done

if [ -z "$lint" ]; then
  hard "qmllint 6 not found (set QMLINT=/path/to/qmllint)"
else
  lint_out=$("$lint" --version >/dev/null 2>&1; for f in "${qml_files[@]}"; do "$lint" "$f" 2>&1; done)
  lint_errors=$(printf '%s\n' "$lint_out" | grep -c '^Error')
  lint_warnings=$(printf '%s\n' "$lint_out" | grep -c '^Warning')
  if [ "$lint_errors" -gt 0 ]; then
    printf '%s\n' "$lint_out" | grep '^Error' | sed 's/^/       /'
    hard "qmllint reported $lint_errors error(s)"
  else
    pass "qmllint: no errors ($lint_warnings warnings, non-fatal)"
  fi
fi

# --- 2. palette lives in Theme.qml only --------------------------------------
# Config.qml is exempt too, but it holds personal settings (mounts, outputs),
# never colours — the exemption exists so the check does not fire on a comment.
if hits=$(grep -rnE '#[0-9a-fA-F]{3,8}\b' "${design_files[@]}" 2>/dev/null); then
  printf '%s\n' "$hits" | sed 's/^/       /'
  hard "hex colour outside config/Theme.qml"
else
  pass "no hex colours outside config/Theme.qml"
fi

# --- 3. type sizes come from the four Txt variants ---------------------------
if hits=$(grep -rnE 'pixelSize:[[:space:]]*[0-9]' "${design_files[@]}" 2>/dev/null); then
  printf '%s\n' "$hits" | sed 's/^/       /'
  hard "literal pixelSize outside Theme.qml (use Txt variants or Theme tokens)"
else
  pass "no literal pixelSize outside Theme.qml"
fi

if hits=$(grep -rnE '^[[:space:]]*Text \{' island --include='*.qml' \
          | grep -v 'island/components/Txt.qml' 2>/dev/null); then
  printf '%s\n' "$hits" | sed 's/^/       /'
  hard "raw Text item outside components/Txt.qml"
else
  pass "all text goes through components/Txt.qml"
fi

# --- 4. no always-on animation or effect layers ------------------------------
if hits=$(grep -rn 'Animation\.Infinite' island --include='*.qml' 2>/dev/null); then
  printf '%s\n' "$hits" | sed 's/^/       /'
  hard "Animation.Infinite (the idle bar must be able to reach 0% CPU)"
else
  pass "no Animation.Infinite"
fi

if hits=$(grep -rnE 'DropShadow|BoxShadow|FastBlur|layer\.effect|MultiEffect|ShaderEffect' \
          island --include='*.qml' 2>/dev/null); then
  printf '%s\n' "$hits" | sed 's/^/       /'
  hard "shadow / effect API (design is flat fills only)"
else
  pass "no shadow or effect layers"
fi

# --- 5. the health panel stays tickless --------------------------------------
# The panel is painted only while it is open; a Timer there would keep the
# shell awake after it closes. Samples advance from service signals instead.
if hits=$(grep -nE '^[[:space:]]*Timer \{' island/modules/HealthPanel.qml 2>/dev/null); then
  printf '%s\n' "$hits" | sed 's/^/       /'
  hard "Timer inside modules/HealthPanel.qml (clock must use SystemClock)"
else
  pass "health panel has no Timer"
fi

# --- 6. nothing personal is hardcoded in the design system -------------------
for token in diskMounts preferredScreens; do
  if grep -qE "^[[:space:]]*(readonly )?property .*$token" island/config/Theme.qml 2>/dev/null; then
    hard "Theme.qml defines $token (belongs in config/Config.qml)"
  fi
done
[ "$fail" -eq 0 ] && pass "personal settings live in config/Config.qml"

echo
if [ "$fail" -eq 0 ]; then
  echo "all checks passed"
else
  echo "checks failed"
fi
exit "$fail"
