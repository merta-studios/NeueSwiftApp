#!/usr/bin/env bash
#
# Tests/auto-merge.test.sh – prüft die Entscheidungen von ci/auto-merge.sh,
# ohne echte Merges auszulösen. Die GitHub-CLI wird durch Tests/stubs/gh
# ersetzt; es geht kein Netzwerkverkehr nach außen.
#
# Geprüft werden unter anderem:
#   • grüner Pfad inkl. Merge an genau den geprüften Commit (sha-Parameter)
#   • fehlende, laufende, rote, abgebrochene und übersprungene Prüfungen
#   • Entwurf, Konflikt, falscher Zielbranch, Fork-PR, Label no-automerge
#   • Änderungen an Workflows/CI/Tests werden nicht automatisch gemergt
#   • Head-Commit ändert sich zwischen Prüfung und Merge
#   • Merge wird vom Branch-Schutz abgelehnt
#   • Dry-Run schreibt nichts
#   • Pflichtprüfungsliste, Skript und Workflow passen zusammen
#   • keine Umgehungsschalter im Code (--admin, --force, admin-Bypass)
#
#   Tests/auto-merge.test.sh

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

repo_root="$PWD"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/neueswiftapp-automerge.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Stub vor die echte gh-CLI legen.
mkdir -p "$tmp/bin"
cp "$repo_root/Tests/stubs/gh" "$tmp/bin/gh"
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH"
export GH_STUB_DIR=""

if ! command -v jq >/dev/null 2>&1; then
    echo "jq fehlt – wird für die Tests benötigt." >&2
    exit 1
fi

cases=0
failures=0
case_name=""
case_output=""
case_rc=0

green_sha="1111111111111111111111111111111111111111"
other_sha="2222222222222222222222222222222222222222"

fail() {
    failures=$((failures + 1))
    printf '  \033[31m✗\033[0m %s\n' "$*"
}

pass() {
    printf '  \033[32m✓\033[0m %s\n' "$*"
}

# --------------------------------------------------------------- Testaufbau

scenario() { # scenario <name>
    cases=$((cases + 1))
    case_name="$1"
    printf '\n\033[1m%s\033[0m\n' "$case_name"
    GH_STUB_DIR="$tmp/$1"
    export GH_STUB_DIR
    mkdir -p "$GH_STUB_DIR"
    : >"$GH_STUB_DIR/calls.log"

    printf '{"default_branch":"main"}' >"$GH_STUB_DIR/repo.json"
    printf '[]' >"$GH_STUB_DIR/pulls-search.json"
    printf '[]' >"$GH_STUB_DIR/labels.json"
    printf '[]' >"$GH_STUB_DIR/files.json"
    printf '[]' >"$GH_STUB_DIR/comments.json"
    printf '{"statuses":[]}' >"$GH_STUB_DIR/status.json"
    printf '{"workflow_runs":[]}' >"$GH_STUB_DIR/runs.json"
    write_pr
    write_checks success success
}

write_pr() { # write_pr – Standard-PR (überschreibbar mit patch_pr)
    jq -n --arg sha "$green_sha" '{
        number: 1,
        state: "open",
        title: "Teständerung",
        draft: false,
        mergeable: true,
        mergeable_state: "clean",
        merged: false,
        merge_commit_sha: null,
        base: { ref: "main", repo: { id: 1, full_name: "test/repo" } },
        head: { ref: "arena/test", sha: $sha, repo: { id: 1, full_name: "test/repo" } }
    }' >"$GH_STUB_DIR/pr.json"
}

patch_pr() { # patch_pr <jq-filter>
    jq "$1" "$GH_STUB_DIR/pr.json" >"$GH_STUB_DIR/pr.json.tmp"
    mv "$GH_STUB_DIR/pr.json.tmp" "$GH_STUB_DIR/pr.json"
}

write_checks() { # write_checks <conclusion...> – je Pflichtprüfung ein Wert
    local -a names=(
        "Syntax (alle Swift-Dateien)"
        "App-Logik (Typen und Tests)"
    )
    local -a runs=()
    local index=0 conclusion
    for conclusion in "$@"; do
        runs+=("$(jq -cn --arg name "${names[$index]}" --arg conclusion "$conclusion" \
            --argjson idx "$index" '{
            name: $name,
            status: (if $conclusion == "pending" then "in_progress" else "completed" end),
            conclusion: (if $conclusion == "pending" then null else $conclusion end),
            started_at: "2026-01-01T00:00:0\($idx)Z",
            id: (100 + $idx)
        }')")
        index=$((index + 1))
    done
    local joined
    joined="$(printf '%s\n' "${runs[@]}" | jq -s -c '.')"
    jq -n --argjson runs "$joined" '{ total_count: ($runs | length), check_runs: $runs }' \
        >"$GH_STUB_DIR/check-runs.json"
}

run_script() { # run_script [argumente...]
    case_output="$(REPO=test/repo \
        AUTOMERGE_REQUIRED_CHECKS="Syntax (alle Swift-Dateien),App-Logik (Typen und Tests)" \
        AUTOMERGE_TIMEOUT="${AUTOMERGE_TIMEOUT:-0}" \
        AUTOMERGE_POLL=0 \
        AUTOMERGE_CANCEL_RETRIES=1 \
        AUTOMERGE_DISPATCH_CHECK="${AUTOMERGE_DISPATCH_CHECK:-0}" \
        AUTOMERGE_DISPATCH_BUILD="${AUTOMERGE_DISPATCH_BUILD:-0}" \
        AUTOMERGE_CREATE_PR="${AUTOMERGE_CREATE_PR:-0}" \
        AUTOMERGE_DRY_RUN="${AUTOMERGE_DRY_RUN:-0}" \
        ci/auto-merge.sh "$@" 2>&1)"
    case_rc=$?
    printf '%s\n' "$case_output" | sed 's/^/    /'
}

expect_rc() { # expect_rc <erwartet>
    if [ "$case_rc" = "$1" ]; then
        pass "Rückgabewert $1"
    else
        fail "Rückgabewert $case_rc, erwartet $1"
    fi
}

expect_merge() { # expect_merge [sha]
    local wanted="${1:-}" call sha
    call="$(grep '^PUT repos/test/repo/pulls/1/merge' "$GH_STUB_DIR/calls.log" || true)"
    if [ -z "$call" ]; then
        fail "kein Merge-Aufruf erfolgt"
        return
    fi
    if [ -z "$wanted" ]; then
        pass "Merge ausgelöst"
        return
    fi
    sha="$(printf '%s' "$call" | sed -nE 's/.* sha=([0-9a-f]+).*/\1/p')"
    if [ "$sha" = "$wanted" ]; then
        pass "Merge an Commit ${wanted:0:8} gebunden"
    else
        fail "Merge ohne Bindung an ${wanted:0:8} (sha-Parameter: '${sha:-fehlt}')"
    fi
}

expect_no_merge() {
    if grep -q '^PUT ' "$GH_STUB_DIR/calls.log"; then
        fail "es wurde gemergt, obwohl nicht gemergt werden durfte"
    else
        pass "kein Merge"
    fi
}

expect_output() { # expect_output <text>
    if printf '%s' "$case_output" | grep -qF -- "$1"; then
        pass "Meldung enthält: $1"
    else
        fail "Meldung enthält nicht: $1"
    fi
}

expect_comment() {
    if [ -s "$GH_STUB_DIR/posted-comments.txt" ]; then
        pass "Kommentar am Pull Request"
    else
        fail "kein Kommentar am Pull Request"
    fi
}

expect_no_comment() {
    if [ -s "$GH_STUB_DIR/posted-comments.txt" ]; then
        fail "unerwarteter Kommentar am Pull Request"
    else
        pass "kein Kommentar"
    fi
}

expect_called() { # expect_called <METHOD endpoint>
    if grep -qF -- "$1" "$GH_STUB_DIR/calls.log"; then
        pass "Aufruf $1"
    else
        fail "Aufruf $1 fehlt"
    fi
}

expect_not_called() { # expect_not_called <text>
    if grep -qF -- "$1" "$GH_STUB_DIR/calls.log"; then
        fail "unerwarteter Aufruf $1"
    else
        pass "kein Aufruf $1"
    fi
}

# ------------------------------------------------------------------ Szenarien

scenario "grüner Pfad mergt an den geprüften Commit"
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 0
expect_merge "$green_sha"
expect_called "PUT repos/test/repo/pulls/1/merge"

scenario "grüner Pfad stößt die Folgeläufe an (GITHUB_TOKEN-Merge)"
AUTOMERGE_TIMEOUT=60 AUTOMERGE_DISPATCH_CHECK=1 AUTOMERGE_DISPATCH_BUILD=1 run_script --pr 1
expect_rc 0
expect_called "POST repos/test/repo/actions/workflows/build-check.yml/dispatches"
expect_called "POST repos/test/repo/actions/workflows/build-ipa.yml/dispatches"

scenario "Folgelauf wird nicht doppelt gestartet"
printf '{"workflow_runs":[{"path":".github/workflows/build-ipa.yml"}]}' >"$GH_STUB_DIR/runs.json"
AUTOMERGE_TIMEOUT=60 AUTOMERGE_DISPATCH_BUILD=1 run_script --pr 1
expect_not_called "POST repos/test/repo/actions/workflows/build-ipa.yml/dispatches"

scenario "fehlende Pflichtprüfung ist kein Erfolg"
write_checks success
AUTOMERGE_TIMEOUT=0 run_script --pr 1
expect_rc 1
expect_no_merge
expect_output "Zeitüberschreitung"

scenario "rote Pflichtprüfung verhindert den Merge"
write_checks success failure
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 1
expect_no_merge
expect_comment
expect_output "nicht bestanden"

scenario "übersprungene Pflichtprüfung ist kein Erfolg"
write_checks success skipped
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 1
expect_no_merge
expect_output "übersprungen"

scenario "abgebrochene Pflichtprüfung ist kein Erfolg"
write_checks success cancelled
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 1
expect_no_merge
expect_called "POST repos/test/repo/actions/workflows/build-check.yml/dispatches"

scenario "laufende Pflichtprüfung wird nicht als Erfolg gewertet"
write_checks success pending
AUTOMERGE_TIMEOUT=0 run_script --pr 1
expect_rc 1
expect_no_merge

scenario "Entwurf wird nicht gemergt"
patch_pr '.draft = true'
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 0
expect_no_merge
expect_output "Entwurf"

scenario "Label no-automerge stoppt die Automatik"
printf '[{"name":"no-automerge"}]' >"$GH_STUB_DIR/labels.json"
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 0
expect_no_merge
expect_output "no-automerge"

scenario "fremder Branch ohne Opt-in-Label wird nicht gemergt"
patch_pr '.head.ref = "feature/etwas"'
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 0
expect_no_merge
expect_output "AUTOMERGE_BRANCHES"

scenario "Opt-in-Label automerge aktiviert fremde Branches"
printf '[{"name":"automerge"}]' >"$GH_STUB_DIR/labels.json"
patch_pr '.head.ref = "feature/etwas"'
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 0
expect_merge "$green_sha"

scenario "Fork-PR wird nicht gemergt"
patch_pr '.head.repo.full_name = "fremd/repo"'
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 0
expect_no_merge
expect_output "Fork"

scenario "gleicher Branch-Name aus anderem Repository (id) wird nicht gemergt"
patch_pr '.head.repo.id = 99'
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 0
expect_no_merge

scenario "falscher Zielbranch wird nicht gemergt"
patch_pr '.base.ref = "release"'
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 0
expect_no_merge
expect_output "Zielbranch"

scenario "Änderungen an Workflows/CI/Tests werden nicht automatisch gemergt"
printf '[{"filename":"NeueSwiftApp.swiftpm/App.swift"},{"filename":".github/workflows/build-check.yml"}]' \
    >"$GH_STUB_DIR/files.json"
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 1
expect_no_merge
expect_comment
expect_output "geschützten Pfaden"

scenario "Änderungen an ci/ werden nicht automatisch gemergt"
printf '[{"filename":"ci/auto-merge.sh"}]' >"$GH_STUB_DIR/files.json"
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 1
expect_no_merge

scenario "Konflikt verhindert den Merge"
patch_pr '.mergeable = false | .mergeable_state = "dirty"'
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 1
expect_no_merge
expect_output "Konflikt"

scenario "Head-Commit ändert sich zwischen Prüfung und Merge"
jq --arg sha "$other_sha" '.head.sha = $sha' "$GH_STUB_DIR/pr.json" >"$GH_STUB_DIR/pr2.json"
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 1
expect_no_merge
expect_output "Head-Commit hat sich"

scenario "Branch-Schutz lehnt den Merge ab"
printf '1' >"$GH_STUB_DIR/merge.rc"
printf 'Pull request is not mergeable: the base branch policy prohibits the merge\n' \
    >"$GH_STUB_DIR/merge.err"
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 1
expect_output "Merge fehlgeschlagen"

scenario "keine Check-Runs auf dem Commit: kein Erfolg"
printf '{"total_count":0,"check_runs":[]}' >"$GH_STUB_DIR/check-runs.json"
AUTOMERGE_TIMEOUT=0 run_script --pr 1
expect_rc 1
expect_no_merge

scenario "nicht vollständig lesbare Check-Runs werden nicht ausgewertet"
jq '. + {total_count: 150}' "$GH_STUB_DIR/check-runs.json" >"$GH_STUB_DIR/check-runs.tmp"
mv "$GH_STUB_DIR/check-runs.tmp" "$GH_STUB_DIR/check-runs.json"
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 1
expect_no_merge
expect_output "nicht sicher auswertbar"

scenario "offener Drittstatus (Commit-Status) blockiert"
jq -n '{statuses:[{context:"Syntax (alle Swift-Dateien)",state:"pending"}]}' \
    >"$GH_STUB_DIR/status.json"
AUTOMERGE_TIMEOUT=0 run_script --pr 1
expect_rc 1
expect_no_merge

scenario "bereits gemergter PR ist kein Fehler"
patch_pr '.state = "merged"'
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 0
expect_no_merge

scenario "geschlossener PR wird nicht gemergt"
patch_pr '.state = "closed"'
AUTOMERGE_TIMEOUT=60 run_script --pr 1
expect_rc 0
expect_no_merge

scenario "Dry-Run entscheidet, schreibt aber nichts"
AUTOMERGE_TIMEOUT=60 AUTOMERGE_DRY_RUN=1 run_script --pr 1
expect_rc 0
expect_no_merge
expect_no_comment

scenario "fehlender PR wird für einen Arena-Branch angelegt"
AUTOMERGE_TIMEOUT=60 AUTOMERGE_CREATE_PR=1
printf '{"number":1}' >"$GH_STUB_DIR/create-pr.json"
printf '{"commit":{"message":"Teständerung\\n\\nMehr Text"}}' >"$GH_STUB_DIR/commits.json"
run_script --branch arena/test
expect_rc 0
expect_called "POST repos/test/repo/pulls"
expect_merge "$green_sha"

scenario "PR-Anlegen ohne Rechte endet mit Fehler"
printf '1' >"$GH_STUB_DIR/create-pr.rc"
printf 'Resource not accessible by integration\n' >"$GH_STUB_DIR/create-pr.err"
AUTOMERGE_TIMEOUT=60 AUTOMERGE_CREATE_PR=1 run_script --branch arena/test
expect_rc 1
expect_no_merge

# ------------------------------------------------- Statische Sicherheitsprüfungen

printf '\n\033[1mStatische Prüfungen\033[0m\n'
cases=$((cases + 1))

script="$repo_root/ci/auto-merge.sh"
workflow="$repo_root/.github/workflows/auto-merge.yml"

strip_comments() { sed -E 's/(^|[[:space:]])#.*$//' "$1"; }

for forbidden in '--admin' 'AUTOMERGE_FORCE' '--force' 'admin=true'; do
    found=0
    for file in "$script" "$workflow"; do
        if strip_comments "$file" | grep -qF -- "$forbidden"; then
            found=1
        fi
    done
    if [ "$found" -eq 1 ]; then
        fail "Umgehungsschalter gefunden: $forbidden"
    else
        pass "kein '$forbidden' in Auto-Merge-Skript/Workflow"
    fi
done

if grep -qE '^[[:space:]]+pull_request:' "$workflow"; then
    fail "Workflow nutzt pull_request (führt PR-Code mit Schreibrechten aus)"
else
    pass "Auto-Merge-Workflow nutzt kein pull_request"
fi

if grep -q 'pull_request_target' "$workflow"; then
    pass "Auto-Merge-Workflow nutzt pull_request_target"
else
    fail "Auto-Merge-Workflow nutzt kein pull_request_target"
fi

if grep -q 'persist-credentials: false' "$workflow"; then
    pass "Checkout ohne persistierte Zugangsdaten"
else
    fail "Checkout mit persistierten Zugangsdaten"
fi

# Pflichtprüfungen müssen im Skript, im Workflow und in den Jobs übereinstimmen.
printf '\n\033[1mPflichtprüfungen stimmen mit den Workflow-Jobs überein\033[0m\n'
cases=$((cases + 1))

default_checks="$(sed -n "s/^    REQUIRED_CHECKS='\(.*\)'$/\1/p" "$script")"
workflow_checks="$(sed -n "s/.*AUTOMERGE_REQUIRED_CHECKS: .*|| '\(.*\)' }}.*/\1/p" "$workflow")"
job_names="$(python3 - "$repo_root/.github/workflows/build-check.yml" <<'PY'
import sys

names = []
in_jobs = False
for line in open(sys.argv[1], encoding="utf-8"):
    stripped = line.rstrip("\n")
    if stripped == "jobs:":
        in_jobs = True
        continue
    if not in_jobs:
        continue
    if stripped.startswith("    name: "):
        names.append(stripped[len("    name: "):])
print(",".join(names))
PY
)"

if [ -z "$default_checks" ]; then
    fail "Standardliste der Pflichtprüfungen im Skript nicht gefunden"
elif [ "$default_checks" = "$workflow_checks" ]; then
    pass "Skript und Workflow nennen dieselben Pflichtprüfungen"
else
    fail "Skript und Workflow nennen unterschiedliche Pflichtprüfungen"
fi

if [ -n "$job_names" ] && [ "$job_names" = "$default_checks" ]; then
    pass "Pflichtprüfungen entsprechen den Job-Namen in build-check.yml"
else
    fail "Pflichtprüfungen passen nicht zu den Jobs in build-check.yml"
    printf '      Jobs:  %s\n      Liste: %s\n' "$job_names" "$default_checks"
fi

# ------------------------------------------------------------------- Ergebnis

printf '\n'
if [ "$failures" -eq 0 ]; then
    printf '\033[32m%s Auto-Merge-Szenarien erfolgreich.\033[0m\n' "$cases"
    exit 0
fi

printf '\033[31m%s von %s Szenarien mit Fehlern.\033[0m\n' "$failures" "$cases"
exit 1
