#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release_script="$repo_root/scripts/build-testflight-internal.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    fail "$message (expected '$expected', got '$actual')"
  fi
}

newer_build="$(
  cd /tmp
  TESTFLIGHT_NOW=202609011005 \
    "$release_script" --print-build-number --last-build 202609011004
)"
assert_equal \
  "202609011005" \
  "$newer_build" \
  "a newer timestamp must be used unchanged"

incremented_build="$(
  cd /tmp
  TESTFLIGHT_NOW=202609011004 \
    "$release_script" --print-build-number --last-build 202609011004
)"
assert_equal \
  "202609011005" \
  "$incremented_build" \
  "a same-minute rebuild must increment the previous build"

if TESTFLIGHT_NOW=202609011006 \
  "$release_script" --print-build-number --last-build invalid \
  >/dev/null 2>&1; then
  fail "a malformed previous build must be rejected"
fi

pubspec_before="$(shasum -a 256 "$repo_root/mobile/pubspec.yaml" | awk '{print $1}')"
state_before="$(shasum -a 256 "$repo_root/scripts/testflight-internal-last-build.txt" | awk '{print $1}')"
dry_run_output="$(
  TESTFLIGHT_NOW=202609011006 \
    "$release_script" --dry-run --last-build 202609011004
)"
pubspec_after="$(shasum -a 256 "$repo_root/mobile/pubspec.yaml" | awk '{print $1}')"
state_after="$(shasum -a 256 "$repo_root/scripts/testflight-internal-last-build.txt" | awk '{print $1}')"

assert_equal "$pubspec_before" "$pubspec_after" "dry-run must not edit pubspec.yaml"
assert_equal "$state_before" "$state_after" "dry-run must not advance release state"

if [[ "$dry_run_output" != *"flutter build ipa --release --build-name=1.0.0 --build-number=202609011006"* ]]; then
  fail "dry-run must show the iOS-only Flutter build-number override"
fi

echo "PASS: TestFlight internal build workflow"
