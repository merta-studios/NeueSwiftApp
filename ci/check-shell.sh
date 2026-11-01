#!/usr/bin/env bash
#
# ci/check-shell.sh – prüft die Shell-Skripte dieses Repos.
#
#   ci/check-shell.sh
#
# Zwei Stufen:
#   1. `bash -n` – Syntaxfehler (immer verfügbar).
#   2. shellcheck – echte Fehlerquellen (auf den GitHub-Runnern vorinstalliert).
#
# Fehlt shellcheck, wird das gemeldet. In GitHub Actions ist das ein Fehlschlag
# (CI_REQUIRE_LINT_TOOLS=1), lokal nur ein Hinweis – ein stiller Erfolg ohne
# Prüfung ist aber in beiden Fällen ausgeschlossen.
#
# Umgebungsvariablen:
#   CI_REQUIRE_LINT_TOOLS  1 = fehlende Werkzeuge sind ein Fehler
#   SHELLCHECK_SEVERITY    Mindestschwere (Standard: warning)
#   CI_SUMMARY_FILE        Datei für die Schritt-Zusammenfassung (optional)

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

# shellcheck source=ci/lib.sh
. ci/lib.sh

severity="${SHELLCHECK_SEVERITY:-warning}"
summary_file="${CI_SUMMARY_FILE:-}"

log() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

summary_append() {
    [ -n "$summary_file" ] || return 0
    printf '%s\n' "$1" >>"$summary_file"
}

# Alle *.sh plus Skripte mit Shebang, die nicht auf .sh enden (z. B. die
# gh-Attrappe in Tests/stubs/gh).
scripts=()
while IFS= read -r file; do
    scripts+=("$file")
done < <( {
    find . -name '*.sh' -not -path './.git/*' -not -path './.build/*'
    find . -path ./.git -prune -o -type f -name 'gh' -print
} | sort -u )

if [ "${#scripts[@]}" -eq 0 ]; then
    err "Keine Shell-Skripte gefunden – das ist kein Erfolg."
    summary_append "- ❌ Shell: keine Skripte gefunden"
    exit 1
fi

log "Shell-Skripte prüfen"
bash --version | head -n 1
echo

status=0
syntax_checked=0
for file in "${scripts[@]}"; do
    if bash -n "$file"; then
        syntax_checked=$((syntax_checked + 1))
    else
        err "Syntaxfehler in $file (bash -n)"
        status=1
    fi
done
ok "$syntax_checked von ${#scripts[@]} Skript(en) syntaktisch in Ordnung"

if command -v shellcheck >/dev/null 2>&1; then
    echo
    note_version="$(shellcheck --version | sed -nE 's/^version: (.*)$/\1/p')"
    log "shellcheck $note_version (Mindestschwere: $severity)"
    shellcheck_output="$(shellcheck --severity="$severity" --external-sources "${scripts[@]}" 2>&1)"
    if [ $? -eq 0 ] && [ -z "$shellcheck_output" ]; then
        ok "shellcheck ohne Befund"
        summary_append "- ✅ Shell: ${#scripts[@]} Skript(e), shellcheck ohne Befund"
    else
        printf '%s\n' "$shellcheck_output" | head -n 60
        ci_report_diagnostics "$shellcheck_output" warning
        err "shellcheck hat Befunde gemeldet (siehe oben)."
        summary_append "- ❌ Shell: shellcheck-Befunde"
        status=1
    fi
else
    err "shellcheck ist nicht installiert."
    if [ "${CI_REQUIRE_LINT_TOOLS:-0}" = "1" ]; then
        echo "::error::shellcheck fehlt in dieser Umgebung (CI_REQUIRE_LINT_TOOLS=1)."
        summary_append "- ❌ Shell: shellcheck fehlt"
        status=1
    else
        warn "Lokal übersprungen. Installation: https://github.com/koalaman/shellcheck"
        summary_append "- ⚠️ Shell: nur Syntax (shellcheck lokal nicht installiert)"
    fi
fi

exit "$status"
