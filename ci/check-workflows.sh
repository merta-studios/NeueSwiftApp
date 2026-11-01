#!/usr/bin/env bash
#
# ci/check-workflows.sh – prüft die GitHub-Workflows dieses Repos.
#
#   ci/check-workflows.sh
#
# Prüfungen:
#   1. Workflow-Dateien vorhanden (sonst ist das kein Erfolg).
#   2. Alle `uses:`-Angaben sind auf einen Commit-SHA festgelegt (kein
#      bewegliches `@v4`). Das ist die eigentliche Lieferketten-Härtung:
#      ein Tag kann verschoben werden, ein SHA nicht.
#   3. actionlint – Syntax und Semantik der Workflows. Ist actionlint nicht
#      installiert, wird die festgelegte Version einmalig heruntergeladen und
#      gegen eine SHA-256-Summe geprüft.
#   4. YAML-Parsing mit python3 (falls PyYAML vorhanden) – findet auch
#      Einrückungs- und Tippfehler in Dateien, die actionlint nicht liest.
#
# Umgebungsvariablen:
#   CI_REQUIRE_LINT_TOOLS  1 = fehlende Werkzeuge sind ein Fehler
#   CI_SUMMARY_FILE        Datei für die Schritt-Zusammenfassung (optional)

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

# shellcheck source=ci/lib.sh
. ci/lib.sh

summary_file="${CI_SUMMARY_FILE:-}"
actionlint_version="1.7.12"
actionlint_sha256="8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"

# Alle Meldungen gehen nach stderr: find_actionlint wird per
# Kommando-Substitution aufgerufen, stdout darf nur den Pfad enthalten.
log() { printf '\033[1m%s\033[0m\n' "$*" >&2; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*" >&2; }
note() { printf '  \033[34mi\033[0m %s\n' "$*" >&2; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
err() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

summary_append() {
    [ -n "$summary_file" ] || return 0
    printf '%s\n' "$1" >>"$summary_file"
}

status=0

workflows=()
for file in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$file" ] && workflows+=("$file")
done

if [ "${#workflows[@]}" -eq 0 ]; then
    err "Keine Workflow-Datei unter .github/workflows gefunden."
    summary_append "- ❌ Workflows: keine Datei gefunden"
    exit 1
fi

log "GitHub-Workflows prüfen"
note "${#workflows[@]} Datei(en): ${workflows[*]}"
echo

# ---------------------------------------------------------------- SHA-Pinning

log "Alle Aktionen auf Commit-SHA festgelegt?"
pinning_errors=0
pin_count=0
for file in "${workflows[@]}"; do
    while IFS= read -r line; do
        reference="${line#*uses:}"
        reference="${reference%%#*}"
        reference="$(printf '%s' "$reference" | tr -d '[:space:]')"
        case "$reference" in
            "" | ./* | docker://*) continue ;;
        esac
        pin_count=$((pin_count + 1))
        if ! printf '%s' "$reference" | grep -qE '@[0-9a-f]{40}$'; then
            err "$file: '$reference' ist nicht auf einen Commit-SHA festgelegt"
            ci_annotate error "$file" 1 1 "'$reference' ist nicht auf einen Commit-SHA festgelegt"
            pinning_errors=$((pinning_errors + 1))
        fi
        if ! printf '%s' "$line" | grep -qE '#[[:space:]]*v?[0-9]'; then
            warn "$file: '$reference' ohne Versionskommentar (z. B. '# v7.0.1')"
        fi
    done < <(grep -E '^[[:space:]]*(-[[:space:]]*)?uses:' "$file" || true)
done

if [ "$pinning_errors" -gt 0 ]; then
    err "$pinning_errors Aktion(en) sind nicht gepinnt."
    summary_append "- ❌ Workflows: $pinning_errors Aktion(en) ohne SHA-Pinning"
    status=1
elif [ "$pin_count" -eq 0 ]; then
    warn "Keine externen Aktionen gefunden – Pinning-Prüfung war leer."
else
    ok "$pin_count extern(e) Aktion(en) sind auf Commit-SHAs gepinnt"
fi

# ------------------------------------------------------------------ actionlint

find_actionlint() {
    if command -v actionlint >/dev/null 2>&1; then
        printf 'actionlint'
        return 0
    fi
    local arch target
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        *)
            warn "Automatischer actionlint-Download für $(uname -m) nicht hinterlegt."
            return 1
            ;;
    esac
    target="${TMPDIR:-/tmp}/actionlint-${actionlint_version}"
    if [ -x "$target" ]; then
        printf '%s' "$target"
        return 0
    fi
    local url archive
    url="https://github.com/rhysd/actionlint/releases/download/v${actionlint_version}/actionlint_${actionlint_version}_linux_${arch}.tar.gz"
    archive="$(mktemp "${TMPDIR:-/tmp}/actionlint.XXXXXX.tar.gz")"
    note "actionlint ${actionlint_version} wird geladen: $url"
    if ! curl -fsSL --retry 2 --max-time 120 -o "$archive" "$url"; then
        rm -f "$archive"
        warn "Download fehlgeschlagen (Blockiert? Kein Netz?)."
        return 1
    fi
    local digest
    digest="$(sha256sum "$archive" | awk '{print $1}')"
    if [ "$digest" != "$actionlint_sha256" ]; then
        err "SHA-256 passt nicht: erwartet $actionlint_sha256, erhalten $digest"
        rm -f "$archive"
        return 1
    fi
    tar -xzf "$archive" -C "$(dirname "$target")" actionlint
    rm -f "$archive"
    mv "$(dirname "$target")/actionlint" "$target"
    chmod +x "$target"
    printf '%s' "$target"
}

echo
log "actionlint"
actionlint="$(find_actionlint || true)"
if [ -n "$actionlint" ] && [ -x "$actionlint" ]; then
    note "Version: $("$actionlint" --version 2>&1 | head -n 1)"
    actionlint_output="$("$actionlint" -color "${workflows[@]}" 2>&1)"
    if [ $? -eq 0 ] && [ -z "$actionlint_output" ]; then
        ok "actionlint ohne Befund"
        summary_append "- ✅ Workflows: actionlint ohne Befund"
    else
        err "actionlint hat Befunde gemeldet."
        printf '%s\n' "$actionlint_output" | sed 's/^/    /'
        ci_report_diagnostics "$actionlint_output" error
        summary_append "- ❌ Workflows: actionlint-Befunde"
        status=1
    fi
else
    err "actionlint nicht verfügbar."
    if [ "${CI_REQUIRE_LINT_TOOLS:-0}" = "1" ]; then
        echo "::error::actionlint fehlt (CI_REQUIRE_LINT_TOOLS=1)."
        summary_append "- ❌ Workflows: actionlint fehlt"
        status=1
    else
        warn "Lokal übersprungen – in GitHub Actions ist actionlint Pflicht."
        summary_append "- ⚠️ Workflows: actionlint lokal nicht verfügbar"
    fi
fi

# ----------------------------------------------------------------- YAML-Parsing

echo
log "YAML-Struktur"
if python3 -c 'import yaml' >/dev/null 2>&1; then
    if python3 - "${workflows[@]}" <<'PY'
import sys

import yaml

failures = 0
for path in sys.argv[1:]:
    try:
        with open(path, encoding="utf-8") as handle:
            document = yaml.safe_load(handle)
    except Exception as error:  # noqa: BLE001 - Fehler werden nur gemeldet
        print(f"  ✗ {path}: {error}")
        failures += 1
        continue
    if not isinstance(document, dict) or "jobs" not in document:
        print(f"  ✗ {path}: kein Workflow (Schlüssel 'jobs' fehlt)")
        failures += 1
        continue
    print(f"  ✓ {path}: {len(document['jobs'])} Job(s)")
sys.exit(1 if failures else 0)
PY
    then
        ok "Alle Workflow-Dateien sind gültiges YAML mit Jobs"
    else
        err "YAML-Prüfung fehlgeschlagen."
        status=1
    fi
else
    warn "PyYAML fehlt – YAML-Strukturprüfung übersprungen (actionlint prüft weiterhin)."
fi

summary_append ""
exit "$status"
