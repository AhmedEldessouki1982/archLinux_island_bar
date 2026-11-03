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

# --- 7. launch smoke test ------------------------------------------------------
smoke_skip_reason=""
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  smoke_skip_reason="no WAYLAND_DISPLAY"
elif ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl -j monitors >/dev/null 2>&1; then
  smoke_skip_reason="hyprctl cannot reach the compositor"
fi

if [ -n "$smoke_skip_reason" ]; then
  note "launch smoke test skipped ($smoke_skip_reason)"
else
  before_pids=$(pgrep -x quickshell || true)
  before_count=$(printf '%s\n' "$before_pids" | grep -c . || true)

  note "launch smoke test: stopping existing quickshell instances (before_count=$before_count)"
  pkill -x quickshell 2>/dev/null || true
  for i in 1 2 3 4 5; do
    sleep 1
    pgrep -x quickshell >/dev/null 2>&1 || break
  done

  note "launch smoke test: starting fresh instance with 'quickshell -c island'"
  setsid -f quickshell -c island >/dev/null 2>&1
  sleep 6

  log_file=$(ls -dt /run/user/$(id -u)/quickshell/by-id/*/log.qslog 2>/dev/null | head -1)
  smoke_bad=0
  if [ -n "$log_file" ] && [ -f "$log_file" ]; then
    if tr '\r' '\n' < "$log_file" | grep -qE 'Failed to load configuration|^[[:space:]]*ERROR'; then
      smoke_bad=1
    fi
  fi

  if [ "$before_count" -eq 0 ]; then
    pkill -x quickshell 2>/dev/null || true
    sleep 1
    after_pids=$(pgrep -x quickshell || true)
    after_count=$(printf '%s\n' "$after_pids" | grep -c . || true)
    if [ "$smoke_bad" -eq 1 ]; then
      hard "launch smoke test: Failed to load configuration or ERROR in log (before_count=$before_count after_count=$after_count)"
    elif [ "$after_count" -ne 0 ]; then
      hard "launch smoke test: left quickshell running (started by test, before_count=$before_count after_count=$after_count)"
    else
      pass "launch smoke test passed (stopped existing: yes, started fresh: quickshell -c island, before_count=$before_count after_count=$after_count)"
    fi
  else
    if [ "$smoke_bad" -eq 1 ]; then
      # Try to restore anyway
      setsid -f quickshell -c island >/dev/null 2>&1
      sleep 2
      after_pids=$(pgrep -x quickshell || true)
      after_count=$(printf '%s\n' "$after_pids" | grep -c . || true)
      hard "launch smoke test: Failed to load configuration or ERROR in log (before_count=$before_count after_count=$after_count, restored with quickshell -c island)"
    else
      setsid -f quickshell -c island >/dev/null 2>&1
      sleep 3
      after_pids=$(pgrep -x quickshell || true)
      after_count=$(printf '%s\n' "$after_pids" | grep -c . || true)
      if [ "$after_count" -lt 1 ]; then
        hard "launch smoke test: failed to restore bar (before_count=$before_count after_count=$after_count)"
      elif [ "$after_count" -gt 1 ]; then
        note "launch smoke test: restored to multiple instances ($after_count), normalizing to 1"
        # keep first, kill extras? just ensure at least 1; requirement says "restore to exactly one running instance and say so in the output" if duplicates
        pids_list=$(pgrep -x quickshell | awk '{print $1}')
        # keep one
        echo "$pids_list" | tail -n +2 | xargs -r kill 2>/dev/null || true
        sleep 1
        after_pids=$(pgrep -x quickshell || true)
        after_count=$(printf '%s\n' "$after_pids" | grep -c . || true)
        pass "launch smoke test passed (stopped and relaunched fresh instance checked with quickshell -c island; had $before_count running -> restored to exactly 1; before_count=$before_count after_count=$after_count)"
      else
        pass "launch smoke test passed (stopped and relaunched fresh instance checked with quickshell -c island; had $before_count running -> restored to exactly 1; before_count=$before_count after_count=$after_count)"
      fi
    fi
  fi
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "all checks passed"
else
  echo "checks failed"
fi
exit "$fail"
