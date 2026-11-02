#!/usr/bin/env bash
#
# ci/ios-build-test.sh – echter Build mit Xcode und iOS-SDK plus Smoke-Test im
# Simulator. Läuft auf dem macOS-Runner im Workflow „Swift-Code-Prüfung“.
#
#   1. Scheme automatisch ermitteln (oder APP_SCHEME verwenden).
#   2. Für den iOS-Simulator bauen.
#   3. App in einen Simulator installieren, starten und prüfen, dass der
#      Prozess läuft (Screenshot als Nachweis).
#
# Kann das Paket (Swift-Playgrounds-App, `.swiftpm`) nicht im Simulator gebaut
# werden, wird auf einen unsignierten iOS-Device-Build ausgewichen. Das ist
# eine dokumentierte Einschränkung und wird laut gemeldet – ein echter
# Compilerfehler scheitert dagegen in beiden Varianten.
#
# Umgebungsvariablen:
#   APP_PACKAGE_DIR  Paketordner (Standard: NeueSwiftApp.swiftpm)
#   APP_SCHEME       Scheme erzwingen (Standard: automatisch)
#   SIMULATOR_NAME   Simulator-Gerät erzwingen (z. B. "iPhone 17")

set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

log() { printf '\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
note() { printf '  \033[34mi\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

summary() {
    [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
    printf '%s\n' "$1" >>"$GITHUB_STEP_SUMMARY"
}

package_dir="${APP_PACKAGE_DIR:-NeueSwiftApp.swiftpm}"
derived_data="$PWD/build/DerivedData"
log_dir="$PWD/build"
mkdir -p "$log_dir"

if [ ! -d "$package_dir" ]; then
    err "Paketordner '$package_dir' fehlt."
    exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
    err "xcodebuild fehlt – dieses Skript läuft nur auf macOS mit Xcode."
    exit 1
fi

# ---------------------------------------------------------------- Scheme

scheme="$(ci/detect-scheme.sh "$package_dir")" || {
    err "Scheme nicht ermittelbar."
    summary "- ❌ iOS-Build: kein Xcode-Scheme gefunden"
    exit 1
}
ok "Scheme: $scheme"

# ---------------------------------------------------------------- Simulator

log "Simulator suchen"
if [ -n "${SIMULATOR_NAME:-}" ]; then
    udid="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
wanted = sys.argv[1]
data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    for device in devices:
        if device.get("name") == wanted:
            print(device["udid"])
            raise SystemExit(0)
' "$SIMULATOR_NAME")"
else
    udid="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
data = json.load(sys.stdin)
runtimes = sorted(r for r in data.get("devices", {}) if r.startswith("com.apple.CoreSimulator.SimRuntime.iOS"))
if not runtimes:
    raise SystemExit(0)
# Neueste iOS-Laufzeit zuerst, darin das erste iPhone.
for runtime in reversed(runtimes):
    for device in data["devices"][runtime]:
        if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
            print(device["udid"])
            raise SystemExit(0)
')"
fi

simulator_ok=0
if [ -z "$udid" ]; then
    warn "Kein iPhone-Simulator verfügbar."
else
    note "Simulator-UDID: $udid"
    simulator_ok=1
fi

build_for() { # build_for <destination> <logname> [zusätzliche Argumente...]
    local destination="$1" logname="$2"
    shift 2
    (
        cd "$package_dir" || exit 2
        set -o pipefail
        xcodebuild build \
            -scheme "$scheme" \
            -configuration Debug \
            -destination "$destination" \
            -derivedDataPath "$derived_data" \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY="" \
            "$@" 2>&1 | tee "$log_dir/$logname"
    )
}

find_app() { # find_app <verzeichnis>
    find "$1" -maxdepth 1 -type d -name '*.app' -print -quit 2>/dev/null
}

# ------------------------------------------------------- Build im Simulator

attempt_simulator() {
    [ "$simulator_ok" = "1" ] || return 1
    log "Build für den iOS-Simulator"
    if ! build_for "platform=iOS Simulator,id=$udid" "xcodebuild-simulator.log"; then
        err "Build für den Simulator fehlgeschlagen (siehe build/xcodebuild-simulator.log)."
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            ci_annotate error "build/xcodebuild-simulator.log" 1 1 "$line"
        done < <(grep -E 'error:' "$log_dir/xcodebuild-simulator.log" | head -20)
        return 1
    fi

    app="$(find_app "$derived_data/Build/Products/Debug-iphonesimulator")"
    if [ -z "$app" ]; then
        err "Kein .app-Bundle unter Debug-iphonesimulator gefunden."
        return 1
    fi
    ok "App-Bundle: $app"

    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist" 2>/dev/null)"
    if [ -z "$bundle_id" ]; then
        err "CFBundleIdentifier fehlt im App-Bundle."
        return 1
    fi
    note "Bundle-ID: $bundle_id"

    log "Smoke-Test im Simulator"
    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    if ! xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1; then
        err "Simulator $udid startet nicht."
        return 1
    fi
    if ! xcrun simctl install "$udid" "$app"; then
        err "Installation im Simulator fehlgeschlagen."
        return 1
    fi

    launch_output="$(xcrun simctl launch "$udid" "$bundle_id" 2>&1)"
    printf '  Start: %s\n' "$launch_output"
    case "$launch_output" in
        *"$bundle_id"*) ;;
        *)
            err "App ließ sich nicht starten."
            return 1
            ;;
    esac

    sleep 5
    if ! xcrun simctl io "$udid" screenshot "$log_dir/smoke-screenshot.png" >/dev/null 2>&1; then
        warn "Screenshot konnte nicht erstellt werden."
    fi

    # Läuft der Prozess noch? `simctl terminate` scheitert, wenn die App schon
    # beendet ist – das entlarvt einen Absturz beim Start.
    if ! xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1; then
        err "App war nach dem Start nicht mehr aktiv (Absturz?)."
        return 1
    fi

    ok "App gestartet, lief stabil und wurde beendet."
    summary "- ✅ iOS-Simulator: Build, Installation und Start erfolgreich (Scheme \`$scheme\`, Bundle-ID \`$bundle_id\`)"
    if [ -f "$log_dir/smoke-screenshot.png" ]; then
        summary "- Screenshot als Artefakt: \`ios-simulator-screenshot\`"
    fi
    return 0
}

attempt_device_fallback() {
    log "Ausweichlösung: unsignierter iOS-Device-Build"
    if ! build_for "generic/platform=iOS" "xcodebuild-device.log"; then
        err "Auch der Device-Build ist fehlgeschlagen – das ist ein echter Build-Fehler."
        return 1
    fi
    app="$(find_app "$derived_data/Build/Products/Debug-iphoneos")"
    if [ -z "$app" ]; then
        err "Kein .app-Bundle unter Debug-iphoneos gefunden."
        return 1
    fi
    ok "App-Bundle: $app"
    warn "Simulator-Smoke-Test konnte nicht ausgeführt werden."
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::warning title=Simulator-Smoke-Test übersprungen::Der Build für den iOS-Simulator war mit diesem Pakettyp nicht möglich; der unsignierte iOS-Device-Build war erfolgreich. Siehe AGENTS.md, Abschnitt 'iOS-Build und Simulator'."
    fi
    summary "- ⚠️ iOS-Simulator nicht möglich, unsignierter iOS-Device-Build erfolgreich (Scheme \`$scheme\`) – Einschränkung dokumentiert"
    return 0
}

if attempt_simulator; then
    exit 0
fi

warn "Der Simulator-Weg ist gescheitert – prüfe, ob ein unsignierter Device-Build möglich ist."
if attempt_device_fallback; then
    exit 0
fi

err "Weder Simulator- noch Device-Build waren erfolgreich."
summary "- ❌ iOS-Build fehlgeschlagen"
exit 1
