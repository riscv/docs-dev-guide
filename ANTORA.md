# Antora Migration Guide

How `docs-spec-template` produces **both** the ARC-compliant submission PDF and
the Antora static-site HTML from a **single source tree**, and the phased plan
to finish that migration.

## TL;DR for authors

- Chapter content lives once, in `modules/ROOT/pages/*.adoc`, as standalone
  Antora pages (each starts with a level-0 `= Title`).
- `src/spec-sample.adoc` is a thin **PDF assembler**: it includes those pages
  with `leveloffset=+1` so their level-0 titles become chapters in the PDF,
  reproducing the historical section numbering.
- Build the PDF: `make` → `build/<short>-v<ver>-<YYYYMMDD>.pdf`.
- Build the site locally: `antora antora-playbook.yml` → `build/site/`.

## The dual-source technique (why it works)

The PDF wants one master document; Antora wants one file per navigable page.
`leveloffset=+1` reconciles them:

```
modules/ROOT/pages/intro.adoc        src/spec-sample.adoc (PDF assembler)
-----------------------------        -----------------------------------
= Introduction        (level 0)  ->  include::...intro.adoc[leveloffset=+1]
== Sub Section        (level 1)      => renders as "== Introduction" (Ch.1)
                                        and "=== Sub Section" (1.1)
```

So the pages are the single content source; the assembler is PDF-only glue.
PDF-only constructs stay in the assembler and never appear in a page:
- `include::../docs-resources/global-config.adoc[]` (cross-repo relative
  include — would break under Antora, so it lives only here)
- the back-of-book `[index] == Index` macro (Antora generates no index)
- `:title-logo-image:`, `:pdf-theme:`, `:pdf-fontsdir:`, `:doctype: book`, etc.

## Repository layout

```
antora.yml                       # component descriptor (keep MINIMAL — see below)
antora-playbook.yml              # LOCAL preview playbook (mirrors production UI)
modules/ROOT/
  nav.adoc                       # site navigation
  pages/                         # single source of chapter content (Antora pages)
    index.adoc                   #   site landing page (Antora start_page; NOT in PDF)
    intro.adoc  chapter2.adoc  contributors.adoc  bibliography.adoc
  examples/example.bib           # bibliography database
src/spec-sample.adoc             # PDF assembler (Makefile DOCS target)
Makefile                         # asciidoctor-pdf/html via Docker; ARC PDF naming
docs-resources/                  # submodule: PDF fonts/themes/logo + global-config
```

## Modes: spec vs. doc

Everything above (the PDF, the site, the dual-source technique) is common to
every repo built from this template. What's *not* common is ratification:
this template also assumes, by default, that every consumer is a
specification headed for ARC ratification, and bundles that assumption in as
a "ratification layer" — the Document State preface, the phase/milestone
attributes, `SPEC_STATE.md` tracking.

A repo that is documentation rather than a spec (e.g. `riscv/docs-dev-guide`)
needs the Antora-ready layer above but not the ratification layer. It opts
out by committing a `.docmode` file at the repo root containing `doc` (absent,
empty, or any other value ⇒ `spec`, today's behavior, byte-for-byte). Version
identity — semver git tags + build-date stamping — is identical in both modes;
only the phase/milestone surface changes:

- `scripts/release-info.sh mode` resolves `.docmode` and is the single source
  of truth every other consumer reads it from (never re-parse the file
  yourself). In `doc` mode, `phase`, `phase-floor-version`, `display`,
  `milestone`, `notice`, and `revremark` all resolve to `""` — `version` and
  the rest of the version-arithmetic commands are unaffected.
- The Makefile passes `-a doc-mode='doc'` (instead of the phase/milestone `-a`
  flags) when in doc mode, which `src/spec-sample.adoc` and
  `modules/ROOT/pages/index.adoc` key their `ifdef::doc-mode[]` /
  `ifndef::doc-mode[]` guards on to drop the Document State preface, the
  title-page revremark, and the cover-page phase banner entirely.
- `scripts/stamp-antora-version.sh` requires only `version`/`revnumber`/
  `revdate` in `antora.yml` in doc mode (not `display`/`notice`/`phase`) — see
  "Version stamping" below.
- `.github/workflows/version-bot.yml`'s `milestone-pr` job (which regenerates
  `SPEC_STATE.md`) only runs in spec mode.

See `MIGRATION.md`'s "Doc mode" section for how to adopt this in a derived
repo.

## Production model (important)

The canonical site is built **elsewhere**, by the central playbook at
`github.com/riscv-admin/antora.riscv.org` (dev mirror:
`github.com/riscv-admin/antora-dev.riscv.org`). This repo is just a **content
source** consumed by that playbook.

The central playbook supplies, uniformly to every spec:
- **Extensions**: `asciidoctor-kroki` (diagrams, incl. wavedrom),
  `@djencks/asciidoctor-mathjax` (math), an ASAM extension for
  `cite:`/`bibliography::[]`, plus section/nav numbering extensions.
- **Shared AsciiDoc attributes**: `doctype: book`, `icons: font`, `xrefstyle`,
  `source-highlighter: highlight.js`, kroki config, math entities, etc.
- **UI**: `github.com/riscv-admin/riscv-antora-only-ui` release bundle.

Consequence — **keep `antora.yml` minimal** (name/title/version/nav). Component
attributes override the playbook, so setting rendering attributes here (notably
`sectnums`, which the central section-numbering extension controls) desyncs this
spec from the rest of the library. Component *identity/grouping* keys are fine;
rendering attributes are not. Put preview-only rendering config in
`antora-playbook.yml` instead.

### Registering this spec on the dev site

Add to `content.sources:` in the dev-site `antora-playbook.yml` (push the branch
first — Antora fetches from GitHub, not the worktree):

```yaml
  # docs-spec-template example spec (dev preview) — component: spec-sample
  - url: https://github.com/riscv/docs-spec-template.git
    branches: antora-setup
    start_page: ROOT::index.adoc
    start_path: /
```

No `nav:` key needed (declared in `antora.yml`). Renders at `/spec-sample/`.

## Publishing to GitHub Pages

Separate from the central site, this repo also publishes a **standalone copy** of
the same content to its own GitHub Pages site, next to the release PDF. For a
repo seeded from this template that is not part of the RISC-V central library,
this is the primary HTML output; for specs that *are* consumed centrally,
`docs.riscv.org` stays canonical and this is a convenience.

- Workflow: `.github/workflows/publish-site.yml` — runs on `v*` tag pushes and on
  manual dispatch, and deploys via `actions/deploy-pages`.
- Build: `scripts/build-pages-site.sh` — the whole build, runnable locally.
- Setup in a seeded repo: **one manual step**, best done before the first push
  to `main` — the workflow runs on every push to `main`, not only on tags, so
  until Pages exists each push leaves a failed run behind.
  `actions/configure-pages` is configured with `enablement: true` and will turn
  Pages on by itself wherever it is allowed to, but the workflow's `GITHUB_TOKEN`
  is refused with `Resource not accessible by integration`: creating a Pages site
  is an admin-level operation that the Actions app cannot perform on a repo that
  has none, regardless of the `pages: write` grant the job holds. This is a
  limitation of the Actions token, **not** an organization policy — `riscv` has
  `members_can_create_pages: true`, so there is no org setting to change and no
  point hunting for one. A repository admin must set *Settings → Pages → Source*
  to "GitHub Actions" once. Equivalent API call, with an admin token:
  `gh api -X POST repos/<org>/<repo>/pages -f build_type=workflow`. Once the
  site exists, `enablement: true` is a no-op and releases publish unattended.
  The job skips itself on private repos, where Pages needs Team/Enterprise.
- Set that source **directly** to "GitHub Actions". If a repo is ever left on
  "Deploy from a branch" first, GitHub queues a run of its built-in
  `pages-build-deployment` workflow that survives the switch, and it can deploy
  *after* the first Actions deployment — overwriting the site with the repository
  root, which has no `index.html`. The symptom is a live 404 from a
  `publish-site.yml` run that reported success; check the `github-pages`
  deployment list for a `pages-build-deployment` entry newer than yours. Re-run
  `publish-site.yml` once the stray build has finished; it does not recur.

### How the playbook is derived

The Pages build does **not** get its own committed playbook. `antora-playbook.yml`
carries a hand-maintained mirror of the central playbook's rendering attributes,
and a second copy of that block would silently drift. Instead
`scripts/gen-pages-playbook.js` loads it and overrides four things into a
generated, gitignored `antora-pages-playbook.yml`:

| Key | Why |
| --- | --- |
| `site.url` | Project Pages sites live at `https://<org>.github.io/<repo>/`, not at a domain root; Antora needs the base path for the sitemap and canonical links. |
| `content.sources` | Which versions to publish (below). |
| `output.dir` | `build/pages-site`, so a publish never clobbers the `build/site` preview output. |
| `cover-logo` | Resolves the cover logo locally instead of from `common::`. |

### The cover logo

`index.adoc` renders the logo through the `cover-logo` attribute rather than a
literal resource ID. It defaults in `antora.yml` to `common::risc-v_logo.svg`,
the shared asset the central build uses. A single-repo build has no `common`
component, so the Pages build stages the copy from the `docs-resources` submodule
into `modules/ROOT/images/` (gitignored) and hard-sets the attribute to it. The
central build is unaffected, and the local-preview behaviour is unchanged — a
bare `npm run preview` still logs the one expected unresolved `common::` image.

`validate-content-source.yml` stages the logo the same way, for a different
reason: it publishes its render as a PR preview artifact, and `index.adoc` is the
start page, so an unresolved cover would be the first thing a reviewer sees. A
side effect is that the gate now actually *validates* the image macro, which it
could not while it was merely exception-listing the error. The exception stays,
but only covers the degraded path where the submodule is unavailable — there it
keeps a missing submodule a warning rather than a red gate.

### Versions, and why only one is published today

### Untagged builds publish as `dev`

A build with no release tag to name it — the first manual publish in a freshly
seeded repo, or any `workflow_dispatch` before the first tag — gets
`release-info.sh`'s dev version, `vX.YY-<sha>-<date>`. That string is published
under a short fixed label (`dev`, override with `DEV_VERSION_LABEL`) instead of
verbatim, for two reasons:

1. **It breaks the navigation.** The RISC-V UI floats the version selector
   beside the nav tree (`.version-box{float:right}` plus
   `.nav-version-group{overflow:hidden}`, which establishes a block formatting
   context), so the nav only gets the width left over next to the selector, and
   the selector is as wide as its longest version string. At 22 characters the
   nav collapses to about three characters per line. Release tags are short
   (`vX.Y`) and render correctly, so this never affects a real release.
2. **It churns URLs.** Every dispatch would otherwise mint a
   `/spec-sample/<sha>/` path that the next publish orphans, since each deploy
   replaces the whole site. `/spec-sample/dev/` stays linkable.

The full dev version is not lost: it is still stamped into `page-revnumber` and
shown on the cover page, so a published dev site names the exact commit it came
from.

### Version stamping

The version stamp is applied to the **working tree** at build time from
`scripts/release-info.sh` — the same source the PDF uses — so the published
version matches the PDF even though the tagged commit's committed `antora.yml`
has not been stamped yet. Nothing is committed back; getting the stamp onto
`main` stays `build-pdf.yml`'s job, which opens a review PR for it.

`scripts/stamp-antora-version.sh` asserts each key it stamps was found in
`antora.yml` exactly once — see "Modes" above. In spec mode that's all six of
`version`/`page-revnumber`/`page-revdate`/`page-phase-display`/
`page-phase-notice`/`page-phase`; in doc mode, whose `antora.yml` carries no
`page-phase*` keys, it's only the first three.

The build also scans release tags and publishes any that carry a correctly
stamped descriptor, which is what would give the site a multi-version dropdown. A
tag qualifies only if it contains an `antora.yml` whose `version:` equals the tag
itself. That is deliberately strict, for two reasons:

1. Antora **aborts the entire build** on any ref that has no `antora.yml`, so
   tags predating the Antora layout must be filtered out.
2. A tag stamped with a different version would publish under a wrong or
   duplicate version path.

**Today no tag qualifies**, so the site publishes exactly one version. The reason
is ordering: a release tag is pushed *first*, and `build-pdf.yml` stamps
`antora.yml` on `main` *afterwards* — so a tag never contains its own version.
If the release flow is ever changed to stamp and commit **before** cutting the
tag, past releases begin appearing in the version dropdown automatically, with no
change to this script.

## Section numbering

Chapter/section numbering is applied by the **central playbook**, not this repo.
The `nav_numbering` and `section_numbering` extensions read a per-component rule
from the playbook's `numbering_rules` anchor. That is *why* `antora.yml` sets no
`sectnums` (design rule under "Production model"): the central extension owns it,
and a local override would desync this spec. A generic template can't ship a rule
— chapter counts differ per spec — but the bundled example spec can.

The important subtlety: a rule's `chapters: {start, end}` are **line numbers in
`modules/ROOT/nav.adoc`**, not chapter numbers. The extension scans nav lines;
each line in `[start, end]` matching `^*+ xref:…[` becomes a chapter, numbered
sequentially from 1. For this example spec the nav xrefs currently sit at:

| `nav.adoc` line | page | numbering |
|---|---|---|
| 12 | `index.adoc` | landing/cover — not a chapter |
| 13 | `intro.adoc` | **Chapter 1** |
| 14 | `chapter2.adoc` | **Chapter 2** |
| 15 | `contributors.adoc` | unnumbered (front matter) |
| 16 | `bibliography.adoc` | unnumbered (`[bibliography]`) |

so the entry to add to `numbering_rules` in the central playbook
(`riscv-admin/antora-dev.riscv.org`, `antora/antora-playbook.yml`) is:

```yaml
- component: spec-sample
  module: ROOT
  branches: ['antora-setup']     # match the content-source branch/tag
  chapters: {start: 13, end: 14} # nav lines 13–14 = intro, chapter2
```

One entry covers both extensions (they share the `&numbering_rules` anchor).
`section_numbering` ignores `appendices`, so the bibliography stays unnumbered,
matching the PDF (where contributors is a `[preface]` and the bibliography is
unnumbered back matter).

> ⚠ **This rule is line-coupled to `nav.adoc`.** Adding, removing, or reordering
> entries — or editing the nav header comments — shifts the line numbers, so the
> central rule must be updated in lockstep or site numbering silently drifts.
> (Adding the warning comment to `nav.adoc` already moved these from lines 7–8 to
> 13–14.) Also update `branches:`/`tags:` to match wherever the spec is consumed
> (dev = `antora-setup`; later `main` or release tags).

## Phased plan

- [x] **Phase 1 — Dual-source layout.** Chapters → `modules/ROOT/pages/`;
  `src/spec-sample.adoc` → assembler with `leveloffset=+1`; `antora.yml`
  minimal; nav/start_page repointed; UI bundle fixed to the RISC-V production
  bundle. Verified: `make` → 14pp ARC PDF; `antora antora-playbook.yml` → 5
  pages + landing. (commit `19211be`)
- [x] **Phase 2 — docs-resources cross-repo include.** Verified the boundary
  holds: the `include::../docs-resources/global-config.adoc[]` appears only in
  `src/spec-sample.adoc`; zero `docs-resources` references under `modules/`.
  `global-config.adoc` defines three attributes — `company`, `url-riscv`,
  `doctype: book`. Decision: `company`/`url-riscv` are unreferenced in content,
  so they do **not** need to reach the site; `doctype: book` is already supplied
  uniformly by the central playbook, so it must **not** be duplicated in
  `antora.yml` (would override the playbook — see design rule above). Local
  `antora antora-playbook.yml` build passes (exit 0, 5 pages) with no unresolved
  includes or cross-repo artifacts in the rendered HTML.
+
  **Dev-site fixes (found on antora-dev.riscv.org after publishing):** two
  site-rendering bugs the local build could not surface (both need the central
  extensions/assets):
  * *Bibliography rendered raw.* `cite:`/`bibliography::[]` came through as
    literal text. The central ASAM bibliography extension no-ops unless the
    component declares `asamBibliography: '<bib-resource-id>'` in `antora.yml`.
    Fix: moved the bib to the canonical `modules/ROOT/resources/riscv-spec.bib`
    (was `modules/ROOT/examples/example.bib`; `examples/` is a reserved Antora
    family and no real spec puts a bib there), set
    `asamBibliography: 'ROOT:resources/riscv-spec.bib'` in `antora.yml`, and
    repointed the PDF assembler's `:bibtex-file:` to the new path. `make` PDF
    build re-verified green.
  * *No cover page.* The landing page was placeholder prose. Rebuilt
    `modules/ROOT/pages/index.adoc` on the ratified-spec cover pattern
    (`image::common::risc-v_logo.svg` + title heading + version line + phase
    banner linking to riscv.org/spec-state). The `common::` logo resolves on the
    site build; it warns in bare local preview (no `common` component) until
    Phase 5.
- [x] **Phase 3 — Attribute split.** Added an `asciidoc.attributes` block to the
  LOCAL `antora-playbook.yml`, mirroring the central playbook's shared rendering
  attributes (doctype, icons, xrefstyle, source-highlighter, toclevels, math/char
  entities, kroki config, image-path helpers) so `antora antora-playbook.yml`
  preview renders like production. Deliberately omitted: ISA-manual-specific
  content shortcuts (`csrname`, `i`/`u`/`ra`/`reg_list`), UI PDF-button plumbing
  (`pdf_url`, `multiple_pdfs`, `pdf_list`), and section-numbering keys (`sectnums`
  etc. — commented out in central because the section-numbering *extension*
  controls them, per rule #2). PDF-only attributes stay in the assembler/Makefile;
  `antora.yml` stays minimal (only `page-group` + the spec-specific
  `asamBibliography`). Local build passes (exit 0, 5 pages). The extensions these
  attributes configure (kroki, mathjax, ASAM bib) land in Phase 5, so the
  attributes are inert in bare local preview until then.
- [x] **Phase 4 — Version bridge.** The ARC Author Guide requires the artifact's
  identity to be the `vX.Y` release tag; the HTML site version must match the
  PDF version exactly. Because Antora reads a STATIC `version:` from the committed
  `antora.yml` (the central playbook just fetches the branch — no build step runs
  `release-info.sh` on the spec side), the bridge *stamps* that file, the Antora
  analogue of how `scripts/update-spec-state.sh` stamps `SPEC_STATE.md`:
  * `scripts/stamp-antora-version.sh [version] [date]` writes `version:` and the
    cover attributes (`page-revnumber`, `page-revdate`, `page-phase`,
    `page-phase-display`, `page-phase-notice`) from `release-info.sh` — the same
    source the PDF uses. Idempotent; preserves comments/nav. `make stamp-antora`
    wraps it with the Makefile's `VERSION`/`DATE`, so site and PDF cannot diverge.
  * `antora.yml` `version:` is now the exact tag (site path `/spec-sample/<ver>/`,
    a distinct citable folder per release — matching ARC's citability goal).
  * `index.adoc` cover renders the PDF title-page revision line verbatim:
    `Version {page-revnumber}, {page-revdate}: {page-phase-display}`, plus a phase
    banner mirroring the PDF "Document State" preface. No hardcoded version.
  * Verified: stamping `v0.8` yields `/spec-sample/v0.8/` with cover
    "Version v0.8, 2026-06-12: Stabilized"; restamped to the repo's real state.
  * **Release step:** automated in `build-pdf.yml` (see Phase 6) — the same run
    that builds the PDF stamps the matching version and opens a review PR against
    `main`; merging it is part of cutting a release. Manual fallback for
    local/offline releases: `make stamp-antora VERSION=vX.Y` then commit
    `antora.yml`.
  * **Hardening:** the stamp script asserts that each key was substituted exactly
    once and that the result still parses as YAML, then fails loudly. It
    previously exited 0 having silently produced invalid YAML when a formatter
    line-wrapped `page-phase-notice` into a plain multi-line scalar (caught in
    review of #105); it now also drops such wrapped continuations. `antora.yml`
    is excluded from yamlfmt (#106) so the wrap cannot return.
- [x] **Phase 5 — Extensions + preview.** Wired the central playbook's *asciidoc*
  extensions into the LOCAL preview so `antora antora-playbook.yml` renders like
  production:
  * `package.json` pins Antora + `asciidoctor-kroki` + `@djencks/asciidoctor-mathjax`
    as devDependencies (reproducible preview, not a global `antora`). **Version
    note:** `asciidoctor-kroki` must be `0.18.1` (what the central playbook uses);
    `1.0.0` needs a newer Asciidoctor.js than Antora 3.1.x bundles and dies with
    `block.$!= is not a function`.
  * `antora-playbook.yml` gained an `asciidoc.extensions` list (kroki + mathjax).
  * `docker-compose.yml` runs a local Kroki on `localhost:9870` (matching the
    `kroki-server-url` attribute), so wavedrom renders without shipping source to
    a public service. Preview flow: `npm install` → `docker compose up -d kroki`
    → `npm run preview`.
  * Added a small `latexmath` demo to `chapter2.adoc` (the example spec now
    demonstrates math like it already did wavedrom/citations).
  * Verified: wavedrom → inline `<svg>` (kroki), `latexmath` → MathJax SVG
    (`data-mml-node` markers), and `make` PDF still builds clean with the new math.
  * **Bibliography deliberately NOT mirrored locally.** The central `cite:` /
    `bibliography::[]` support is a custom, multi-file ASAM extension vendored in
    the central playbook (not on npm); replicating it here would be heavy and a
    divergence risk. Citations render on the central site (ASAM) and in the `make`
    PDF/HTML (asciidoctor-bibtex gem), so authors have two ways to check them
    without it living in this repo. Revisit only if local ASAM parity is needed.
- [x] **Phase 6 — CI (content-source validation).** This repo is ONE content
  source; the real site is built centrally from 20+ sources, so there is no site
  to build here. Added `.github/workflows/validate-content-source.yml`: on PR /
  push-to-main / dispatch it builds THIS component in isolation via
  `antora-playbook.yml` (npm ci → Kroki service on :9870 → `npx antora`), as a
  gate so broken AsciiDoc / unresolved intra-component xrefs/includes / extension
  errors fail here instead of stalling the shared central build. It does NOT
  deploy. Cross-component refs (xrefs into other specs) resolve only centrally,
  so they are exception-listed. Verified: clean tree passes; an injected broken
  xref fails the gate.
  * **PR preview artifact.** The gate's render is uploaded as *Rendered site
    (Antora)* (~4 MB, 14-day retention) instead of being discarded, so a reviewer
    can see a content change rendered rather than reading the AsciiDoc diff — the
    build was already happening on every PR, so this costs no build time. The
    cover logo is staged first (see "The cover logo") so the start page is not
    broken. Both this job and `build-pdf.yml` write a direct artifact link into
    `$GITHUB_STEP_SUMMARY` via `upload-artifact`'s `artifact-url` output; that
    needs no permissions and works on fork PRs, where the `pull_request` token is
    read-only. It is a HEAD-only preview, not a deployment: a real per-PR preview
    host was rejected because the RISC-V org refuses Pages site creation to the
    workflow token (see `publish-site.yml`) and fork PRs cannot hold deploy
    secrets. Artifact download still requires a signed-in GitHub account.
  * **Version-stamp automation (Phase 4 lockstep, now wired).** `build-pdf.yml`
    resolves `VERSION`/`DATE` once (shared by the PDF build and the stamp, so no
    date drift) and a `stamp-site-version` job stamps the matching `antora.yml`
    and opens a review PR against `main`. It runs only for real releases (skips
    PR previews and drafts) and is monotonic (never stamps `main` backwards when
    an older tag is rebuilt). Chosen over `version-bot.yml` because
    `build-pdf.yml` is the run the author actually triggers to cut a release *and*
    the run that builds the PDF, so both come from the same source/version/run by
    construction.
  * **Why a PR, not a direct push** (changed in review of #105): the original job
    ran `git push origin HEAD:main`, assuming a seeded repo's `main` is
    unprotected. That is a bad bet for a file copied into 20+ spec repos whose
    settings we do not control — and a rejected push fails *after* the Release is
    published, leaving a green release with a silently stale site. A PR works
    under any protection setting and matches the milestone-PR idiom already in
    `version-bot.yml`. Trade-off: lockstep is no longer merge-free — an unmerged
    stamp PR means the site lags, so treat it as part of the release checklist.

## Build commands

```bash
make                          # ARC PDF (+ HTML) via Docker; VERSION/DATE overridable
make stamp-antora VERSION=vX.Y   # stamp antora.yml to match the PDF release (commit the result)

# Local Antora preview (renders like production: diagrams + math):
npm install                   # one-time: Antora + kroki/mathjax extensions
docker compose up -d kroki    # local Kroki server on :9870 (for wavedrom/diagrams)
npm run preview               # antora --fetch antora-playbook.yml -> build/site/
docker compose down           # stop Kroki when done

# GitHub Pages site, exactly as CI builds it (needs Kroki up, as above).
# NOTE: this stamps antora.yml in your worktree -- pass NO_STAMP=1 to leave it be.
NO_STAMP=1 ./scripts/build-pages-site.sh            # -> build/pages-site/
./scripts/build-pages-site.sh https://org.github.io/repo   # with the real base URL
```
