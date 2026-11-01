#!/usr/bin/env bash
#
# ci/auto-merge.sh – prüft einen Pull Request und mergt ihn, wenn alle
# Pflichtprüfungen für genau den aktuellen Head-Commit grün sind.
#
#   ci/auto-merge.sh --pr 12
#   ci/auto-merge.sh --branch arena/abc-app [--create]
#   ci/auto-merge.sh --pr 12 --dry-run
#
# Grundsätze (bewusst anders als „einfach alles mergen“):
#   • Es gibt keinen Schalter, der Prüfungen überspringt, und kein --admin.
#     /automerge im Pull Request löst nur eine erneute Auswertung aus.
#   • Pflichtprüfungen stehen als Liste fest. Fehlende, laufende,
#     übersprungene, abgebrochene oder fehlgeschlagene Prüfungen sind kein
#     Erfolg.
#   • Nur Pull Requests aus diesem Repository (kein gleichnamiger Fork-Branch).
#   • Kein Merge von Entwürfen, bei Konflikten, bei falschem Zielbranch oder
#     mit Label „no-automerge“.
#   • Änderungen an Workflows, CI- und Testdateien werden nicht automatisch
#     freigegeben – die müssen von einem Menschen angesehen werden.
#   • Der Merge wird serverseitig an den geprüften Commit gebunden
#     (`sha=`-Parameter der Merge-API); ändert sich der Head dazwischen,
#     lehnt GitHub ab.
#
# Umgebungsvariablen (alle optional, Standard in Klammern):
#   REPO                        owner/name (sonst GITHUB_REPOSITORY, sonst origin)
#   AUTOMERGE_BASE_BRANCH       Zielbranch (Standard: Default-Branch des Repos)
#   AUTOMERGE_BRANCHES          erlaubte Head-Branches (arena/*,ai/*,agent/*)
#   AUTOMERGE_LABEL             Opt-in-Label für fremde Branch-Namen (automerge)
#   AUTOMERGE_BLOCK_LABEL       Ausschluss-Label (no-automerge)
#   AUTOMERGE_REQUIRED_CHECKS   kommagetrennte Pflichtprüfungen (siehe unten)
#   AUTOMERGE_PROTECTED_PATHS   geschützte Pfade (.github/,ci/,Tests/)
#   AUTOMERGE_TIMEOUT           Sekunden auf Prüfungen warten (2700)
#   AUTOMERGE_POLL              Sekunden zwischen Abfragen (20)
#   AUTOMERGE_CANCEL_RETRIES    Neustarts bei abgebrochenen Prüfungen (2)
#   AUTOMERGE_DISPATCH_CHECK    1 = nach dem Merge Swift-Prüfung anstoßen (0)
#   AUTOMERGE_DISPATCH_BUILD    1 = nach dem Merge IPA-Build anstoßen (0)
#   AUTOMERGE_CREATE_PR         1 = fehlenden Pull Request anlegen (0)
#   AUTOMERGE_DRY_RUN           1 = nur entscheiden, nichts schreiben (0)
#   AUTOMERGE_CHECK_WORKFLOW    Workflow-Datei der Prüfung (build-check.yml)
#   AUTOMERGE_BUILD_WORKFLOW    Workflow-Datei des IPA-Builds (build-ipa.yml)
#
# Rückgabewerte: 0 = gemergt oder nichts zu tun, 1 = nicht gemergt (Grund im Log),
#                2 = Aufruffehler.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

REPO="${REPO:-${GITHUB_REPOSITORY:-}}"
BASE_BRANCH="${AUTOMERGE_BASE_BRANCH:-}"
BRANCH_PATTERNS="${AUTOMERGE_BRANCHES:-arena/*,ai/*,agent/*}"
OPT_IN_LABEL="${AUTOMERGE_LABEL:-automerge}"
BLOCK_LABEL="${AUTOMERGE_BLOCK_LABEL:-no-automerge}"
REQUIRED_CHECKS="${AUTOMERGE_REQUIRED_CHECKS-}"
PROTECTED_PATHS="${AUTOMERGE_PROTECTED_PATHS:-.github/,ci/,Tests/}"
TIMEOUT="${AUTOMERGE_TIMEOUT:-2700}"
POLL="${AUTOMERGE_POLL:-20}"
CANCEL_RETRIES="${AUTOMERGE_CANCEL_RETRIES:-2}"
DISPATCH_CHECK="${AUTOMERGE_DISPATCH_CHECK:-0}"
DISPATCH_BUILD="${AUTOMERGE_DISPATCH_BUILD:-0}"
CREATE_PR="${AUTOMERGE_CREATE_PR:-0}"
DRY_RUN="${AUTOMERGE_DRY_RUN:-0}"
CHECK_WORKFLOW="${AUTOMERGE_CHECK_WORKFLOW:-build-check.yml}"
BUILD_WORKFLOW="${AUTOMERGE_BUILD_WORKFLOW:-build-ipa.yml}"

if [ -z "$REQUIRED_CHECKS" ]; then
    REQUIRED_CHECKS='Syntax (alle Swift-Dateien),App-Logik (Typen und Tests),swift-format (Format),Skripte und Workflows (Lint und Tests),iOS-Build und Simulator-Smoke (Xcode)'
fi

PR=""
BRANCH=""

log() { printf '\033[1m%s\033[0m\n' "$*"; }
note() { printf '  \033[34mi\033[0m %s\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$1"; }

skip() { # skip <grund> – bewusst nichts tun, Lauf ist grün
    note "$1"
    exit 0
}

fail() { # fail <grund> – nicht mergen, Lauf ist rot
    err "$1"
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --pr) PR="${2:-}"; shift 2 || shift ;;
        --branch) BRANCH="${2:-}"; shift 2 || shift ;;
        --create) CREATE_PR=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h | --help)
            sed -n '2,48p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unbekanntes Argument: $1" >&2
            exit 2
            ;;
    esac
done

for tool in gh jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Werkzeug '$tool' fehlt." >&2
        exit 2
    fi
done

# ------------------------------------------------------------------ Repository

if [ -z "$REPO" ]; then
    origin_url="$(git remote get-url origin 2>/dev/null || true)"
    case "$origin_url" in
        git@github.com:*) REPO="${origin_url#git@github.com:}" ;;
        https://github.com/*) REPO="${origin_url#https://github.com/}" ;;
        ssh://git@github.com/*) REPO="${origin_url#ssh://git@github.com/}" ;;
    esac
    REPO="${REPO%.git}"
fi
if [ -z "$REPO" ]; then
    fail "Repository unbekannt – REPO=owner/name setzen."
fi
OWNER="${REPO%%/*}"

if [ -z "$BASE_BRANCH" ]; then
    BASE_BRANCH="$(gh api "repos/$REPO" 2>/dev/null | jq -r '.default_branch // empty')"
fi
if [ -z "$BASE_BRANCH" ]; then
    fail "Default-Branch von $REPO nicht ermittelbar (Rechte? Repository?)"
fi

log "Auto-Merge für $REPO (Zielbranch: $BASE_BRANCH)"

if [ "$DRY_RUN" = "1" ]; then
    warn "Dry-Run: es wird nichts kommentiert, gestartet oder gemergt."
fi

# --------------------------------------------------------- API-Hilfen (nur lesen)

api_array() { # api_array <pfad> [zusätzliche_query]
    local path="$1" extra="${2:-}" page=1 chunk combined="[]" size url
    while :; do
        url="${path}?per_page=100&page=${page}"
        [ -n "$extra" ] && url="${url}&${extra}"
        if ! chunk="$(gh api "$url" 2>/dev/null)"; then
            return 1
        fi
        if ! combined="$(printf '%s' "$combined" | jq -c --argjson chunk "$chunk" '. + $chunk' 2>/dev/null)"; then
            return 1
        fi
        size="$(printf '%s' "$chunk" | jq 'length' 2>/dev/null)" || return 1
        [ "${size:-0}" -lt 100 ] && break
        page=$((page + 1))
        [ "$page" -gt 30 ] && break
    done
    printf '%s' "$combined"
}

pr_json() { gh api "repos/$REPO/pulls/$PR" 2>/dev/null; }

# -------------------------------------------------------------- PR auflösen

if [ -n "$PR" ] && ! printf '%s' "$PR" | grep -qE '^[0-9]+$'; then
    fail "Pull-Request-Nummer erwartet, erhalten: $PR"
fi

if [ -z "$PR" ] && [ -n "$BRANCH" ]; then
    listed="$(api_array "repos/$REPO/pulls" "state=open&head=${OWNER}:${BRANCH}")" ||
        fail "Offene Pull Requests zu $BRANCH nicht lesbar."
    PR="$(printf '%s' "$listed" | jq -r '.[0].number // empty')"
    if [ -n "$PR" ]; then
        note "Offener Pull Request für $BRANCH: #$PR"
    elif [ "$CREATE_PR" = "1" ]; then
        if [ "$DRY_RUN" = "1" ]; then
            skip "[Dry-Run] würde einen Pull Request für $BRANCH anlegen."
        fi
        title="$(gh api "repos/$REPO/commits/$BRANCH" 2>/dev/null |
            jq -r '.commit.message | split("\n")[0] // empty')"
        [ -n "$title" ] || title="Änderungen von $BRANCH"
        title="${title:0:120}"
        body="Automatisch angelegter Pull Request für \`$BRANCH\`.

Gemergt wird nur, wenn alle Pflichtprüfungen für den Head-Commit grün sind
(Syntax, App-Logik-Tests, swift-format, Skript-/Workflow-Prüfung, iOS-Build mit
Simulator-Smoke-Test). Änderungen an Workflows, CI- und Testdateien werden
bewusst nicht automatisch freigegeben."
        create_output=""
        if create_output="$(gh api -X POST "repos/$REPO/pulls" \
            -f base="$BASE_BRANCH" -f head="$BRANCH" \
            -f title="$title" -f body="$body" 2>&1)"; then
            PR="$(printf '%s' "$create_output" | jq -r '.number // empty')"
            ok "Pull Request #$PR angelegt."
        else
            warn "Anlegen fehlgeschlagen: $create_output"
            listed="$(api_array "repos/$REPO/pulls" "state=open&head=${OWNER}:${BRANCH}" || true)"
            PR="$(printf '%s' "${listed:-[]}" | jq -r '.[0].number // empty')"
            if [ -n "$PR" ]; then
                note "Es gibt bereits einen offenen Pull Request: #$PR"
            else
                fail "Kein Pull Request für $BRANCH – Anlegen ist nicht erlaubt oder nicht möglich."
            fi
        fi
    else
        skip "Kein offener Pull Request für $BRANCH – nichts zu tun."
    fi
fi

if [ -z "$PR" ]; then
    skip "Kein Pull Request angegeben – nichts zu tun."
fi

# ------------------------------------------------------------- PR-Zustand lesen

pr="$(pr_json)"
if [ -z "$pr" ] || [ "$(jq -r 'has("number")' <<<"$pr" 2>/dev/null)" != "true" ]; then
    fail "Pull Request #$PR konnte nicht gelesen werden (Nummer? Rechte?)."
fi

state="$(jq -r '.state' <<<"$pr")"
base_ref="$(jq -r '.base.ref' <<<"$pr")"
head_ref="$(jq -r '.head.ref // ""' <<<"$pr")"
head_sha="$(jq -r '.head.sha // ""' <<<"$pr")"
head_repo="$(jq -r '.head.repo.full_name // ""' <<<"$pr")"
head_repo_id="$(jq -r '.head.repo.id // 0' <<<"$pr")"
base_repo_id="$(jq -r '.base.repo.id // 0' <<<"$pr")"
is_draft="$(jq -r '.draft // false' <<<"$pr")"
title="$(jq -r '.title // ""' <<<"$pr")"

log "Pull Request #$PR: $title"
note "Branch: $head_ref → $base_ref (Commit ${head_sha:0:8})"

case "$state" in
    open) ;;
    merged) skip "Pull Request ist bereits gemergt." ;;
    *) skip "Pull Request ist geschlossen (nicht gemergt)." ;;
esac

if [ "$base_ref" != "$BASE_BRANCH" ]; then
    skip "Zielbranch ist '$base_ref', nicht '$BASE_BRANCH' – Automatik greift hier nicht."
fi

if [ "$head_repo" != "$REPO" ] || [ "$head_repo_id" = "0" ] || [ "$head_repo_id" != "$base_repo_id" ]; then
    skip "Head-Branch stammt aus '$head_repo' statt aus '$REPO' – Fork-PRs werden nicht automergt."
fi

if [ "$is_draft" = "true" ]; then
    skip "Pull Request ist ein Entwurf."
fi

labels="$(gh api "repos/$REPO/issues/$PR/labels?per_page=100" 2>/dev/null | jq -r '.[].name' 2>/dev/null)"
has_label() {
    local wanted="$1" label
    while IFS= read -r label; do
        [ -n "$label" ] || continue
        [ "$label" = "$wanted" ] && return 0
    done <<<"$labels"
    return 1
}

if has_label "$BLOCK_LABEL"; then
    skip "Label '$BLOCK_LABEL' gesetzt – automatischer Merge ist abgeschaltet."
fi

branch_allowed() {
    local branch="$1" pattern
    local -a patterns=()
    IFS=',' read -r -a patterns <<<"$BRANCH_PATTERNS"
    for pattern in "${patterns[@]}"; do
        pattern="$(trim "$pattern")"
        [ -n "$pattern" ] || continue
        # shellcheck disable=SC2254 # Muster soll als Muster wirken
        case "$branch" in $pattern) return 0 ;; esac
    done
    return 1
}

if ! branch_allowed "$head_ref" && ! has_label "$OPT_IN_LABEL"; then
    skip "Branch '$head_ref' passt nicht zu AUTOMERGE_BRANCHES und Label '$OPT_IN_LABEL' fehlt."
fi

# --------------------------------------------------------------- Kommentarhilfe

comment_once() { # comment_once <marker> <text>
    local marker="$1" text="$2" comments
    if comments="$(api_array "repos/$REPO/issues/$PR/comments")"; then
        if [ "$(printf '%s' "$comments" | jq -r --arg m "$marker" '[.[] | select((.body // "") | contains($m))] | length' 2>/dev/null)" != "0" ]; then
            return 0
        fi
    fi
    if [ "$DRY_RUN" = "1" ]; then
        note "[Dry-Run] Kommentar: $marker"
        return 0
    fi
    if gh api -X POST "repos/$REPO/issues/$PR/comments" -f body="$text" >/dev/null 2>&1; then
        note "Kommentar am Pull Request hinterlassen."
    else
        warn "Kommentar konnte nicht geschrieben werden."
    fi
}

# ------------------------------------------------ Geschützte Pfade, Konflikte

protected_url_hits() {
    local files prefix name
    local -a prefixes=()
    IFS=',' read -r -a prefixes <<<"$PROTECTED_PATHS"
    if ! files="$(api_array "repos/$REPO/pulls/$PR/files")"; then
        warn "Geänderte Dateien nicht lesbar – sie gelten sicherheitshalber als geschützt."
        return 1
    fi
    HITS=""
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        for prefix in "${prefixes[@]}"; do
            prefix="$(trim "$prefix")"
            [ -n "$prefix" ] || continue
            case "$name" in
                "$prefix"*) HITS="$HITS $name" ;;
            esac
        done
    done < <(printf '%s' "$files" | jq -r '.[].filename' 2>/dev/null)
    [ -z "$HITS" ]
}

if ! protected_url_hits; then
    comment_once "<!-- automerge-geschuetzt -->" "### 🤖 Auto-Merge: manuelle Prüfung nötig

Dieser Pull Request ändert Workflows, CI- oder Testdateien:$HITS

Solche Änderungen werden **nicht** automatisch gemergt – sie können die Prüfungen selbst beeinflussen. Bitte ansehen und von Hand mergen."
    fail "Änderungen an geschützten Pfaden – automatischer Merge ist ausgeschaltet."
fi

mergeable_state="$(jq -r '.mergeable_state // ""' <<<"$pr")"
for _ in 1 2 3 4 5; do
    if [ "$mergeable_state" != "unknown" ] && [ "$(jq -r '.mergeable' <<<"$pr")" != "null" ]; then
        break
    fi
    sleep 2
    pr="$(pr_json)"
    mergeable_state="$(jq -r '.mergeable_state // ""' <<<"$pr")"
done

if [ "$(jq -r '.mergeable // "null"' <<<"$pr")" = "false" ] || [ "$mergeable_state" = "dirty" ]; then
    comment_once "<!-- automerge-konflikt -->" "### 🤖 Auto-Merge: Konflikt

Der Branch lässt sich nicht konfliktfrei nach \`$BASE_BRANCH\` mergen. Bitte neu aufsetzen; danach läuft die Automatik wieder."
    fail "Konflikt mit $BASE_BRANCH (mergeable_state=$mergeable_state)."
fi

# --------------------------------------------------------- Pflichtprüfungen

evaluate_checks() { # evaluate_checks <commit-sha> – setzt CHECKS_STATE usw.
    local sha="$1" payload runs_state statuses name entry
    CHECKS_STATE="pending"
    CHECKS_DETAIL=""
    MISSING_NAMES=""
    PENDING_NAMES=""
    FAILED_NAMES=""
    CANCELLED_NAMES=""
    SKIPPED_NAMES=""

    if ! payload="$(gh api "repos/$REPO/commits/$sha/check-runs?per_page=100" 2>/dev/null)"; then
        CHECKS_DETAIL="Check-Runs zu ${sha:0:8} nicht lesbar"
        return 0
    fi

    local total count
    total="$(jq -r '.total_count // 0' <<<"$payload" 2>/dev/null)"
    count="$(jq -r '.check_runs | length' <<<"$payload" 2>/dev/null)"
    if [ "${total:-0}" -gt "${count:-0}" ]; then
        CHECKS_STATE="fail"
        CHECKS_DETAIL="mehr als $count Check-Runs auf dem Commit ($total) – nicht sicher auswertbar"
        return 0
    fi

    local -A check_status=()
    local -A check_conclusion=()
    while IFS=$'\t' read -r name runs_state statuses; do
        [ -n "$name" ] || continue
        check_status["$name"]="$runs_state"
        check_conclusion["$name"]="$statuses"
    done < <(jq -r '
        [ .check_runs[] ]
        | group_by(.name)
        | map(sort_by((.started_at // .created_at // ""), .id) | last)
        | .[] | [.name, .status, (.conclusion // "")] | @tsv
    ' <<<"$payload" 2>/dev/null)

    # Alte Commit-Status (Drittanbieter-CI) zählen ebenfalls, wenn sie einen
    # Pflichtnamen tragen.
    local -A status_state=()
    if payload="$(gh api "repos/$REPO/commits/$sha/status" 2>/dev/null)"; then
        while IFS=$'\t' read -r name statuses; do
            [ -n "$name" ] || continue
            status_state["$name"]="$statuses"
        done < <(jq -r '.statuses[]? | [.context, .state] | @tsv' <<<"$payload" 2>/dev/null)
    fi

    local -a required=()
    IFS=',' read -r -a required <<<"$REQUIRED_CHECKS"
    local checked=0
    for name in "${required[@]}"; do
        name="$(trim "$name")"
        [ -n "$name" ] || continue
        checked=$((checked + 1))

        entry="${check_status[$name]:-missing}"
        if [ "$entry" = "missing" ]; then
            MISSING_NAMES="$MISSING_NAMES, $name"
            continue
        fi
        if [ "$entry" != "completed" ]; then
            PENDING_NAMES="$PENDING_NAMES, $name"
            continue
        fi

        case "${check_conclusion[$name]:-}" in
            success)
                if [ -n "${status_state[$name]:-}" ] && [ "${status_state[$name]}" != "success" ]; then
                    if [ "${status_state[$name]}" = "pending" ]; then
                        PENDING_NAMES="$PENDING_NAMES, $name (Status offen)"
                    else
                        FAILED_NAMES="$FAILED_NAMES, $name (${status_state[$name]})"
                    fi
                fi
                ;;
            skipped | neutral)
                SKIPPED_NAMES="$SKIPPED_NAMES, $name (${check_conclusion[$name]})"
                ;;
            cancelled)
                CANCELLED_NAMES="$CANCELLED_NAMES, $name"
                ;;
            *)
                FAILED_NAMES="$FAILED_NAMES, $name (${check_conclusion[$name]:-ohne Ergebnis})"
                ;;
        esac
    done

    MISSING_NAMES="${MISSING_NAMES#, }"
    PENDING_NAMES="${PENDING_NAMES#, }"
    FAILED_NAMES="${FAILED_NAMES#, }"
    CANCELLED_NAMES="${CANCELLED_NAMES#, }"
    SKIPPED_NAMES="${SKIPPED_NAMES#, }"

    if [ "$checked" -eq 0 ]; then
        CHECKS_STATE="fail"
        CHECKS_DETAIL="keine Pflichtprüfung konfiguriert"
        return 0
    fi

    if [ -n "$FAILED_NAMES" ]; then
        CHECKS_STATE="fail"
        CHECKS_DETAIL="nicht bestanden: $FAILED_NAMES"
    elif [ -n "$SKIPPED_NAMES" ]; then
        CHECKS_STATE="fail"
        CHECKS_DETAIL="übersprungen gilt nicht als bestanden: $SKIPPED_NAMES"
    elif [ -n "$CANCELLED_NAMES" ]; then
        CHECKS_STATE="cancelled"
        CHECKS_DETAIL="abgebrochen, kein Ergebnis: $CANCELLED_NAMES"
    elif [ -n "$MISSING_NAMES" ] || [ -n "$PENDING_NAMES" ]; then
        CHECKS_STATE="pending"
        CHECKS_DETAIL="ausstehend: ${MISSING_NAMES}${PENDING_NAMES:+$PENDING_NAMES}"
    else
        CHECKS_STATE="pass"
        CHECKS_DETAIL="$checked Pflichtprüfung(en) grün"
    fi
    return 0
}

dispatch_check_workflow() { # dispatch_check_workflow <ref> <grund>
    local ref="$1" reason="$2"
    if [ "$DRY_RUN" = "1" ]; then
        note "[Dry-Run] würde '$CHECK_WORKFLOW' für $ref starten ($reason)."
        return 0
    fi
    if gh api -X POST "repos/$REPO/actions/workflows/$CHECK_WORKFLOW/dispatches" \
        -f ref="$ref" >/dev/null 2>&1; then
        ok "'$CHECK_WORKFLOW' für $ref gestartet ($reason)."
    else
        warn "'$CHECK_WORKFLOW' konnte für $ref nicht gestartet werden (Rechte? Workflow auf dem Default-Branch?)."
    fi
}

log "Warte auf die Pflichtprüfungen von ${head_sha:0:8} (max. ${TIMEOUT}s)"
note "Pflicht: $REQUIRED_CHECKS"

deadline=$((SECONDS + TIMEOUT))
dispatch_attempts=0
cancel_retries=0

while :; do
    evaluate_checks "$head_sha"

    case "$CHECKS_STATE" in
        pass)
            ok "$CHECKS_DETAIL"
            break
            ;;
        fail)
            err "$CHECKS_DETAIL"
            comment_once "<!-- automerge-rot -->" "### 🤖 Auto-Merge: nicht gemergt

$CHECKS_DETAIL

Gemergt wird nur mit grünen Pflichtprüfungen für genau diesen Commit. Bitte Ursache beheben und erneut pushen – danach läuft die Prüfung automatisch wieder.

Details im Tab **Actions**." || true
            exit 1
            ;;
        cancelled)
            if [ "$cancel_retries" -ge "$CANCEL_RETRIES" ]; then
                err "$CHECKS_DETAIL (nach $CANCEL_RETRIES Neustartversuch(en))"
                comment_once "<!-- automerge-abbruch -->" "### 🤖 Auto-Merge: Prüfung ohne Ergebnis

$CHECKS_DETAIL

Ein abgebrochener Lauf zählt nicht als bestanden. Bitte im Tab **Actions** nachsehen und neu starten." || true
                exit 1
            fi
            cancel_retries=$((cancel_retries + 1))
            warn "$CHECKS_DETAIL – Neustart $cancel_retries/$CANCEL_RETRIES"
            dispatch_check_workflow "$head_ref" "abgebrochene Prüfung"
            ;;
        *)
            note "Noch nicht fertig – $CHECKS_DETAIL"
            if [ "$dispatch_attempts" -lt 2 ] && [ -n "$MISSING_NAMES" ]; then
                dispatch_attempts=$((dispatch_attempts + 1))
                dispatch_check_workflow "$head_ref" "fehlende Prüfung"
            fi
            ;;
    esac

    if [ "$SECONDS" -ge "$deadline" ]; then
        err "Zeitüberschreitung nach ${TIMEOUT}s – $CHECKS_DETAIL"
        comment_once "<!-- automerge-timeout -->" "### 🤖 Auto-Merge: Zeitüberschreitung

Nach ${TIMEOUT}s lagen nicht alle Pflichtprüfungen grün vor:$CHECKS_DETAIL

Es wurde **nicht** gemergt. Ein neuer Push startet die Prüfung erneut." || true
        exit 1
    fi

    [ "$POLL" -gt 0 ] && sleep "$POLL"
done

# ------------------------------------------------------------------ Mergen

current_head="$(pr_json | jq -r '.head.sha // empty')"
if [ "$current_head" != "$head_sha" ]; then
    fail "Head-Commit hat sich während der Prüfung geändert (${head_sha:0:8} → ${current_head:0:8}). Bitte erneut auswerten."
fi

log "Merge #$PR nach $BASE_BRANCH (${head_sha:0:8})"
if [ "$DRY_RUN" = "1" ]; then
    note "[Dry-Run] würde mit Merge-Commit mergen (sha=$head_sha)."
    exit 0
fi

merge_output=""
if merge_output="$(gh api -X PUT "repos/$REPO/pulls/$PR/merge" \
    -f merge_method=merge -f sha="$head_sha" 2>&1)"; then
    if [ "$(printf '%s' "$merge_output" | jq -r '.merged // false' 2>/dev/null)" != "true" ]; then
        fail "Merge wurde nicht bestätigt: $(printf '%s' "$merge_output" | head -c 400)"
    fi
    merge_sha="$(printf '%s' "$merge_output" | jq -r '.sha // empty' 2>/dev/null)"
    ok "Gemergt (Merge-Commit ${merge_sha:0:8})."
else
    case "$merge_output" in
        *"already merged"* | *"Already merged"*)
            ok "Pull Request war bereits gemergt."
            merge_sha="$(pr_json | jq -r '.merge_commit_sha // empty')"
            ;;
        *)
            err "Merge fehlgeschlagen:"
            printf '%s\n' "$merge_output"
            case "$merge_output" in
                *"not mergeable"* | *"Head branch was modified"*)
                    warn "Der Branch hat sich geändert – bitte erneut auswerten."
                    ;;
                *"protected branch"* | *"required status"* | *"review required"*)
                    warn "Der Branch-Schutz von $BASE_BRANCH verlangt mehr, als die Automatik leisten darf."
                    ;;
            esac
            exit 1
            ;;
    esac
fi

comment_once "<!-- automerge-gruen -->" "### 🤖 Auto-Merge: in \`$BASE_BRANCH\` gemergt

- Merge-Commit: \`${merge_sha:0:8}\`
- Geprüft: Syntax, App-Logik-Tests, swift-format, Skript-/Workflow-Prüfung, iOS-Build mit Simulator-Smoke-Test

Der nächste Push auf diesen Branch landet wieder automatisch hier." || true

# ------------------------------------------------- Folge-Läufe auf dem Zielbranch

ensure_workflow_run() { # ensure_workflow_run <workflow-datei> <commit> <ref> <name>
    local workflow="$1" sha="$2" ref="$3" label="$4" runs existing
    if [ -z "$sha" ]; then
        warn "Merge-Commit unbekannt – $label wird nicht angestoßen."
        return 0
    fi
    if ! runs="$(gh api "repos/$REPO/actions/runs?head_sha=$sha&per_page=100" 2>/dev/null)"; then
        warn "Läufe zu ${sha:0:8} nicht lesbar – $label wird nicht angestoßen."
        return 0
    fi
    existing="$(printf '%s' "$runs" | jq -r --arg path ".github/workflows/$workflow" \
        '[.workflow_runs[]? | select(.path == $path)] | length' 2>/dev/null)"
    if [ "${existing:-0}" -gt 0 ]; then
        note "$label läuft für ${sha:0:8} bereits – kein zweiter Start."
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        note "[Dry-Run] würde $label für $ref starten."
        return 0
    fi
    if gh api -X POST "repos/$REPO/actions/workflows/$workflow/dispatches" \
        -f ref="$ref" >/dev/null 2>&1; then
        ok "$label gestartet."
    else
        warn "$label konnte nicht gestartet werden (Workflow auf dem Default-Branch? Rechte?)."
    fi
}

# Ein Merge mit dem GITHUB_TOKEN löst – eine Eigenheit von GitHub – selbst
# keine Workflows aus. Deshalb werden die beiden Folge-Läufe hier ausdrücklich
# angestoßen, aber nur wenn für den Merge-Commit noch keiner existiert.
if [ "$DISPATCH_CHECK" = "1" ]; then
    ensure_workflow_run "$CHECK_WORKFLOW" "$merge_sha" "$BASE_BRANCH" "Swift-Code-Prüfung"
fi
if [ "$DISPATCH_BUILD" = "1" ]; then
    ensure_workflow_run "$BUILD_WORKFLOW" "$merge_sha" "$BASE_BRANCH" "IPA-Build"
fi

exit 0
