#!/usr/bin/env bash
# Stamp the Antora component descriptor (antora.yml) with the current release
# version and phase so the HTML site version stays in EXACT lockstep with the
# ARC submission PDF, per the ARC Author Guide (version = the vX.Y tag; the
# title-page revision line is "Version <ver>, <date>: <Display>").
#
# The PDF derives its version dynamically at build time from the git tag via
# scripts/release-info.sh. Antora, by contrast, reads a STATIC version from the
# committed antora.yml, so a release must stamp that file. This is the Antora
# analogue of scripts/update-spec-state.sh (which stamps SPEC_STATE.md).
#
# Usage: scripts/stamp-antora-version.sh [version] [date]
#   version  vX.Y (default: scripts/release-info.sh version -> latest tag)
#   date     YYYY-MM-DD (default: today)
#
# Idempotent: it replaces the values of existing keys in antora.yml in place and
# leaves comments, nav, and other attributes untouched.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
antora_yml="$repo_root/antora.yml"

version="${1:-$("$here/release-info.sh" version)}"
date="${2:-$(date +%Y-%m-%d)}"

# Normalise and validate the version (vX.Y) through the shared helper.
version="$("$here/release-info.sh" normalize "$version")"

# .docmode ("spec" default | "doc") -- see scripts/release-info.sh. In doc mode
# phase/display/notice all resolve to "" (the phase surface is neutralized), so
# the page-phase* keys below are dropped from the required set rather than
# stamped with empty values.
mode="$("$here/release-info.sh" mode)"

phase="$("$here/release-info.sh" phase "$version")"
phase_display="$("$here/release-info.sh" display "$version")"
phase_notice="$("$here/release-info.sh" notice "$version")"

# YAML single-quote escaping (double any embedded single quote).
yq_squote() { printf "'%s'" "${1//\'/\'\'}"; }

export A_VERSION="$version"
export A_REVDATE="$date"
export A_PHASE="$phase"
export A_PHASE_DISPLAY="$(yq_squote "$phase_display")"
export A_PHASE_NOTICE="$(yq_squote "$phase_notice")"

tmp="$(mktemp)"
# Replace values by unique key. The trailing ':' in each pattern anchors the key
# so e.g. `page-phase:` never matches `page-phase-display:`.
#
# Every value we write is a single-line quoted scalar. If a formatter or a hand
# edit has line-wrapped one of these into a plain MULTI-line scalar, replacing
# just the key's first line would orphan the continuation after a now-closed
# quoted scalar and silently produce invalid YAML. So after replacing a key we
# also drop any following lines that are indented deeper than it -- those are
# the remains of its wrapped value. `cont` holds the indent of the key just
# written, or -1 when we are not inside a replaced value.
#
# Each key must be found EXACTLY once; otherwise we would exit 0 having stamped
# nothing (or having stamped twice), and the release workflow's `git diff` check
# would read that as "already up to date". Fail loudly instead -- see END.
awk -v mode="$mode" '
  BEGIN {
    cont = -1
    if (mode == "doc") {
      nreq = split("version revnumber revdate", req, " ")
    } else {
      nreq = split("version revnumber revdate display notice phase", req, " ")
    }
  }

  cont >= 0 {
    if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) {
      cont = -1
    } else {
      match($0, /^[[:space:]]*/)
      if (RLENGTH > cont) next
      cont = -1
    }
  }

  /^version:/                { print "version: " ENVIRON["A_VERSION"];                      seen["version"]++;   cont = 0; next }
  /^    page-revnumber:/     { print "    page-revnumber: " ENVIRON["A_VERSION"];           seen["revnumber"]++; cont = 4; next }
  /^    page-revdate:/       { print "    page-revdate: " ENVIRON["A_REVDATE"];             seen["revdate"]++;   cont = 4; next }
  /^    page-phase-display:/ { print "    page-phase-display: " ENVIRON["A_PHASE_DISPLAY"]; seen["display"]++;   cont = 4; next }
  /^    page-phase-notice:/  { print "    page-phase-notice: " ENVIRON["A_PHASE_NOTICE"];   seen["notice"]++;    cont = 4; next }
  /^    page-phase:/         { print "    page-phase: " ENVIRON["A_PHASE"];                 seen["phase"]++;     cont = 4; next }
  { print }

  END {
    bad = ""
    for (i = 1; i <= nreq; i++)
      if (seen[req[i]] != 1)
        bad = bad sprintf("  %-12s found %d time(s), expected 1\n", req[i], seen[req[i]] + 0)
    if (bad != "") {
      printf "stamp-antora-version: antora.yml does not have the expected keys:\n%s", bad > "/dev/stderr"
      exit 3
    }
  }
' "$antora_yml" > "$tmp"
mv "$tmp" "$antora_yml"

# Assert the result still parses. Without this the release workflow would commit
# a corrupt antora.yml to main and the site version would stop tracking the PDF.
if python3 -c 'import yaml' 2>/dev/null; then
  python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$antora_yml" || {
    echo "stamp-antora-version: stamped antora.yml is not valid YAML (see above)" >&2
    exit 4
  }
else
  echo "stamp-antora-version: WARNING: python3 + PyYAML unavailable; skipped YAML validation" >&2
fi

if [[ "$mode" == "doc" ]]; then
  echo "Stamped antora.yml: version=$version date=$date (doc mode: phase surface not stamped)"
else
  echo "Stamped antora.yml: version=$version phase=$phase ($phase_display) date=$date"
fi
