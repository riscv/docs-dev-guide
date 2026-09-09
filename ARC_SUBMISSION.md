# ARC Submission Requirements for ISA and non-ISA Specifications

**Audience:** Maintainers, editors, and chairs of any specification repository
under `github.com/riscv/*` (ISA) and `github.com/riscv-non-isa/*` (non-ISA)
that submits work to the Architecture Review Committee (ARC) for review.

**Effective:** Immediately. ARC will **reject submissions that do not meet
these requirements**.

---

## 0. Notice from ARC (verbatim)

> ARC has been having issues with submitted specifications not being in the
> form of a clearly versioned file that has been released in github with a
> unique and monotonic version tag. Future review requests of specifications
> will be rejected unless the specifications are of the following form:
>
> * Link to a tag on github, which contains the compiled pdf.
>
> * The compiled pdf file name has to contain a version string matching the
>   tag and also a date stamp (e.g, `Zifoo-v0.8-20260520.pdf`).
>
> * The title page of the document must match the above information.

The rest of this document operationalizes that notice — specifying the
exact tag/filename/title-page conventions, the version→milestone mapping
that goes on the title page, and how the `docs-spec-template` toolchain
produces compliant artifacts automatically.

---

## 1. Why this exists

ARC has been receiving spec submissions in inconsistent forms — uncompiled
sources, draft PDFs without identifiers, or files whose name/title/version do
not match. This makes review unreproducible: ARC cannot be sure two reviewers
are looking at the same artifact, and the reviewed artifact cannot be cited
later. The rules below make every reviewable artifact uniquely identifiable.

## 2. What ARC requires

Every specification submitted to ARC for review MUST be presented as:

1. **A link to a Git tag on GitHub** in the spec's canonical repository
   (`riscv/<repo>` or `riscv-non-isa/<repo>`). The tag MUST point at the exact
   commit the PDF was built from.

2. **The compiled PDF MUST be published with the tag** — either as an asset on
   a GitHub Release attached to that tag, or committed at the tagged commit.
   A bare tag with no PDF is not a valid submission.

3. **The PDF filename MUST contain**:
   - the spec short name,
   - the version string matching the tag, and
   - a date stamp in `YYYYMMDD` form.

   Pattern: `<spec-short-name>-v<MAJOR>.<MINOR>-<YYYYMMDD>.pdf`

4. **The PDF title page MUST display the same information** — spec name,
   version string, milestone ID, and date — and they MUST match the filename
   and the tag.

## 3. Conventions

### 3.1 Version → Milestone mapping

Tags use **`vMAJOR.MINOR`** form, where the version is a fixed-point decimal to
hundredths: `v0.6` = 0.60, `v0.72` = 0.72, `v1.0` = 1.00. Ordering is therefore
**decimal, not semver** — `v0.8` (0.80) is greater than `v0.61`. The milestone
gates are the reserved values below; between them, merges to `main`
auto-advance the revision by `0.01` (`v0.61`, `v0.62`, …). The milestone ID is
the single canonical label that identifies what state the document is in.

| Milestone ID            | Tag at milestone gate | Revisions within phase     |
| ----------------------- | --------------------- | -------------------------- |
| `development-complete`  | `v0.6`                | `v0.61`, `v0.62`, … `v0.79` |
| `stabilized`            | `v0.8`                | `v0.81`, `v0.82`, … `v0.89` |
| `frozen`                | `v0.9`                | `v0.91`, `v0.92`, … `v0.98` |
| `ratification-ready`    | `v0.99`               | (no revisions; single tag) |
| `ratified`              | `v1.0`                | (no revisions; ratified)   |

Milestone gates are cut **manually** by a maintainer; the `v0.NN` revisions
between them are created automatically on merge to `main`. `v0.0` is the
inception version.

**Tags MUST be monotonically increasing** (by decimal value). Never delete or
rewrite a published tag — create a new one.

A revision tag carries the milestone label of the **most recent gate
passed**. Example: `v0.83` is still labeled `stabilized` until the spec is
re-tagged at `v0.9` (`frozen`).

### 3.2 PDF filename

```
<spec-short-name>-v<MAJOR>.<MINOR>-<YYYYMMDD>.pdf
```

Worked examples — one per milestone:

| Filename                                | Milestone            |
| --------------------------------------- | -------------------- |
| `Zifoo-v0.6-20260520.pdf`               | development-complete |
| `Zifoo-v0.8-20260612.pdf`               | stabilized           |
| `RHTI-v0.9-20260408.pdf`                | frozen               |
| `Server-Platform-v0.99-20260415.pdf`    | ratification-ready   |
| `Zifoo-v1.0-20260901.pdf`               | ratified             |

Use the **short name** registered for the spec, not the long title. Use
hyphens, not spaces.

### 3.3 Title page

The first page of the PDF MUST show, prominently:

- Spec long title and short name
- Version string matching the tag and filename (e.g. `v0.8`)
- Date in human-readable form matching the `YYYYMMDD` in the filename
- **Milestone label**, the title-case display form of one of the canonical
  milestone IDs:

  | Canonical ID (filenames, scripts) | Display label (title page) |
  | --------------------------------- | -------------------------- |
  | `draft-and-development`           | Draft and Development      |
  | `development-complete`            | Development Complete       |
  | `stabilized`                      | Stabilized                 |
  | `frozen`                          | Frozen                     |
  | `ratification-ready`              | Ratification-Ready         |
  | `ratified`                        | Ratified                   |

The canonical ID is what scripts, filenames, and CI consumers reference.
The display label is what humans see on the title page.

Repos derived from `docs-spec-template` get this layout automatically:

- **Page 1 (title page):** title, authors, and a single revision line of the
  form `Version vX.Y, YYYY-MM-DD: <Milestone display label>` — for
  example `Version v1.0, 2026-05-24: Ratified`. This is asciidoctor-pdf's
  default rendering of `revnumber, revdate: revremark`, with `revremark`
  set to the title-case display label.

- **Page 2 (Document State preface):** a single `Note:` paragraph
  containing the phase notice — e.g.,
  > **Note:** This document is ratified. No changes are allowed; use a
  > follow-on extension for updates.

- **Page 3 onward:** TOC, list-of prefaces, and body content.

The `Document State` preface is created in the spec source with:

```adoc
[preface]
== Document State
*Note:* {phase_notice}

toc::[]
```

`{phase_notice}` is set automatically by the Makefile via
`scripts/release-info.sh notice <version>`.

## 4. How to comply

### 4.1 Release flow (recommended)

1. Freeze the source at the commit you intend to submit.
2. Run the `Create Specification Document` GitHub Action with
   `target_phase` set to the milestone you're cutting (e.g. `stabilized`)
   — OR push a tag of the form `v0.8`.
3. The workflow builds the PDF with `VERSION` and `DATE` plumbed through
   the Makefile, produces `build/<short>-v<MAJOR>.<MINOR>-<YYYYMMDD>.pdf`, creates
   a GitHub Release, and attaches the PDF.
4. Verify the title page shows the version, milestone ID, and date.
5. Use the **GitHub Release URL** when scheduling the ARC slot.

### 4.2 Building locally

```bash
make VERSION=v0.8 DATE=2026-06-12
ls build/
# → <short>-v0.8-20260612.pdf
```

The Makefile passes the ARC-compliant filename to AsciiDoctor's `-o` on every
build — there is no separate "ARC build" target, and no post-build rename that
could fail and leave a non-compliant PDF behind; every PDF this repo emits is
ARC-compliant by construction.

### 4.3 Multi-document repos

If your repo builds more than one specification, list each in `DOCS` and
the `%.pdf` rule names each PDF from its own basename. If two docs in one
repo are submitted to ARC independently, ensure their basenames are the
ARC short names.

## 5. Pre-submission checklist

Before requesting an ARC review slot, confirm:

- [ ] Tag `v<MAJOR>.<MINOR>` is pushed to the canonical repo
- [ ] Tag is on a commit that builds reproducibly
- [ ] PDF is published (release asset preferred) with filename
      `<short>-v<MAJOR>.<MINOR>-<YYYYMMDD>.pdf`
- [ ] PDF title page shows the same short name, version, milestone ID, and
      date
- [ ] The version and date in filename, tag, title page, and milestone ID
      are mutually consistent (no `v0.85` filename with a `frozen`
      milestone, etc.)
- [ ] Tag version is monotonically greater than the previous tag (decimal
      order: `v0.8` > `v0.79`)

ARC reviewers reference the **tag link** (or release URL), not a draft or
branch. Submissions that don't satisfy the checklist will be rejected and
rescheduled.

## 6. Migration

If your repo was forked from `docs-spec-template` before this policy was
introduced, see `MIGRATION.md` in this template repo for a step-by-step
checklist to bring the toolchain in line.

## 7. Where to ask for help

- Policy questions: `help@riscv.org`
- Tooling / build issues: open an issue against `riscv/docs-spec-template`
