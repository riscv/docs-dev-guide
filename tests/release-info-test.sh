#!/usr/bin/env bash
#
# Tests for scripts/release-info.sh -- the 2-digit (fixed-point decimal) release
# metadata helper. These lock the subtle bits: DECIMAL ordering (v0.8 > v0.61,
# which sort -V gets wrong), the +0.01 auto-increment, the milestone guard that
# refuses to auto-mint a manual gate, phase detection, and normalization.
#
# Run: tests/release-info-test.sh   (exit 0 = all passed)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# These assertions describe SPEC-mode behaviour, and release-info.sh resolves
# .docmode relative to its OWN location (repo_root = script dir/..), not the
# caller's cwd. Running the script in place would therefore inherit whatever
# mode THIS repository is in -- in a doc-mode repo every phase/display/floor
# assertion below would compare against the empty string that doc mode is
# supposed to return, and the suite would report failures for correct behaviour
# (see issue #152).
#
# So drive a copy of the script from a scratch repo with no .docmode: mode is
# pinned to spec no matter where the suite runs. The doc-mode assertions at the
# bottom keep their own scratch repo and opt IN to doc mode explicitly, which is
# the same pattern -- this just applies it to the whole suite. Nothing here
# needs the template's git history: the two blocks that DO need a repo (the
# untagged-build and .docmode sections) build their own.
specrepo="$(mktemp -d)"
mkdir -p "$specrepo/scripts"
cp "$here/../scripts/release-info.sh" "$specrepo/scripts/release-info.sh"
RI="$specrepo/scripts/release-info.sh"
trap 'rm -rf "$specrepo"' EXIT

pass=0
fail=0

# ok <description> <expected> <actual>
ok() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass=$(( pass + 1 ))
  else
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$desc" "$expected" "$actual"
  fi
}

# rc <description> <expected-rc> <command...>
rc() {
  local desc="$1" expected="$2"; shift 2
  "$@" >/dev/null 2>&1
  local actual=$?
  if [[ "$actual" == "$expected" ]]; then
    pass=$(( pass + 1 ))
  else
    fail=$(( fail + 1 ))
    printf 'FAIL: %s\n  expected rc: %s\n  actual rc:   %s\n' "$desc" "$expected" "$actual"
  fi
}

# --- decimal ordering (the sort -V / git version-sort trap) -----------------
ok "compare v0.8 > v0.61"        1  "$("$RI" compare v0.8 v0.61)"
ok "compare v0.61 < v0.8"       -1  "$("$RI" compare v0.61 v0.8)"
ok "compare v0.6 == v0.60"       0  "$("$RI" compare v0.6 v0.60)"
ok "compare v0.99 > v0.9"        1  "$("$RI" compare v0.99 v0.9)"
ok "compare v1.0 > v0.99"        1  "$("$RI" compare v1.0 v0.99)"
ok "compare v0.9 > v0.89"        1  "$("$RI" compare v0.9 v0.89)"
ok "max v0.8 v0.61 = v0.8"    v0.8  "$("$RI" max v0.8 v0.61)"
ok "max v0.70 v0.9 = v0.9"    v0.9  "$("$RI" max v0.70 v0.9)"

# --- normalization / canonical form -----------------------------------------
ok "normalize v0.60 -> v0.6"  v0.6   "$("$RI" normalize v0.60)"
ok "normalize v0.6 -> v0.6"   v0.6   "$("$RI" normalize v0.6)"
ok "normalize v0.7 -> v0.70"  v0.70  "$("$RI" normalize v0.7)"
ok "normalize 0.99 -> v0.99"  v0.99  "$("$RI" normalize 0.99)"
ok "normalize v1.0 -> v1.0"   v1.0   "$("$RI" normalize v1.0)"
ok "normalize v0.0 -> v0.0"   v0.0   "$("$RI" normalize v0.0)"

# --- auto-increment (+0.01) --------------------------------------------------
ok "next v0.6 -> v0.61"   v0.61  "$("$RI" next v0.6)"
ok "next v0.61 -> v0.62"  v0.62  "$("$RI" next v0.61)"
ok "next v0.69 -> v0.70"  v0.70  "$("$RI" next v0.69)"
ok "next v0.05 -> v0.06"  v0.06  "$("$RI" next v0.05)"
ok "next v0.0 -> v0.01"   v0.01  "$("$RI" next v0.0)"
ok "next v0.9 -> v0.91"   v0.91  "$("$RI" next v0.9)"

# --- milestone guard: auto-increment must never mint a manual gate ----------
rc "next v0.59 refuses v0.6"   10  "$RI" next v0.59
rc "next v0.79 refuses v0.8"   10  "$RI" next v0.79
rc "next v0.89 refuses v0.9"   10  "$RI" next v0.89
rc "next v0.98 refuses v0.99"  10  "$RI" next v0.98
rc "next v0.99 refuses v1.0"   10  "$RI" next v0.99
rc "next v1.0 has no successor"  2  "$RI" next v1.0

# --- is-milestone ------------------------------------------------------------
rc "v0.6 is a milestone"    0  "$RI" is-milestone v0.6
rc "v0.8 is a milestone"    0  "$RI" is-milestone v0.8
rc "v0.9 is a milestone"    0  "$RI" is-milestone v0.9
rc "v0.99 is a milestone"   0  "$RI" is-milestone v0.99
rc "v1.0 is a milestone"    0  "$RI" is-milestone v1.0
rc "v0.61 not a milestone"  1  "$RI" is-milestone v0.61
rc "v0.7 not a milestone"   1  "$RI" is-milestone v0.7

# --- phase detection (state achieved) ---------------------------------------
ok "phase v0.0"   draft-and-development  "$("$RI" phase v0.0)"
ok "phase v0.3"   draft-and-development  "$("$RI" phase v0.3)"
ok "phase v0.59"  draft-and-development  "$("$RI" phase v0.59)"
ok "phase v0.6"   development-complete   "$("$RI" phase v0.6)"
ok "phase v0.72"  development-complete   "$("$RI" phase v0.72)"
ok "phase v0.8"   stabilized             "$("$RI" phase v0.8)"
ok "phase v0.85"  stabilized             "$("$RI" phase v0.85)"
ok "phase v0.9"   frozen                 "$("$RI" phase v0.9)"
ok "phase v0.98"  frozen                 "$("$RI" phase v0.98)"
ok "phase v0.99"  ratification-ready     "$("$RI" phase v0.99)"
ok "phase v1.0"   ratified               "$("$RI" phase v1.0)"

# --- phase floors round-trip -------------------------------------------------
ok "floor draft-and-development" v0.0   "$("$RI" phase-floor-version draft-and-development)"
ok "floor development-complete"  v0.6   "$("$RI" phase-floor-version development-complete)"
ok "floor stabilized"            v0.8   "$("$RI" phase-floor-version stabilized)"
ok "floor frozen"                v0.9   "$("$RI" phase-floor-version frozen)"
ok "floor ratification-ready"    v0.99  "$("$RI" phase-floor-version ratification-ready)"
ok "floor ratified"              v1.0   "$("$RI" phase-floor-version ratified)"

# --- display labels ----------------------------------------------------------
ok "display v0.8"  Stabilized  "$("$RI" display v0.8)"
ok "display v1.0"  Ratified    "$("$RI" display v1.0)"

# --- publication milestone is gone ------------------------------------------
rc "publication is not a valid phase floor"  2  "$RI" phase-floor-version publication

# --- interim build non-tagged versions ---------------------------------------
ok "normalize v0.60-a1b2c3d" "v0.6-a1b2c3d" "$("$RI" normalize v0.60-a1b2c3d)"
rc "v0.6-a1b2c3d not a milestone" 1 "$RI" is-milestone v0.6-a1b2c3d
ok "phase v0.6-a1b2c3d" development-complete "$("$RI" phase v0.6-a1b2c3d)"
# Suffix handling stays generic, incl. the legacy date-bearing dev form.
ok "normalize v0.60-a1b2c3d-20260730" "v0.6-a1b2c3d-20260730" "$("$RI" normalize v0.60-a1b2c3d-20260730)"
ok "phase v0.6-a1b2c3d-20260730" development-complete "$("$RI" phase v0.6-a1b2c3d-20260730)"

# --- dev version carries NO date (#131) --------------------------------------
# The Makefile appends DATE_STAMP to build the ARC filename
# <short>-v<version>-<YYYYMMDD>.pdf. A dev version that embedded its own build
# date therefore stamped the date TWICE on every local build. Assert the emitted
# shape is <latest>-<sha> so the concatenation stays ARC-shaped.
devrepo="$(mktemp -d)"
(
  cd "$devrepo" || exit 1
  git init -q .
  git -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  git tag v0.6
  git -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m untagged
) >/dev/null 2>&1
ri_clean() { (cd "$devrepo" && env -u VERSION -u RELEASE_VERSION -u GITHUB_REF_NAME -u GITHUB_REF "$RI" "$@"); }
dev_sha="$(cd "$devrepo" && git rev-parse --short HEAD)"
dev_version="$(ri_clean version)"
ok "untagged build version is <latest>-<sha>"  "v0.6-$dev_sha"  "$dev_version"
ok "untagged build version has no date stamp"  ""  "$(printf '%s' "$dev_version" | grep -oE '[0-9]{8}' || true)"
ok "untagged build phase still resolves"  development-complete  "$(ri_clean phase "$dev_version")"
(cd "$devrepo" && git checkout -q v0.6)
ok "tagged build version is the bare tag"  v0.6  "$(ri_clean version)"
rm -rf "$devrepo"

# --- 3-digit input is rejected ----------------------------------------------
rc "normalize rejects v0.6.0"  2  "$RI" normalize v0.6.0
rc "normalize rejects v0.99.1" 2  "$RI" normalize v0.99.1

# --- .docmode (issue #110) ----------------------------------------------------
# .docmode is resolved relative to release-info.sh's OWN location (repo_root =
# $here/..), not the caller's cwd, so exercising it needs a scratch repo that
# carries its own copy of the script under scripts/ -- same as $RI itself.
modrepo="$(mktemp -d)"
mkdir -p "$modrepo/scripts"
cp "$RI" "$modrepo/scripts/release-info.sh"
(
  cd "$modrepo" || exit 1
  git init -q .
  git -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  git tag v0.8
) >/dev/null 2>&1
mod_ri() { (cd "$modrepo" && env -u VERSION -u RELEASE_VERSION -u GITHUB_REF_NAME -u GITHUB_REF ./scripts/release-info.sh "$@"); }

ok "mode defaults to spec (no .docmode)"  spec  "$(mod_ri mode)"
ok "phase unaffected in spec mode"  stabilized  "$(mod_ri phase v0.8)"

echo doc > "$modrepo/.docmode"
ok "mode is doc when .docmode contains doc"  doc  "$(mod_ri mode)"
ok "phase is empty in doc mode"        ""  "$(mod_ri phase v0.8)"
ok "phase-floor-version is empty in doc mode"  ""  "$(mod_ri phase-floor-version stabilized)"
ok "display is empty in doc mode"      ""  "$(mod_ri display v0.8)"
ok "milestone is empty in doc mode"    ""  "$(mod_ri milestone v0.8)"
ok "notice is empty in doc mode"       ""  "$(mod_ri notice v0.8)"
ok "revremark is empty in doc mode"    ""  "$(mod_ri revremark v0.8)"
ok "version is unaffected in doc mode"       v0.8  "$(mod_ri version)"
ok "compare is unaffected in doc mode"          1  "$(mod_ri compare v0.8 v0.6)"
ok "is-milestone is unaffected in doc mode"     0  "$(mod_ri is-milestone v0.8; echo $?)"
ok "all reports MODE=doc and blank phase fields" \
  "$(printf 'MODE=doc\nVERSION=v0.8\nPHASE=\nPHASE_DISPLAY=\nMILESTONE=\nPHASE_NOTICE=\nREVMARK=')" \
  "$(mod_ri all)"

echo bogus > "$modrepo/.docmode"
ok "unrecognized .docmode value falls back to spec"  spec  "$(mod_ri mode 2>/dev/null)"

rm -rf "$modrepo"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
