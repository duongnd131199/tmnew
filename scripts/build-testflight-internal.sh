#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
mobile_dir="$repo_root/mobile"
state_file="$script_dir/testflight-internal-last-build.txt"

mode="build"
requested_last_build=""

usage() {
  cat <<'EOF'
Usage: scripts/build-testflight-internal.sh [options]

Builds an iOS IPA with a monotonically increasing TestFlight build number
without changing the Android-compatible build metadata in mobile/pubspec.yaml.

Options:
  --last-build NUMBER       Latest build observed in App Store Connect.
  --print-build-number      Print the next build number and exit.
  --dry-run                 Print the Flutter build command and exit.
  -h, --help                Show this help.
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

validate_testflight_build() {
  local value="$1"
  local label="$2"

  if [[ ! "$value" =~ ^[0-9]{12}$ ]]; then
    fail "$label must contain exactly 12 digits in YYYYMMDDHHmm format."
  fi
}

while (($# > 0)); do
  case "$1" in
    --last-build)
      (($# >= 2)) || fail "--last-build requires a value."
      requested_last_build="$2"
      shift 2
      ;;
    --print-build-number)
      mode="print"
      shift
      ;;
    --dry-run)
      mode="dry-run"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

[[ -f "$state_file" ]] || fail "Missing release state: $state_file"

stored_last_build="$(tr -d '[:space:]' < "$state_file")"
validate_testflight_build "$stored_last_build" "Stored TestFlight build"

effective_last_build="$stored_last_build"
if [[ -n "$requested_last_build" ]]; then
  validate_testflight_build "$requested_last_build" "App Store Connect build"
  if ((10#$requested_last_build > 10#$effective_last_build)); then
    effective_last_build="$requested_last_build"
  fi
fi

current_timestamp="${TESTFLIGHT_NOW:-$(date +%Y%m%d%H%M)}"
validate_testflight_build "$current_timestamp" "Current timestamp"

if ((10#$current_timestamp > 10#$effective_last_build)); then
  next_build="$current_timestamp"
else
  printf -v next_build '%012d' "$((10#$effective_last_build + 1))"
fi

if [[ "$mode" == "print" ]]; then
  echo "$next_build"
  exit 0
fi

pubspec_file="$mobile_dir/pubspec.yaml"
[[ -f "$pubspec_file" ]] || fail "Missing Flutter manifest: $pubspec_file"

version_value="$(sed -n 's/^version:[[:space:]]*//p' "$pubspec_file")"
version_name="${version_value%%+*}"
android_build="${version_value##*+}"

[[ "$version_value" == *+* ]] || fail "pubspec.yaml version must include build metadata."
[[ "$android_build" =~ ^[0-9]+$ ]] || fail "Android build metadata must be numeric."
((android_build >= 1 && android_build <= 2100000000)) || \
  fail "Android build metadata must stay between 1 and 2100000000."

build_command=(
  flutter build ipa
  --release
  "--build-name=$version_name"
  "--build-number=$next_build"
)

if [[ "$mode" == "dry-run" ]]; then
  printf 'cd %q\n' "$mobile_dir"
  printf '%q ' "${build_command[@]}"
  printf '\n'
  echo "pubspec.yaml remains unchanged at $version_value"
  exit 0
fi

(
  cd "$mobile_dir"
  "${build_command[@]}"
)

archive_source="$mobile_dir/build/ios/archive/Runner.xcarchive"
[[ -d "$archive_source" ]] || fail "Flutter did not create $archive_source"

archive_build="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :ApplicationProperties:CFBundleVersion' \
    "$archive_source/Info.plist"
)"
[[ "$archive_build" == "$next_build" ]] || \
  fail "Archive build $archive_build does not match expected build $next_build."

shopt -s nullglob
ipa_files=("$mobile_dir"/build/ios/ipa/*.ipa)
shopt -u nullglob
(( ${#ipa_files[@]} == 1 )) || fail "Expected exactly one IPA in mobile/build/ios/ipa."

ipa_build="$(
  unzip -p "${ipa_files[0]}" Payload/Runner.app/Info.plist |
    plutil -extract CFBundleVersion raw -
)"
[[ "$ipa_build" == "$next_build" ]] || \
  fail "IPA build $ipa_build does not match expected build $next_build."

xcode_archive_day="$(date +%Y-%m-%d)"
xcode_archive_dir="$HOME/Library/Developer/Xcode/Archives/$xcode_archive_day"
xcode_archive="$xcode_archive_dir/MetaTrader 5 $next_build.xcarchive"

mkdir -p "$xcode_archive_dir"
[[ ! -e "$xcode_archive" ]] || fail "Xcode archive already exists: $xcode_archive"
ditto "$archive_source" "$xcode_archive"

state_temp="$(mktemp "$script_dir/.testflight-internal-last-build.XXXXXX")"
printf '%s\n' "$next_build" > "$state_temp"
mv "$state_temp" "$state_file"

cat <<EOF
Prepared TestFlight Internal build $version_name ($next_build).
Xcode archive: $xcode_archive

Required distribution flow:
1. Xcode Organizer → Distribute App.
2. Select TestFlight Internal Only.
3. Upload and wait for App Store Connect analysis.
4. Verify Internal Testers shows build $next_build with status Testing.
5. Existing internal testers refresh TestFlight and tap Update; do not reinvite them.
EOF
