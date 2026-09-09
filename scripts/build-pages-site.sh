#!/usr/bin/env bash
# Build the standalone Antora HTML site that this repo publishes to its own
# GitHub Pages site (see .github/workflows/publish-site.yml).
#
# This is NOT the riscv.org production site. The production site is assembled by
# the central playbook (github.com/riscv-admin/antora.riscv.org) from 20+ content
# sources, of which this repo is one; see ANTORA.md "Production model". What this
# script builds is a self-contained, per-repo copy of the same content -- useful
# on its own for a repo seeded from this template, and useful here as a
# full-fidelity preview of how the content renders.
#
# Usage: scripts/build-pages-site.sh [site-url]
#   site-url  Base URL the site is served from, e.g. https://riscv.github.io/my-spec
#             (GitHub Actions passes the actions/configure-pages base_url).
#             Omitted for local runs -- the playbook's own site.url is kept.
#
# Environment:
#   VERSION   Release version to stamp (default: scripts/release-info.sh version)
#   DATE      Release date, YYYY-MM-DD (default: today)
#   NO_STAMP  Set to 1 to skip version stamping (leave antora.yml as committed)
#   TAG_GLOB  Which tags to consider publishing (default: v*)
#   DEV_VERSION_LABEL
#             Version label for untagged builds (default: dev) -- see step 1b
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
cd "$repo_root"

site_url="${1:-}"
tag_glob="${TAG_GLOB:-v*}"
DEV_VERSION_LABEL="${DEV_VERSION_LABEL:-dev}"
generated_playbook="$repo_root/antora-pages-playbook.yml"
output_dir="./build/pages-site"

# Read the value of a top-level `version:` key out of an antora.yml on stdin.
descriptor_version() {
  awk '/^version:/ { gsub(/^[ \t]*version:[ \t]*/, ""); gsub(/^["'\'']|["'\'']$/, ""); print; exit }'
}

# ---------------------------------------------------------------------------
# 1. Version stamp
#
# Antora reads a STATIC version from antora.yml, and the ARC Author Guide
# requires the HTML site version to match the PDF exactly. Stamp the WORKTREE
# from scripts/release-info.sh -- the same source the PDF build uses -- so the
# published version is right even when the checked-out commit's committed
# antora.yml has not been stamped yet (on a tag push, the release workflow
# stamps main only AFTER the tag exists). The edit is never committed here.
# ---------------------------------------------------------------------------
if [ "${NO_STAMP:-0}" = "1" ]; then
  echo "==> Skipping version stamp (NO_STAMP=1)"
else
  echo "==> Stamping antora.yml"
  "$here/stamp-antora-version.sh" "${VERSION:-}" "${DATE:-$(date +%Y-%m-%d)}"
fi
head_version="$(descriptor_version < "$repo_root/antora.yml")"
echo "    component version: ${head_version:-<none>}"

# ---------------------------------------------------------------------------
# 1b. Keep the published version string SHORT
#
# The RISC-V UI floats the version selector alongside the navigation tree
# (.version-box{float:right} + .nav-version-group{overflow:hidden}), so the nav
# gets only the width left over beside the selector, and the selector is as wide
# as its longest version string. A release tag is short (vX.Y) and renders fine.
# An UNTAGGED build is not: release-info.sh returns a dev version of the form
# vX.YY-<sha>-<date> (22 chars), which squeezes the nav to about three
# characters per line -- and that is exactly what the first manual publish in a
# freshly seeded repo produces.
#
# So untagged builds publish under a short, fixed label. This also stops every
# dispatch from minting a brand-new /spec-sample/<sha>/ path that the next
# publish orphans; /spec-sample/dev/ stays linkable. The full dev version is
# still recorded on the cover page, via the page-revnumber stamped above.
# ---------------------------------------------------------------------------
case "$head_version" in
  *-*)
    echo "    untagged build -- publishing as '$DEV_VERSION_LABEL' (cover keeps $head_version)"
    tmp_yml="$(mktemp)"
    awk -v label="$DEV_VERSION_LABEL" '
      !done && /^version:/ { print "version: " label; done = 1; next }
      { print }
    ' "$repo_root/antora.yml" > "$tmp_yml"
    mv "$tmp_yml" "$repo_root/antora.yml"
    head_version="$DEV_VERSION_LABEL"
    ;;
esac

# ---------------------------------------------------------------------------
# 2. Stage the cover logo
#
# index.adoc renders the logo through the `cover-logo` attribute, which defaults
# to the central `common` component (antora.yml). No such component exists in a
# single-repo build, so vendor the copy that already ships in the docs-resources
# submodule -- the same asset the PDF build uses -- into this component's images
# family and point the attribute at it. Staged, not committed (.gitignore).
# ---------------------------------------------------------------------------
logo_src="$repo_root/docs-resources/images/risc-v_logo.svg"
logo_dest_dir="$repo_root/modules/ROOT/images"
cover_logo=""
if [ -f "$logo_src" ]; then
  mkdir -p "$logo_dest_dir"
  cp "$logo_src" "$logo_dest_dir/risc-v_logo.svg"
  cover_logo="risc-v_logo.svg"
  echo "==> Staged cover logo from docs-resources"
else
  echo "==> WARNING: $logo_src not found (submodule not initialized?)."
  echo "    Falling back to the 'common::' logo, which cannot resolve in a"
  echo "    single-repo build -- the cover image will be broken. Run:"
  echo "        git submodule update --init --recursive"
fi

# ---------------------------------------------------------------------------
# 3. Choose which versions to publish
#
# Always publish the checked-out worktree (branches: HEAD), which carries the
# stamp applied above.
#
# Additionally publish any RELEASE TAG that already carries a correctly stamped
# descriptor, so the site grows a version dropdown across releases. A tag
# qualifies only if it contains an antora.yml whose `version:` equals the tag
# itself. Two reasons this is strict:
#   * Antora aborts the whole build on any ref that has no antora.yml, so tags
#     predating the Antora migration MUST be filtered out here.
#   * A tag stamped with some other version (e.g. the template default v0.0.0,
#     or the previous release, because stamping currently happens on main after
#     the tag is cut) would publish under a wrong or duplicate version path.
# Today that means no tag qualifies and the site publishes a single version.
# Once the release flow stamps antora.yml BEFORE cutting the tag, older releases
# start appearing here automatically -- no change to this script.
# ---------------------------------------------------------------------------
sources=()
tag_list=()
while IFS= read -r tag; do
  [ -n "$tag" ] || continue
  if ! git cat-file -e "$tag:antora.yml" 2>/dev/null; then
    echo "    skip $tag (no antora.yml -- predates the Antora layout)"
    continue
  fi
  tag_version="$(git show "$tag:antora.yml" | descriptor_version)"
  if [ "$tag_version" != "$tag" ]; then
    echo "    skip $tag (descriptor says '${tag_version:-<none>}', not stamped at tag time)"
    continue
  fi
  if [ "$tag_version" = "$head_version" ]; then
    echo "    skip $tag (same version as the worktree build)"
    continue
  fi
  tag_list+=("$tag")
done < <(git tag --list "$tag_glob" --sort=-version:refname)

echo "==> Publishing versions: ${head_version:-HEAD} ${tag_list[*]:-}"
if [ ${#tag_list[@]} -gt 0 ]; then
  tags_json="$(printf '%s\n' "${tag_list[@]}" | node -e '
    const tags = require("fs").readFileSync(0, "utf8").split("\n").filter(Boolean);
    process.stdout.write(JSON.stringify({ url: ".", tags }));
  ')"
  sources+=(--source "$tags_json")
fi
sources+=(--source '{"url": ".", "branches": "HEAD"}')

# ---------------------------------------------------------------------------
# 4. Generate the playbook and build
# ---------------------------------------------------------------------------
gen_args=(--in "$repo_root/antora-playbook.yml" --out "$generated_playbook"
          --output-dir "$output_dir")
[ -n "$site_url" ] && gen_args+=(--url "$site_url")
[ -n "$cover_logo" ] && gen_args+=(--cover-logo "$cover_logo")

echo "==> Generating $(basename "$generated_playbook")"
node "$here/gen-pages-playbook.js" "${gen_args[@]}" "${sources[@]}"

echo "==> Building site into $output_dir"
antora_bin="$repo_root/node_modules/.bin/antora"
[ -x "$antora_bin" ] || antora_bin="npx antora"
$antora_bin --fetch "$generated_playbook"

echo "==> Done: $output_dir"
