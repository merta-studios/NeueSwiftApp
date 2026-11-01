#!/usr/bin/env bash
#
# ci/build-ipa.sh – baut eine unsignierte Release-IPA auf einem macOS-Runner.
#
#   ci/build-ipa.sh
#
# Ergebnis: build/NeueSwiftApp.ipa mit Payload/<App>.app darin, plus
# SHA-256-Prüfsumme. Ohne Signatur ist die Datei nicht installierbar; sie muss
# vorher mit einer eigenen Apple-ID signiert werden (Sideloadly, AltStore, …).
# Es werden dafür keine Zertifikate oder Zugangsdaten benötigt oder hinterlegt.
#
# Umgebungsvariablen:
#   APP_PACKAGE_DIR  Paketordner (Standard: NeueSwiftApp.swiftpm)
#   APP_SCHEME       Scheme erzwingen (Standard: automatisch)
#   IPA_NAME         Dateiname ohne Endung (Standard: NeueSwiftApp)

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
ipa_name="${IPA_NAME:-NeueSwiftApp}"
derived_data="$PWD/build/DerivedData"
out_dir="$PWD/build"
mkdir -p "$out_dir"

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
    summary "- ❌ IPA-Build: kein Xcode-Scheme gefunden"
    exit 1
}
ok "Scheme: $scheme"

# ---------------------------------------------------------------- Build

log "Unsignierter Release-Build für iOS"
(
    cd "$package_dir" || exit 2
    set -o pipefail
    xcodebuild build \
        -scheme "$scheme" \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -derivedDataPath "$derived_data" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGN_ENTITLEMENTS="" \
        clean build 2>&1 | tee "$out_dir/xcodebuild-ipa.log"
) || {
    err "Build fehlgeschlagen (siehe build/xcodebuild-ipa.log)."
    summary "- ❌ IPA-Build: xcodebuild fehlgeschlagen"
    exit 1
}

app_dir="$(find "$derived_data/Build/Products/Release-iphoneos" -maxdepth 1 -type d -name '*.app' -print -quit 2>/dev/null)"
if [ -z "$app_dir" ]; then
    err "Kein .app-Bundle unter Release-iphoneos gefunden."
    summary "- ❌ IPA-Build: App-Bundle fehlt"
    exit 1
fi
app_name="$(basename "$app_dir")"
ok "App-Bundle: $app_dir"

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_dir/Info.plist" 2>/dev/null)"
short_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_dir/Info.plist" 2>/dev/null)"
build_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_dir/Info.plist" 2>/dev/null)"
min_os="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$app_dir/Info.plist" 2>/dev/null)"

for pair in "CFBundleIdentifier:$bundle_id" "CFBundleShortVersionString:$short_version" "CFBundleVersion:$build_version"; do
    if [ -z "${pair#*:}" ]; then
        err "${pair%%:*} fehlt im App-Bundle."
        summary "- ❌ IPA-Build: Info.plist unvollständig"
        exit 1
    fi
done
note "Bundle-ID: $bundle_id"
note "Version: $short_version ($build_version), MinimumOS: ${min_os:-unbekannt}"

# ---------------------------------------------------------------- IPA packen

log "IPA paketieren"
payload_root="$out_dir/ipa-staging"
rm -rf "$payload_root" "$out_dir/$ipa_name.ipa"
mkdir -p "$payload_root/Payload"
cp -R "$app_dir" "$payload_root/Payload/"

if [ ! -f "$payload_root/Payload/$app_name/Info.plist" ]; then
    err "Payload enthält kein vollständiges App-Bundle."
    exit 1
fi

(
    cd "$payload_root" || exit 2
    zip -qry "$out_dir/$ipa_name.ipa" Payload
) || {
    err "zip fehlgeschlagen."
    exit 1
}

if [ ! -f "$out_dir/$ipa_name.ipa" ]; then
    err "$ipa_name.ipa wurde nicht erzeugt."
    exit 1
fi

if ! unzip -Z1 "$out_dir/$ipa_name.ipa" | grep -qF "Payload/$app_name/Info.plist"; then
    err "IPA enthält nicht Payload/$app_name/Info.plist."
    exit 1
fi

sha256_of() { # sha256_of <datei> – macOS hat shasum, Linux hat sha256sum
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1"
    else
        shasum -a 256 "$1"
    fi
}
sha256_of "$out_dir/$ipa_name.ipa" >"$out_dir/$ipa_name.ipa.sha256"
rm -rf "$payload_root"

if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::notice title=IPA::%s.ipa mit Payload/%s (Bundle-ID %s, Version %s (%s))\n' \
        "$ipa_name" "$app_name" "$bundle_id" "$short_version" "$build_version"
fi

ok "IPA: $out_dir/$ipa_name.ipa ($(ls -lh "$out_dir/$ipa_name.ipa" | awk '{print $5}'))"
note "Prüfsumme: $(cut -d' ' -f1 <"$out_dir/$ipa_name.ipa.sha256")"

summary "- ✅ IPA gebaut: \`$ipa_name.ipa\` (Payload/$app_name), Bundle-ID \`$bundle_id\`, Version $short_version ($build_version)"
summary "- Die IPA ist **unsigniert** und muss vor der Installation mit einer eigenen Apple-ID signiert werden."

exit 0
