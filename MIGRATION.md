# Migration Guide — ARC PDF + Antora Site

**Who this is for:** Maintainers of any RISC-V specification repository under
`github.com/riscv/*` (ISA) or `github.com/riscv-non-isa/*` (non-ISA) that was
forked from `docs-spec-template` or shares its toolchain (Makefile +
`scripts/release-info.sh` + `.github/workflows/build-pdf.yml`).

**Why this exists:** the template now produces **two** artifacts from **one**
source tree, and a spec author needs both:

1. **The ARC submission PDF.** ARC rejects submissions that do not emit a PDF
   named `<short>-v<MAJOR>.<MINOR>-<YYYYMMDD>.pdf` whose title page matches,
   using the canonical milestone IDs (`development-complete`, `stabilized`,
   `frozen`, `ratification-ready`, `ratified`).
2. **The Antora HTML site.** Chapter content is consumed as a *content source*
   by the RISC-V central playbook and published on antora.riscv.org. The ARC
   Author Guide requires the site version to match the PDF version **exactly**.
   Optionally, the same content can also be published to your own repo's GitHub
   Pages site (Step 13a) — a standalone copy, not a replacement for the central
   site.

Parts A and C below are the PDF; Part B is the site. **Do not stop after Part
A** — a repo that does gets a compliant PDF and no site.

**Related docs:** `ARC_SUBMISSION.md` is the ARC policy itself. `ANTORA.md`
explains *how* the dual build works and *why* it is designed this way — read its
"Dual-source technique" and "Production model" sections before Part B. This guide
is the sequence of actions; ANTORA.md is the rationale.

## Pre-flight

- [ ] Read `ARC_SUBMISSION.md` to understand what your repo must emit.
- [ ] Skim `ANTORA.md` §"The dual-source technique" and §"Production model".
- [ ] Confirm your repo's spec short name (e.g. `Zifoo`, `Server-Platform`,
      `RHTI`). This is the `<spec-short>` that appears in PDF filenames.
- [ ] Check the latest tag in your repo (`./scripts/release-info.sh latest`).
      Your next tag MUST be monotonically greater (decimal order: `v0.8` > `v0.79`).
      Do NOT use `git ... --sort=version:refname` — it ranks `v0.8` below `v0.61`.
- [ ] **Do NOT rewrite or delete existing tags.** The policy is
      forward-looking; old artifacts stay as-is.

> **Scope warning.** This is no longer a "sync a few files" job. Part B moves
> your chapter sources on disk. Do it on a branch, and expect to touch
> `antora.yml`, `antora-playbook.yml`, `modules/ROOT/nav.adoc`, `package.json`,
> `docker-compose.yml`, `scripts/stamp-antora-version.sh`, and
> `.github/workflows/validate-content-source.yml` in addition to the PDF files.
> Adopting the optional GitHub Pages publish (Step 13a) adds
> `.github/workflows/publish-site.yml`, `scripts/build-pages-site.sh`, and
> `scripts/gen-pages-playbook.js`.

## Doc mode (non-ratified documentation)

Skip this section unless your repo is **documentation**, not a specification
headed for ARC ratification (the worked example is `riscv/docs-dev-guide`).
Doc mode keeps everything above — the PDF target, the Makefile `%.html`
target, the Antora site, version identity from semver git tags + build-date
stamping — and strips only the ratification layer: the Document State
preface, the phase/milestone attributes, and `SPEC_STATE.md` tracking.

- [ ] Commit a `.docmode` file at your repo root containing exactly `doc`
      (no trailing content beyond the first line). Absent, empty, or any
      other value means `spec` — today's behavior, unaffected.
- [ ] Do Steps 1–2 and 7–13 below as written — they're the shared
      Antora-ready layer. `scripts/release-info.sh mode` is the single
      source of truth every one of them reads `.docmode` through; you never
      parse the file yourself.
- [ ] In Step 1, ignore the phase-ID/milestone changes — `release-info.sh`'s
      `phase`/`display`/`notice`/`revremark`/`milestone`/
      `phase-floor-version` all resolve to `""` in doc mode automatically.
- [ ] In Step 3/4's `build-pdf.yml`/`version-bot.yml`, the `target_phase`
      enum and milestone gating stay as-is (they're pure version arithmetic,
      not ratification). No doc-mode edit is needed on top of that: upstream's
      `version-bot.yml` already exports a `mode` output from `tag-version`
      (`release-info.sh mode`) and already gates the `milestone-pr` job --
      the one that regenerates `SPEC_STATE.md` -- on
      `needs.tag-version.outputs.mode == 'spec'`. Take the upstream file as
      written and the gate comes with it. Do not re-apply that edit by hand.
- [ ] Skip Step 5's Document State preface and phase-attribute defaults
      entirely — a doc-mode top-level `.adoc` needs neither; the upstream
      file already guards them behind `ifndef::doc-mode[]`.
- [ ] Skip `SPEC_STATE.md` and `scripts/update-spec-state.sh` altogether —
      there's no milestone state to track.
- [ ] In Step 12's `antora.yml`, keep only `version`, `page-revnumber`,
      `page-revdate`, and add `doc-mode: 'true'` — drop `page-phase`,
      `page-phase-display`, `page-phase-notice`. `stamp-antora-version.sh`
      requires exactly those three keys (not six) in doc mode.
- [ ] Verify the same way as Step 6, minus the phase assertions: the PDF
      still has the ARC filename shape (`<short>-v<ver>-<date>.pdf`) and a
      title page, but no "Document State" preface page and no phase label
      on the revision line; `modules/ROOT/pages/index.adoc` renders with no
      phase banner.

---

# Part A — ARC PDF compliance

## Step 1 — Sync `scripts/release-info.sh`

Replace your script with the upstream version, or apply the following changes:

- [ ] Phase IDs switched from `Developed`/`Stable`/`Frozen`/`Ratification-Ready`/`Ratified`
      to the canonical (lowercase, hyphenated) IDs
      `development-complete`/`stabilized`/`frozen`/`ratification-ready`/`ratified`.
- [ ] Versions are two-digit `vMAJOR.MINOR` as a fixed-point decimal
      (`v0.6` = 0.60, `v1.0` = 1.00). Comparison is decimal, not semver, so the
      script compares by centi-value — never `sort -V`/`git ... --sort`, which
      rank `v0.8` below `v0.61`. Use the `compare`/`max`/`latest` subcommands.
- [ ] Milestone gates are `v0.6`, `v0.8`, `v0.9`, `v0.99`, `v1.0`. `next`
      advances by `0.01` and REFUSES (exit 10) when the next step would land on
      a gate — gates are cut manually via `workflow_dispatch`.
- [ ] New helper `phase_display_for_phase` returns the title-case display
      label (e.g. `Stabilized`, `Ratification-Ready`) used on the title page.
- [ ] `revremark_for_phase` is now a thin wrapper that returns just the
      display label (e.g. `"Ratified"`), so asciidoctor-pdf renders
      `Version vX.Y, YYYY-MM-DD: <Label>` on the title page.
- [ ] `display` CLI command returns the display label (title-case), not the
      canonical ID.
- [ ] `notice_for_phase`, `phase_floor_version`, `milestone_for_phase` all
      keyed on the new canonical IDs.
- [ ] `DEFAULT_PHASE` is `draft-and-development` (was `"Draft and Development"`).

This script is the single source of version/phase truth for **both** artifacts —
the PDF build and the Antora version stamp (Step 12) both call it. Sync it first.

Smoke test:
```bash
for v in v0.5 v0.6 v0.73 v0.8 v0.9 v0.99 v1.0; do
  printf "%-10s phase=%-22s display=%s\n" "$v" \
    "$(./scripts/release-info.sh phase $v)" \
    "$(./scripts/release-info.sh display $v)"
done
```
Expected:
```
v0.5       phase=draft-and-development  display=Draft and Development
v0.6       phase=development-complete   display=Development Complete
v0.73      phase=development-complete   display=Development Complete
v0.8       phase=stabilized             display=Stabilized
v0.9       phase=frozen                 display=Frozen
v0.99      phase=ratification-ready     display=Ratification-Ready
v1.0       phase=ratified               display=Ratified
```

## Step 2 — Update `Makefile`

> ⚠ **Do not copy the upstream Makefile wholesale into a flat-layout repo.**
> The template's Makefile assumes the Part B layout: it sets `SRC_DIR := src`
> and uses `vpath %.adoc $(SRC_DIR)` to find the assembler, and its
> `stamp-antora` target calls a script that only exists once you have
> `antora.yml`. Copying it before you do Part B gives you a build that hunts
> for sources in a `src/` directory you don't have. Either apply the changes
> below by hand now and copy wholesale after Part B, or do Part B first.

- [ ] Set `SPEC_SHORT` near the top of the file. If your `DOCS` list has one
      `.adoc`, you can use:
      ```make
      SPEC_SHORT ?= $(basename $(firstword $(DOCS)))
      ```
      For repos where the spec short name differs from the .adoc basename,
      hard-code it:
      ```make
      SPEC_SHORT := Zifoo
      ```
- [ ] Add these variables:
      ```make
      DATE_STAMP := $(subst -,,$(DATE))
      VERSION_NUM := $(patsubst v%,%,$(VERSION))
      MILESTONE_ID ?= $(PHASE)
      ```
- [ ] Add `milestone_id` and `spec_short` attributes to the AsciiDoctor
      `OPTIONS` list:
      ```make
      -a milestone_id='${MILESTONE_ID}' \
      -a spec_short='${SPEC_SHORT}' \
      ```
- [ ] Have AsciiDoctor emit the ARC filename directly (`-o` resolves relative to
      `-D`). Do NOT rename the PDF after the fact: inside the container `build/`
      is created by root, so a host-side `mv` into it fails with EPERM on rootful
      Docker — and a rename that fails after a green build ships a
      non-ARC-compliant asset.
      ```make
      ARC_PDF = $(1)-v$(VERSION_NUM)-$(DATE_STAMP).pdf

      build-docs: $(DOCS_PDF) $(DOCS_HTML)

      %.pdf: %.adoc
      	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_PDF) $(OPTIONS) $(REQUIRES) -o $(call ARC_PDF,$*) $< $(DOCKER_QUOTE)
      	@test -f build/$(call ARC_PDF,$*) || { echo "ERROR: build/$(call ARC_PDF,$*) was not produced" >&2; exit 1; }
      	@echo "ARC submission PDF: build/$(call ARC_PDF,$*)"
      ```

Smoke test (no Docker required):
```bash
make -n SKIP_DOCKER=true VERSION=v0.8 DATE=2026-06-12 | grep -E "(asciidoctor|ARC)"
```
Should show `-o spec-sample-v0.8-20260612.pdf` on the `asciidoctor-pdf` line.

## Step 3 — Update `.github/workflows/build-pdf.yml`

- [ ] Replace `target_phase` enum values with the canonical IDs (no
      `publication` — it is a phase, not a milestone version):
      ```yaml
      options:
        - auto-next
        - draft-and-development
        - development-complete
        - stabilized
        - frozen
        - ratification-ready
        - ratified
      ```
- [ ] Classify official releases via `release-info.sh is-milestone` (the single
      source of truth for the gates `v0.6`, `v0.8`, `v0.9`, `v0.99`, `v1.0`)
      rather than a hard-coded version list:
      ```yaml
      if ./scripts/release-info.sh is-milestone "${VERSION}"; then
        echo "OFFICIAL_RELEASE=true" >> "$GITHUB_ENV"
      else
        echo "OFFICIAL_RELEASE=false" >> "$GITHUB_ENV"
      fi
      ```
- [ ] Export `VERSION` and `DATE` in the build step so the Makefile picks
      them up:
      ```yaml
      - name: Build Files
        run: |
          set -euo pipefail
          export VERSION="${VERSION}"
          export DATE="$(date +%Y-%m-%d)"
          echo "Building ${VERSION} (${DATE})"
          make
      ```
- [ ] **No change needed** to the release globs — `files: build/*.pdf` picks up
      the ARC-named PDF automatically. Release assets stay PDF-only: the ARC
      submission artifact is the PDF, and the published HTML is the Antora site.
- [ ] **Widen the artifact upload** to keep the HTML the build already produces:
      ```yaml
      - name: Upload Build Artifacts
        uses: actions/upload-artifact@v6
        with:
          name: Build Artifacts
          path: |
            ${{ github.workspace }}/build/*.pdf
            ${{ github.workspace }}/build/*.html
          retention-days: 30
      ```
      `make` renders both formats on every run (`build-docs` depends on
      `$(DOCS_HTML)`), so this costs no build time and gives reviewers the
      rendered document on each PR. `:data-uri:` inlines images and the
      stylesheet, so the `.html` is self-contained and needs no sidecar files.
- [ ] This workflow also carries the site version stamp once you do Part B —
      see Step 12. Sync the whole upstream file if you can; it resolves
      `VERSION`/`DATE` once and shares them between the PDF build and the stamp
      so the two cannot drift apart by a date boundary.

## Step 4 — Update `.github/workflows/version-bot.yml` (if present)

- [ ] Replace `target_phase` enum values with the canonical IDs (same list
      as Step 3).
- [ ] No other changes required — the bot calls `release-info.sh` which
      already emits the new labels.

## Step 5 — Update your top-level spec `.adoc`

This is the file listed in the Makefile's `DOCS`. In a flat-layout repo it sits
at the repo root; after Part B it is the **PDF assembler** at
`src/<spec-short>.adoc` (in this template, `src/spec-sample.adoc`). The edits
are the same either way — only the path changes.

- [ ] Update the `ifndef::phase[]` default to `draft-and-development`:
      ```adoc
      ifndef::phase[:phase: draft-and-development]
      ```
- [ ] Add defaults for the new attributes:
      ```adoc
      ifndef::milestone_id[:milestone_id: {phase}]
      ifndef::spec_short[:spec_short: <your-spec-short>]
      ```
- [ ] Switch the TOC to a macro placement so we can position it manually
      (so the Document State preface lands on page 2, TOC on page 3):
      ```adoc
      :toc: macro
      :toclevels: 4
      :toc-title: Table of Contents
      ```
      (Replaces `:toc: left` or `:toc: auto`.)
- [ ] Add a `Document State` preface as the FIRST preface, immediately
      followed by the explicit `toc::[]` placement. Remove any previous
      `WARNING`/`NOTE` admonition that surfaced the phase notice — its job
      is now done by this block:
      ```adoc
      [preface]
      == Document State
      *Note:* {phase_notice}

      toc::[]

      [preface]
      == List of figures
      list-of::image[hide_empty_section=true, enhanced_rendering=true]

      ...   // other prefaces follow as before
      ```
- [ ] **Do not** add a `WARNING` admonition for the phase notice anywhere
      else. The title-page revision line shows the milestone label
      automatically (via the new `revremark`); the `Document State` preface
      shows the full notice. Anything more is duplication.

## Step 6 — Verify the PDF

```bash
make VERSION=v0.8 DATE=2026-06-12
ls build/
```
You should see exactly one PDF named `<short>-v0.8-20260612.pdf`. Open it
and confirm:

- [ ] **Filename** contains short name, `v0.8`, and `20260612`.
- [ ] **Page 1 (title page)** ends with the line:
      `Version v0.8, 2026-06-12: Stabilized`.
- [ ] **Page 2** is a preface titled `Document State` whose only content is
      a `Note:` paragraph with the phase notice.
- [ ] **Page 3** is the Table of Contents (and includes `Document State`
      as its first entry).
- [ ] Page 4+ are the list-of-X prefaces and body content.

---

# Part B — Antora site

Your chapter content becomes the single source for both artifacts. Read
`ANTORA.md` §"The dual-source technique" first if you haven't — the short version
is that chapters live once as standalone Antora pages with a level-0 `= Title`,
and the PDF assembler includes them with `leveloffset=+1` so those titles become
PDF chapters.

## Step 7 — Adopt the dual-source layout

Target layout (see `ANTORA.md` §"Repository layout"):

```
antora.yml                       # component descriptor (keep MINIMAL)
antora-playbook.yml              # LOCAL preview playbook only
modules/ROOT/
  nav.adoc                       # site navigation
  pages/                         # single source of chapter content
    index.adoc                   #   site landing/cover (NOT in the PDF)
    intro.adoc  chapter2.adoc  contributors.adoc  bibliography.adoc
  resources/<spec>.bib           # bibliography database
src/<spec-short>.adoc            # PDF assembler (Makefile DOCS target)
```

- [ ] Move each chapter `.adoc` to `modules/ROOT/pages/`. Each must start with
      a level-0 `= Title` and must be valid standalone (no reliance on
      attributes defined by the old master document).
- [ ] Move your master `.adoc` to `src/` and reduce it to an assembler: the
      document header, the prefaces, and `include::../modules/ROOT/pages/<page>.adoc[leveloffset=+1]`
      lines. Keep the Step 5 edits.
- [ ] Keep **PDF-only constructs in the assembler only** — never in a page:
      the `include::../docs-resources/global-config.adoc[]` cross-repo relative
      include (it breaks under Antora), the back-of-book `[index] == Index`
      macro, and `:title-logo-image:` / `:pdf-theme:` / `:pdf-fontsdir:` /
      `:doctype: book`.
- [ ] Add `SRC_DIR := src` and `vpath %.adoc $(SRC_DIR)` to the Makefile, and
      point `DOCS` at the assembler's basename.
- [ ] Create `modules/ROOT/pages/index.adoc` as the site landing/cover page. It
      is the Antora `start_page` and does **not** appear in the PDF. Build it on
      the ratified-spec cover pattern: logo, title, the version line
      `Version {page-revnumber}, {page-revdate}: {page-phase-display}`, and a
      phase banner linking to riscv.org/spec-state. Never hardcode a version —
      those attributes are stamped in Step 12.
- [ ] Confirm the boundary holds:
      ```bash
      grep -rn "docs-resources" modules/ && echo "LEAK: docs-resources referenced under modules/"
      ```
      This should print nothing.

## Step 8 — Add `antora.yml`

Copy the template's and edit `name`/`title`. **Keep it minimal.** The central
playbook supplies shared attributes and extensions uniformly to every spec;
anything you set here *overrides* the playbook and desyncs your spec from the
rest of the library — notably `sectnums`, which the central section-numbering
extension owns.

- [ ] `name`, `title` — yours.
- [ ] `version: v0.0` — placeholder; stamped at release (Step 12). Do not
      hand-edit thereafter.
- [ ] `nav:` → `- modules/ROOT/nav.adoc`.
- [ ] `asciidoc.attributes.asamBibliography: 'ROOT:resources/<spec>.bib'` if you
      use `cite:`/`bibliography::[]`. Without it the central ASAM extension
      no-ops and citations render as raw text. Note this is a *second*,
      independent pointer to the same bib — the assembler's `:bibtex-file:`
      serves the PDF. Both are required.
- [ ] Do **not** add rendering attributes (`sectnums`, `doctype`, `icons`,
      `xrefstyle`, `source-highlighter`, …). Preview-only rendering config goes
      in `antora-playbook.yml`.

## Step 9 — Add `modules/ROOT/nav.adoc`

- [ ] One `xref:` entry per page, in reading order, landing page first.
- [ ] Keep the header comment warning about line-number coupling (Step 11).

## Step 10 — Add local preview tooling

- [ ] `antora-playbook.yml` — the **local preview** playbook. It mirrors
      production's extensions and attributes so what you see locally matches the
      site. It is not what builds the real site.
- [ ] `package.json` — pins the preview toolchain as devDependencies rather than
      relying on a global `antora`. **Version constraint:** `asciidoctor-kroki`
      must be `0.18.1` (what the central playbook uses); `1.0.0` requires a newer
      Asciidoctor.js than Antora 3.1.x bundles and dies with
      `block.$!= is not a function`.
- [ ] `docker-compose.yml` — a local Kroki on `localhost:9870` (the port must
      match the playbook's `kroki-server-url`), so diagrams render without
      shipping source to a public Kroki instance.
- [ ] Verify the preview:
      ```bash
      npm install
      docker compose up -d kroki
      npm run preview            # antora --fetch antora-playbook.yml -> build/site/
      docker compose down
      ```
      Expect exit 0. A warning about an unresolved `common::` image is expected
      in bare local preview — that asset only resolves in the central build.

## Step 11 — Register with the central playbook

The canonical site is built **elsewhere**, by `riscv-admin/antora.riscv.org`
(dev mirror: `riscv-admin/antora-dev.riscv.org`). Your repo is a content source.
Nothing you do locally publishes anything.

- [ ] Push your branch first — Antora fetches from GitHub, not your worktree.
- [ ] Add your repo to `content.sources:` in the site playbook:
      ```yaml
        - url: https://github.com/riscv/<your-repo>.git
          branches: <your-branch>       # later: main, or release tags
          start_page: ROOT::index.adoc
          start_path: /
      ```
      No `nav:` key needed — `antora.yml` declares it.
- [ ] Add a `numbering_rules` entry, or your spec renders with wrong or missing
      chapter numbers. **The `chapters: {start, end}` values are line numbers in
      your `nav.adoc`, not chapter numbers** — the extension scans nav lines and
      each line in the range matching `^*+ xref:…[` becomes a chapter, numbered
      from 1:
      ```yaml
      - component: <your-component>
        module: ROOT
        branches: ['<your-branch>']
        chapters: {start: <first-chapter-line>, end: <last-chapter-line>}
      ```
      Exclude the landing page and any unnumbered front/back matter
      (contributors, bibliography) from the range.
- [ ] ⚠ **This rule is line-coupled.** Adding, removing, or reordering nav
      entries — or editing the nav header comments — shifts the line numbers and
      silently drifts site numbering. Update the central rule in lockstep, and
      update `branches:`/`tags:` whenever you change where the spec is consumed
      from. See `ANTORA.md` §"Section numbering".

## Step 12 — Add the version bridge

The site version must equal the PDF version exactly. Antora reads a **static**
`version:` from the committed `antora.yml` — the central playbook just fetches
your branch and never runs `release-info.sh` — so a release has to stamp that
file.

- [ ] Add `scripts/stamp-antora-version.sh` and the Makefile target:
      ```make
      stamp-antora:
      	./scripts/stamp-antora-version.sh "$(VERSION)" "$(DATE)"
      ```
      It writes `version:` plus the cover attributes (`page-revnumber`,
      `page-revdate`, `page-phase`, `page-phase-display`, `page-phase-notice`)
      from `release-info.sh` — the same source the PDF uses, so the two cannot
      diverge. It is idempotent and preserves comments and nav.
- [ ] Sync the upstream `build-pdf.yml` `stamp-site-version` job. On every real
      release (it skips PR previews and drafts) it stamps `antora.yml` and opens
      a **review PR** against `main` titled
      `Stamp Antora site version vX.Y to match released PDF`. It is monotonic —
      it will not stamp `main` backwards when an older tag is rebuilt (it
      compares by decimal value via `release-info.sh`, not `sort -V`).
- [ ] **Merging that PR is part of cutting a release** (Step 14). Until it
      merges, the site version lags the released PDF. It deliberately opens a PR
      rather than pushing to `main` directly so it works whatever branch
      protection your repo has — a rejected push would leave the release green
      and the site silently stale.
- [ ] Verify:
      ```bash
      make stamp-antora VERSION=v0.8 DATE=2026-06-12
      git diff antora.yml     # version: v0.8, page-phase-display: 'Stabilized'
      ```
      Then restamp to your repo's real state before committing.

## Step 13 — Add the CI content-source gate

- [ ] Add `.github/workflows/validate-content-source.yml`. It builds **your
      component in isolation** via `antora-playbook.yml` on PRs, so broken
      AsciiDoc, unresolved intra-component xrefs/includes, and extension errors
      fail in your repo instead of stalling the shared central library build. It
      does **not** build or deploy the real site.
- [ ] Exception-list cross-component references (xrefs into other specs). These
      resolve only in the central multi-source build and are *expected* to be
      unresolved here.
- [ ] Keep the gate's render as a PR preview artifact — the site is built on
      every PR either way, so retaining it costs no build time and lets
      reviewers see a content change rendered:
      ```yaml
      - name: Upload rendered site
        id: upload
        uses: actions/upload-artifact@v6
        with:
          name: Rendered site (Antora)
          path: build/site
          retention-days: 14
      ```
      Check out with `submodules: recursive` and stage the cover logo before the
      build (copy `docs-resources/images/risc-v_logo.svg` into
      `modules/ROOT/images/`, then pass
      `--attribute cover-logo=risc-v_logo.svg`). Without it `index.adoc` — the
      start page, and the first thing a reviewer opens — renders a broken image.
- [ ] Write the artifact link into `$GITHUB_STEP_SUMMARY` here and in
      `build-pdf.yml`, using `upload-artifact`'s `artifact-url` output, so the
      output is one click from the Checks tab. Do **not** post it as a PR
      comment from these workflows: the `pull_request` token is read-only on
      fork PRs, so that needs a separate `workflow_run`-triggered workflow.

## Step 13a — Publish to your own GitHub Pages site (optional)

Steps 1–13 give you the ARC PDF and a component the central playbook can
consume. This step additionally publishes a **standalone copy** of the same
content to your repo's own GitHub Pages site on every release. It does not
replace antora.riscv.org, which stays canonical for RISC-V specs — but it is the
primary HTML output for a spec that is not part of the central library, and a
useful full-fidelity preview for one that is. Skip this step freely; nothing
else depends on it.

- [ ] Copy `.github/workflows/publish-site.yml`, `scripts/build-pages-site.sh`,
      and `scripts/gen-pages-playbook.js`. The workflow runs on `v*` tags and on
      `workflow_dispatch`; the build lives in the script so it is reproducible
      locally.
- [ ] Render the cover logo through an attribute, so the page works in both
      builds. In `antora.yml`:
      ```yaml
          cover-logo: common::risc-v_logo.svg
      ```
      and in `modules/ROOT/pages/index.adoc` use `image::{cover-logo}[...]`
      instead of a literal `common::risc-v_logo.svg`. The central build keeps
      using the shared asset; the Pages build overrides the attribute with a
      copy vendored from the `docs-resources` submodule, because a single-repo
      build has no `common` component.
- [ ] Add the generated artifacts to `.gitignore`:
      ```gitignore
      /antora-pages-playbook.yml
      /modules/ROOT/images/risc-v_logo.svg
      ```
- [ ] **Have a repository admin enable Pages once**: *Settings → Pages → Build
      and deployment → Source: GitHub Actions*, before the first push to `main`
      — the workflow runs on every push to `main`, not only on tags. The workflow
      asks for this automatically (`enablement: true`), but the built-in
      `GITHUB_TOKEN` is refused with `Resource not accessible by integration`:
      that is a limitation of the Actions token, **not** an organization policy,
      so there is no org-level setting to change. Equivalent API call, with an
      admin token:
      ```bash
      gh api -X POST repos/<org>/<repo>/pages -f build_type=workflow
      ```
      Set the source *directly* to "GitHub Actions". If it is set to "Deploy from
      a branch" first, GitHub queues a build of its built-in
      `pages-build-deployment` workflow that can land after your first Actions
      deployment and overwrite the site with the repo root — a live 404 from a
      run that reported success. Re-run `publish-site.yml` to recover.
      Pages also needs a public repo unless your org is on Team/Enterprise; the
      job skips itself on private repos rather than failing your release.
- [ ] Verify locally before pushing (needs Kroki, as in Step 10):
      ```bash
      NO_STAMP=1 ./scripts/build-pages-site.sh   # -> build/pages-site/
      ```
- [ ] Verify in CI: run the workflow manually and confirm the site appears at
      `https://<org>.github.io/<repo>/`. A repo with no release tags yet
      publishes under `/<component>/dev/` rather than a
      `v<latest>-<hash>-<date>` path — that is deliberate, and the exact commit
      is still shown on the cover page.

> **One version, not a dropdown.** The build publishes the checked-out ref, plus
> any release tag whose `antora.yml` names that same tag. Under the standard
> release flow the tag is cut *before* the stamp PR from Step 12 merges, so no
> tag carries its own version and exactly one version is published. Tags that
> predate your Antora migration are skipped with a reason rather than aborting
> the build — Antora fails hard on any ref lacking `antora.yml`.

---

# Part C — Release and submit

## Step 14 — Cut your next release

When you're ready to advance to the next milestone:

- [ ] Open the `Create Specification Document` workflow → `Run workflow`.
- [ ] Pick the target milestone from `target_phase` (or leave on `auto-next`
      for an intermediate revision tag).
- [ ] Confirm the resulting release has a single PDF whose name matches the
      ARC convention.
- [ ] **Review and merge the site version stamp PR** the release opened
      (`Stamp Antora site version vX.Y to match released PDF`). The site
      version does not track the PDF until you do. The values are generated from
      `release-info.sh`, so this wants a merge, not an edit.
- [ ] After it merges, confirm the site renders at `/<component>/<version>/` with
      a cover reading `Version vX.Y, YYYY-MM-DD: <Display>` — identical to the
      PDF title page.
- [ ] **Releasing locally or offline?** The CI stamp doesn't run, so do it by
      hand or the site version silently lags the PDF:
      ```bash
      make stamp-antora VERSION=vX.Y
      git add antora.yml && git commit -m "Stamp site version vX.Y"
      ```
- [ ] If you adopted Step 13a, confirm your own Pages site published at
      `https://<org>.github.io/<repo>/<component>/vX.Y/`. It is stamped
      independently of the Step 12 PR, so it is correct as soon as the tag
      build finishes — it does not wait for that PR to merge.
- [ ] If you changed `nav.adoc` this cycle, re-check the central
      `numbering_rules` entry (Step 11) — including its `branches:`/`tags:`.
- [ ] Use the **GitHub Release URL** (not a branch or commit URL) in the ARC
      review request.

## Step 15 — Confirm with ARC (one-time)

- [ ] Reply on the ARC mailing list / Jira ticket that your repo is compliant
      with `ARC_SUBMISSION.md`, citing the URL of your first ARC-conformant
      release.

## Common gotchas

### PDF

- **Existing pre-`v0.6` tags:** the script labels them `draft-and-development`,
  which is fine. No action needed. **Old 3-digit tags** (`v0.8.0`) are not valid
  in the 2-digit scheme and are ignored by `release-info.sh latest`; do not
  delete them, just cut new 2-digit tags going forward.
- **Repos that don't use this template's Makefile:** you still need to emit a
  PDF named per §3.2 of `ARC_SUBMISSION.md` and a title page per §3.3.
  Adopting the template Makefile is the easiest way; otherwise replicate the
  naming logic in whatever build system you use.
- **Multi-document repos:** the `%.pdf` rule fires once per PDF in
  `$(DOCS_PDF)`, so each is named from its own basename + version + date.
  If two docs in one repo need to be ARC-submitted independently, the
  `SPEC_SHORT` heuristic uses the .adoc basename — verify that's the short
  name ARC expects.
- **GitHub Actions caching:** if you cache `build/` between runs, clear the
  cache once so a stale PDF from an earlier version doesn't ghost the current
  output — the release step globs `build/*.pdf` and would attach both (the
  artifact upload globs `*.html` too, with the same exposure).
- **Don't rewrite tags.** Push a new monotonically-greater tag if you need to
  reissue.
- **`:toc: macro` requires explicit placement.** If you switch from
  `:toc: left` to `:toc: macro` and forget the `toc::[]` line, the PDF will
  build without a Table of Contents. Always pair the attribute change with
  the macro placement in Step 5.
- **No theme/submodule edits required.** The PDF layout is achieved entirely
  through the assembler `.adoc`, the Makefile, and `release-info.sh`. Do not
  modify `docs-resources/themes/riscv-pdf.yml`.
- **Pre-existing in-body phase admonitions** (e.g. a `WARNING` block keyed
  on `{phase_display}`) MUST be removed when you add the `Document State`
  preface, or the phase notice will appear twice.

### Site

- **Don't copy the upstream Makefile into a flat-layout repo.** See the warning
  in Step 2.
- **Attributes in `antora.yml` override the central playbook.** This is the most
  common way to desync a spec from the library. `sectnums` is the classic
  offender. Preview-only config belongs in `antora-playbook.yml`.
- **`asciidoctor-kroki` must be `0.18.1`.** `1.0.0` throws
  `block.$!= is not a function` under Antora 3.1.x.
- **`modules/ROOT/examples/` is a reserved Antora family** — don't put your bib
  there. Use `modules/ROOT/resources/`.
- **The numbering rule is coupled to `nav.adoc` line numbers**, not chapter
  numbers, and lives in a *different repo*. Editing nav comments is enough to
  break it. See Step 11.
- **Local preview can't surface every bug.** Cross-component references, the
  ASAM bibliography extension, and central section numbering only resolve in the
  central build. Publish to the dev site (`antora-dev.riscv.org`) to check those.
- **Two independent bib pointers.** `:bibtex-file:` (assembler → PDF) and
  `asamBibliography` (antora.yml → site) both point at the same file and both
  must be set. Changing the bib path means changing both.
- **Never hand-edit `antora.yml`'s `version:` or `page-*` attributes.** They are
  stamped. Hand edits get overwritten and, worse, can ship a site version that
  disagrees with the PDF.

## Questions / help

`help@riscv.org` for ARC policy questions. Open an issue against
`riscv/docs-spec-template` for tooling/migration issues.
