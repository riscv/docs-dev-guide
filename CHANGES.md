# Changes

## 2026-06-08 — Antora structure and documentation site guidance

### New files

- `src/antora-structure.adoc` — New section documenting the Antora-based repository layout used by RISC-V specification repositories. Covers `antora.yml`, `modules/ROOT/pages/`, `modules/ROOT/nav.adoc`, `modules/ROOT/images/`, and how to register a specification with the RISC-V documentation site by submitting a pull request to [riscv-admin/antora-dev.riscv.org](https://github.com/riscv-admin/antora-dev.riscv.org). Includes content-source entry format, chapter numbering rules configuration, branch naming conventions, and Antora installation instructions.

### Modified files

**`src/docs-dev-guide.adoc`**
- Added `include::antora-structure.adoc[]` between `authoring.adoc` and `a_few_basics.adoc`.

**`src/authoring.adoc`**
- Updated repository reference from `docs-templates` to `docs-spec-template`.
- Replaced stale `asciidoctor book_header.adoc` quick-build command with the correct entry point (`asciidoctor modules/ROOT/pages/spec-sample.adoc`) and a `make` alternative.
- Updated description of template repo to reflect Antora-based directory structure.

**`src/a_few_basics.adoc`**
- Updated two references to `book_header.adoc` (lines 91 and 334) to `modules/ROOT/pages/spec-sample.adoc` in the docs-spec-template repo.

**`src/build-infrastructure.adoc`**
- Added `=== Source directory` subsection noting that `SRC_DIR` is now `modules/ROOT/pages/` and cross-referencing the antora-structure section.
- Added `[[spec-types]]` subsection distinguishing ISA specifications (authored on a branch/fork of riscv-isa-manual) from non-ISA specifications (authored in an autonomous repository using docs-spec-template).
- Added `[[spec-lifecycle]]` section defining the four specification states (Draft, Stable, Frozen, Ratified) with `:revremark:` examples and a link to `riscv.org/spec-state`.
- Documented that state advancement is entirely manual — no automation promotes a specification between states.
- Documented the non-ISA release process using the `workflow_dispatch` GitHub Actions trigger, including the `revision_mark` input and a note on keeping it consistent with `:revremark:` in the source.
- Documented that ISA specification state is managed within the relevant chapter(s) of the riscv-isa-manual branch where the author is working.

**`src/intro.adoc`**
- Added `[[getting-help]]` subsection consolidating help resources: `sig-documentation` mailing list, `help@riscv.org`, docs-dev-guide GitHub issues, and antora-dev.riscv.org GitHub issues.

**`local_build.md`**
- Updated `## AsciiDoc book headers and styles` section to reference `modules/ROOT/pages/spec-sample.adoc` as the document entry point and `docs-resources/global-config.adoc` for shared attributes.
- Updated `## Create and name a new .adoc file` to reflect the Antora workflow: new files go in `modules/ROOT/pages/`, are included in `spec-sample.adoc` for the PDF build, and registered in `modules/ROOT/nav.adoc` for the Antora site.
- Updated `## HTML build` section to use `make` and the correct entry point (`modules/ROOT/pages/spec-sample.adoc`) in place of stale `book_header.adoc` references.
- Added `## Antora site build` section covering `make antora`, output location, and Antora installation (`npm install -g antora`).
- Added `## Run a local Kroki server for diagrams` section with the Docker run command (`docker run -d -p 9870:8000 yuzutech/kroki`), a stop command, and a note that the dev playbook is already configured for `localhost:9870`.
