# Upgrading a Spec Repository to a Newer Template Version

## Can I upgrade a repository I created from this template?

Short answer: yes. A repository created from `docs-spec-template` can be upgraded
to a later version of the template, and can keep being upgraded indefinitely. It
is not a one-shot copy. But it is not `git pull` either — the mechanism has to be
set up deliberately, because GitHub's "Use this template" severs the link.

**Who this is for:** Maintainers of a specification repository that was created
from `docs-spec-template` (via *Use this template* or a fork) and wants to pick
up later toolchain improvements — new workflows, fixed build scripts, ARC
compliance changes — without losing their specification content.

> **Before you start:** this guide assumes your repository already has
> `scripts/release-info.sh`, `modules/ROOT/`, and the current workflows. If it
> does not, you have not adopted the Antora dual build yet. Work through
> [`MIGRATION.md`](MIGRATION.md) first, then come back here.

The procedure is in sections 1–3. If you want to know *why* it works this way, or
which files belong to whom, see the [Reference](#reference) at the end.

---

## 1. Before you begin

Before you upgrade, add the spec template repository as a remote and record which
template version your repository is currently on. Do these steps once, on a
branch, and every subsequent upgrade becomes a routine operation.

### 1.1 Add the template as a remote

```shell
git remote add template https://github.com/riscv/docs-spec-template.git
git fetch template
```

The remote is named `template` rather than the more usual `upstream` because if
your repository is also a fork of something else, `upstream` will already be
taken.

### 1.2 Find your baseline

You need to know which template release your repository currently matches. If you
know which release you started from, use that and skip to 1.3.

If you do not know, find the closest match by comparing the template-owned files
against each candidate release:

```shell
for ref in v4.0.0 v4.0.1 v4.0.2 v4.0.3 v4.0.4 template/main; do
  n=$(git diff --name-only "$ref" -- scripts .github/workflows 2>/dev/null | wc -l)
  printf '%-20s %s differing files\n' "$ref" "$n"
done
```

For example, this output:

```
v4.0.0                      3 differing files
v4.0.1                      7 differing files
v4.0.2                      9 differing files
v4.0.3                     11 differing files
v4.0.4                     11 differing files
template/main              12 differing files
```

The fewest differences are against `v4.0.0`, so that is your baseline. If several
releases tie, choose the most recent one.

### 1.3 Record your baseline

Now record it by creating a `.template-version` file in your repository. This file
makes future upgrades much easier: it is the only place that records which
template version your tooling came from.

> **Note:** you are creating this file yourself — the template does not ship it,
> and nothing reads it automatically. It is a record for your future self and for
> the template maintainers. The convention is proposed in the pull request that
> added this guide, and only pays off if the template adopts it.

First get the full commit SHA of the baseline you picked in 1.2. Substitute your
own baseline here — the sample output above happened to favour `v4.0.0`, but
yours may be any of the releases, or `template/main`:

```shell
git rev-parse v4.0.0
```

Then create the file, replacing `template_ref` with your baseline from 1.2 and
`template_sha` with the SHA that `git rev-parse` just printed:

```shell
cat > .template-version <<'EOF'
# Records which docs-spec-template release this repository's tooling came from.
# Nothing reads this file. You update it manually at the end of every upgrade,
# in step 2.8. This is not a specification version -- spec versions are the
# v* git tags created by the version-bot.yml workflow.
template_ref: v4.0.0
template_sha: 0000000000000000000000000000000000000000
upgraded_on: 2026-08-17
EOF
git add .template-version
```

Record the SHA as well as the release name. The template's tag namespace is shared
with its own version-bot test tags (`vtest`, `v0.01`, `v1.0_rc1`), and tags can be
moved to point at a different commit. A SHA cannot.

### 1.4 Optional: check whether the newest release has what you need

The age of your own repository is not a problem here — you can upgrade from any
baseline, however old. This section is about the other end: whether the
*template's* newest numbered release actually contains the work you are
upgrading for.

**How to tell.** Open the template's
[`CHANGELOG.md`](https://github.com/riscv/docs-spec-template/blob/main/CHANGELOG.md)
and read the `[Unreleased]` section at the top. Anything listed there is merged
to `main` but is **not** in any numbered release yet. Today that includes the
Antora dual build, the GitHub Pages publish, and the pull request preview
artifact — the template's numbered releases (`v1.0.0` through `v4.0.4`)
currently lag behind its `main` branch.

If nothing under `[Unreleased]` matters to you, use the newest release and go on
to section 2.

If you do need something listed there, use a commit SHA from `template/main` as
your baseline instead of a release name:

```shell
git rev-parse template/main
```

Record that SHA in `.template-version` and leave `template_ref: template/main`.
Always pin to a specific SHA. Do not upgrade against `template/main` as a moving
target, or you will not be able to tell what changed between two upgrades.

Once the template's release line catches up with `main`, this section stops
being necessary — `[Unreleased]` will be empty and the newest release will have
everything.

---

## 2. Upgrade

### 2.1 Choose your target

Your **target** is the template version you are upgrading *to*. Set it once, as a
shell variable, and the rest of the commands in this section will use it:

```shell
TARGET=template/main
```

`template/main` applies the latest template code, which is what you normally
want. If you pinned to a commit SHA in 1.4, use that SHA here instead. If you
need to land on a specific *older* template version, contact `help@riscv.org`
rather than working it out from this guide.

Set your recorded baseline the same way, taking the value of `template_sha` from
your `.template-version` file:

```shell
BASELINE=<the template_sha from .template-version>
```

### 2.2 Optional: see what changed

You can skip this section and go straight to 2.3. It is here for when you want
to know what is arriving before you take it.

```shell
git fetch template
git log --oneline "$BASELINE".."$TARGET"
```

If your baseline is old, expect that list to be long — several hundred commits is
normal, and you are not meant to read it all. It is there to show you the size of
the jump.

Then read the template's changelog for the same range. The commit list tells you
what moved; the changelog tells you what it means for you, because that is where
breaking toolchain changes are described.

The easiest way to read it is on GitHub, which renders the changelog and lets you
browse file by file. Print the URL for your own two refs:

```shell
echo "https://github.com/riscv/docs-spec-template/compare/${BASELINE}...${TARGET#template/}"
```

Then open what it prints **in a browser** — this is a web page, not a command.
For example: <https://github.com/riscv/docs-spec-template/compare/v4.0.0...main>,
which compares release `v4.0.0` against the current `main`.

> **Note:** the changelog you want is the *template's* `CHANGELOG.md`, not yours.
> A `git diff -- CHANGELOG.md` in your own repository will show nothing if your
> repository has no `CHANGELOG.md` of its own, which is normal.

### 2.3 Create a branch

```shell
git switch -c chore/template-upgrade
```

### 2.4 Copy the template-owned files

Template-owned files have no per-repository content, so you can take the
template's version of them wholesale. `git checkout` from a ref copies specific
paths straight into your working tree — no merge, no conflicts, and no shared
history required:

```shell
git checkout $TARGET -- \
  scripts/ tests/ \
  .github/workflows/ .github/dependabot.yml \
  .pre-commit-config.yaml .vale.ini docker-compose.yml \
  ANTORA.md MIGRATION.md ARC_SUBMISSION.md
```

For the full list of which files are template-owned and why, see
[Which files are whose](#a-which-files-are-whose) in the Reference.

Now review what you just staged. This is the check that catches a template-owned
file you had customized locally without realizing it:

```shell
git diff --cached --stat
```

If a file shows up here that you did change on purpose, stop and read that one
diff before continuing. See [Template-owned](#template-owned) in the Reference
for what to do about a local edit to a template-owned file.

### 2.5 Merge the shared files manually

Shared files carry template structure **and** your customizations on the same
lines, so you cannot copy them. You have to apply the template's changes to your
copy while keeping your own values.

Look at what changed upstream:

```shell
git diff --stat "$BASELINE".."$TARGET" -- Makefile antora.yml antora-playbook.yml package.json
```

That gives you a summary of which files moved and by how much. To read an
individual file's changes, open the GitHub compare URL from 2.2 and click through
the files, or diff one file at a time locally:

```shell
git diff "$BASELINE".."$TARGET" -- Makefile
```

If reading a diff in the terminal is awkward, write it to a file and open it in
your editor instead:

```shell
git diff "$BASELINE".."$TARGET" -- Makefile > template-Makefile.diff
```

There is no tool for the merge itself — you edit your copy in a text editor. In
practice:

1. Get the template's version of the file somewhere you can open it:

   ```shell
   git show "$TARGET":Makefile > /tmp/Makefile.template
   ```

2. Copy across every change the diff showed, **except** the lines listed as yours
   in the table under [Shared files](#shared-files) in the Reference.
3. Re-run the diff against your edited copy. Whatever is left should be only the
   lines you deliberately kept.

For example, on a `Makefile` upgrade you keep your `DOCS` and `SPEC_SHORT` lines
and take everything else.

For `package.json`, take the template's `devDependencies` versions and keep your
`name` field. Then regenerate the lockfile rather than merging it:

```shell
npm install --package-lock-only
```

### 2.6 Check your PDF assembler

Your `src/<your-spec>.adoc` file is the one file that is both yours and the
template's at the same time — it names your chapters, but everything around those
`include::` lines is template scaffolding that changes when ARC requirements
change.

**What you are comparing, and why.** The file you diff is the template's own
sample assembler, `src/spec-sample.adoc`, at your two refs. That tells you what
scaffolding changed upstream. You then make the same change **by hand** in your
own `src/<your-spec>.adoc`. You never copy `spec-sample.adoc` over your own
file: it carries the sample specification's chapters and its own `spec_short`
value, not yours.

Start with a summary:

```shell
git diff --stat "$BASELINE".."$TARGET" -- src/
```

If that prints nothing, the template's assembler did not change between your two
refs and you can move on to 2.7.

If it does show changes, write the full diff to a file and open it in your
editor, or click through to `src/` in the GitHub compare URL from 2.2, which is
easier to read than a long AsciiDoc diff in a terminal:

```shell
git diff "$BASELINE".."$TARGET" -- src/ > template-src.diff
```

Then work through the diff one hunk at a time. Each hunk is one of two things:

- **A change to an attribute, a `[preface]` block, `toc::[]`, a `list-of::`
  macro, or `[index]`.** This is scaffolding. Make the same change, in the same
  position, in your own `src/<your-spec>.adoc`.
- **A change to an `include::` line.** This is the sample specification's own
  chapters. Ignore it — your `include::` lines are yours.

For example, if the diff shows the template adding an attribute default:

```diff
  ifndef::phase_display[:phase_display: {phase}]
+ ifndef::milestone_id[:milestone_id: {phase}]
  ifndef::spec_short[:spec_short: spec-sample]
```

then add that one `ifndef::milestone_id[...]` line to your own file in the same
place. The `spec_short` line on either side of it stays **yours** — the
template's value is `spec-sample`, and copying it in would break your PDF
filename.

When you have finished, build the PDF (3.1) and check pages 1 and 2.

> **If this step looks wrong to you, stop and ask rather than guessing.** A
> mistake here is the most common reason a repository upgrades cleanly and then
> fails ARC review, because the compliance requirements live in exactly the file
> that ownership rules say not to touch. Email `help@riscv.org` or open an issue
> on the template with `template-src.diff` and your `src/<your-spec>.adoc`
> attached, and someone will do this merge with you. See
> [The one file that is both](#the-one-file-that-is-both) in the Reference for
> the background.

### 2.7 Update the submodule

`docs-resources` upgrades on its own schedule — Dependabot proposes bumps
independently of template releases — but take the template's current pointer
during an upgrade so your build matches what the template tested:

```shell
git checkout $TARGET -- docs-resources
git submodule update --init --recursive
```

### 2.8 Record the new baseline

Update `.template-version` with the new ref, SHA, and today's date. If you do not
update this file now, your next upgrade will start back at the beginning, working
out your baseline from scratch.

### 2.9 Open a pull request

Everything so far has changed files in your local working tree only. Commit and
push the branch to open a pull request:

```shell
git add -A
git commit -m "chore: upgrade template to <target>"
git push -u origin chore/template-upgrade
```

Opening a pull request is also what runs the CI checks described in section 3.

---

## 3. Verify

### 3.1 Check it locally

Run all of these. The quickest ones are first, so a failure stops you early.

Start with the helper-script unit tests, which catch `release-info.sh`
regressions:

```shell
tests/release-info-test.sh
```

It takes about a second and finishes with a line like `64 passed, 0 failed`. If
it seems to hang instead, it is blocked on a prompt rather than working — the
test creates a throwaway git repository and commits into it, so a global git
setting such as commit signing can stop it dead. Press Ctrl-C and re-run it as
`bash -x tests/release-info-test.sh` to see which command it stopped on.

Next, confirm your version metadata still resolves:

```shell
./scripts/release-info.sh version
./scripts/release-info.sh phase "$(./scripts/release-info.sh version)"
```

Then run a full PDF build. This one needs Docker **running**, not merely
installed: the `Makefile` only checks that the `docker` command exists, and if it
does, it runs the build inside the RISC-V documentation container. Start Docker
first.

```shell
make clean && make build
```

If you would rather build with a locally installed AsciiDoctor toolchain, use
`make build-no-container` instead.

If the build fails inside `asciidoctor-bibtex`, your specification has no
bibliography. The `Makefile` loads that extension unconditionally, in `REQUIRES`,
but the `:bibtex-file:` attribute that points it at a `.bib` lives in your
`src/<your-spec>.adoc`. Either add that attribute and a `.bib` under
`modules/ROOT/resources/`, or remove `--require=asciidoctor-bibtex` from
`REQUIRES`. If you remove it, that becomes a local `Makefile` change you have to
carry through every future merge in 2.5 — so write it down with your other
`Makefile` values.

Now check the built PDF's filename:

```shell
ls build/*.pdf
```

You should see `<SPEC_SHORT>-v<MAJOR>.<MINOR>-<YYYYMMDD>.pdf`. If you see a bare
`<name>.pdf` instead, your `SPEC_SHORT` value did not survive the `Makefile`
merge in 2.5. Reopen your `Makefile`, restore the `SPEC_SHORT` line from your
pre-upgrade version, and run `make clean && make build` again.

Open the PDF and check page 1 (title, version, date) and page 2 (the *Document
State* preface with the phase notice). Both are checked at ARC submission time,
and an upgrade can change either of them, so it is worth confirming now rather
than discovering it during a submission.

Finally, build the site:

```shell
npm install
docker compose up -d kroki
npm run preview
```

That writes to `build/site/`. Citations and the bibliography will render as raw
text in this local preview. That is expected and not a regression — the `cite:`
and `bibliography::[]` macros are resolved by the central playbook's ASAM
extension, which is not bundled in this repository.

To reproduce exactly what CI publishes to GitHub Pages, which does include those
macros:

```shell
NO_STAMP=1 ./scripts/build-pages-site.sh
```

That writes to `build/pages-site/`.

### 3.2 What CI checks on your pull request

Once you push the branch and open a pull request, CI runs the PDF build,
`pre-commit`, Vale, and a check that your repository can still be consumed by the
central Antora site.

That last check also builds your site and attaches it to the pull request as a
*Rendered site (Antora)* artifact. You do not have to look at it, but downloading
it and clicking through a few sections is the fastest way to confirm an upgrade
did not break your navigation or page structure before you merge.

### 3.3 After you merge

Run `version-bot.yml` **only when you actually intend to cut a release**. A
template upgrade is not a specification revision. Merging it to `main` does not
tag one, and it should not.

---

## 4. What upgrades tend to break

These are the most common problems, most frequent first.

1. **`SPEC_SHORT` lost in a `Makefile` merge**, which produces a non-compliant PDF
   filename. Caught by the `ls build/*.pdf` check in 3.1.
2. **`antora.yml` overwritten wholesale.** Your component `name` reverts to
   `spec-sample`, which silently changes the published site URL and breaks the
   central playbook's registration of your component. Never `git checkout` this
   file from the template.
3. **A stamped value edited manually.** The `version`, `page-revnumber`,
   `page-revdate`, and `page-phase*` attributes in `antora.yml` are generated by
   `stamp-antora-version.sh`, which reads `release-info.sh` — the same source the
   PDF uses. Editing them manually desyncs the site from the PDF, which the ARC
   Author Guide requires to match exactly. Run `make stamp-antora` instead.
4. **`nav.adoc` reordered without a matching central update.** Chapter numbering on
   the published central site is keyed to the *line numbers* of the `xref` entries
   in `modules/ROOT/nav.adoc`, via `numbering_rules` in the central playbook — not
   by anything in your repository. If an upgrade reorders your nav, it needs a
   matching update in `github.com/riscv-admin/antora.riscv.org`. See *Section
   numbering* in [`ANTORA.md`](ANTORA.md).
5. **New workflows need new repository settings.** A workflow that arrives in an
   upgrade may need configuration that a running repository never had. Re-read the
   *Repository Setup Checklist* in [`README.adoc`](README.adoc) after every
   upgrade. Two in particular: the `GHTOKEN` secret, without which bot-opened pull
   requests have all their checks stall in `action_required`; and *Settings →
   Pages → Source: GitHub Actions*, which a RISC-V org admin has to set manually
   because the org restricts Pages creation and the workflow's own token is
   refused.
6. **Submodule left uninitialized** after `git checkout $TARGET -- docs-resources`.
   `make build` initializes it automatically, but `npm run preview` and
   `build-pages-site.sh` will fail on the missing cover logo first.

---

## 5. Rolling back

Because the template-owned files are copied with `git checkout` rather than
merged, reverting is clean — there is no merge commit to unpick.

To abandon an upgrade you have not merged yet, just leave the branch:

```shell
git switch main
```

To undo an upgrade you already merged, revert the commit and reset the submodule:

```shell
git revert --no-commit <upgrade-commit>
git submodule update --init --recursive
```

Then restore the previous values in `.template-version`.

---

## 6. When to upgrade

- **Before any ARC submission.** Upgrade first, then cut the release. ARC
  compliance requirements change in the template, and submitting from a stale
  toolchain is the most common way to fail on format rather than content.
- **Otherwise,** on a milestone boundary (`v0.6`, `v0.8`, `v0.9`, `v0.99`, `v1.0`)
  is a natural rhythm. Those are already governance checkpoints where the
  `SPEC_STATE.md` pull request gets maintainer attention.
- **Never** between a `version-bot.yml` run and the release build it triggers.

Log each upgrade in your `CHANGELOG.md` under `[Unreleased]`, naming the template
ref you moved to. This matters to two audiences: your own maintainers, who
otherwise have no record that the toolchain moved; and the template maintainers,
who need to know which template version a repository is on in order to help you
when a build breaks.

---

# Reference

Background material. You do not need any of it to run the procedure above.

## A. Which files are whose

The template has a clean split between files it owns and files you own. Classify
every path once, and every future upgrade becomes a routine application of those
rules rather than a fresh investigation.

### Template-owned

These have no per-repository content. Overwrite them without reading the diff
closely. If you have edited one of these locally, that edit is a fork you will be
re-doing on every upgrade forever, and it belongs upstream instead — please open
an issue on the template.

```
scripts/release-info.sh
scripts/stamp-antora-version.sh
scripts/update-spec-state.sh
scripts/build-pages-site.sh
scripts/gen-pages-playbook.js
tests/release-info-test.sh
.github/workflows/build-pdf.yml
.github/workflows/version-bot.yml
.github/workflows/publish-site.yml
.github/workflows/validate-content-source.yml
.github/workflows/pre-commit.yml
.github/workflows/vale-linting.yml
.github/dependabot.yml
.pre-commit-config.yaml
.vale.ini
docker-compose.yml
ANTORA.md
MIGRATION.md
ARC_SUBMISSION.md
UPGRADING.md
LICENSE
CODE_OF_CONDUCT.md
GOVERNANCE.md
```

`scripts/build-pages-site.sh` mentions `spec-sample`, but only in comments. It
reads `version:` from `antora.yml` at runtime, and the component name reaches it
via `start_page` in `antora-playbook.yml`, so the script itself carries nothing
per-repository.

`CONTRIBUTING.md` and `GOVERNANCE.md` are template-owned *unless* your task group
has amended them. If so, treat them as shared files.

`UPGRADING.md` is listed here, but note that your repository will not have a copy
until the template ships this guide in a release. Add it to the `git checkout`
command in 2.4 once it exists upstream.

### Shared files

These carry template structure **and** your customizations on the same lines. Do
not overwrite them. Read the template's changes and apply them to your copy,
keeping your own values from this table.

| File | What is yours |
| --- | --- |
| `Makefile` | `DOCS` (your top-level `.adoc`), `SPEC_SHORT`, and any local `REQUIRES` change (see 3.1) |
| `antora.yml` | `name`, `title`, `asamBibliography`; `version`/`page-*` are **generated**, never edited manually |
| `antora-playbook.yml` | `start_page: <your-component>::index.adoc` |
| `package.json` | `name` field; devDependency **versions** are template-owned |
| `README.adoc` | Almost entirely yours, but the template adds sections (setup checklist, new build steps) worth taking |
| `CHANGELOG.md` | Yours; see section 6 for how to log the upgrade itself |
| `.gitignore` | Usually identical; the template adds entries as new generated artifacts appear |
| `.gitmodules` | Usually identical — check rather than assume |
| `src/<your-spec>.adoc` | Your `include::` lines only; see below |

#### The one file that is both

`src/<your-spec>.adoc` is the hardest file in this list, because ownership and
structure point in opposite directions. The file is yours — it names your
chapters — but everything around the `include::` lines is template scaffolding
that changes when ARC requirements change:

- the `ifndef::` attribute defaults at the top of the file
- the `[preface] == Document State` block
- the `toc::[]` placement
- the `list-of::` macros for figures, tables, and listings
- the `[index]` position, before the bibliography

> Compare `src/spec-sample.adoc` against your own assembler on every upgrade,
> even though you never copy it over. This is the single most common source of a
> repository that upgrades cleanly and then fails ARC review, because the
> compliance requirements live in exactly the file that ownership rules say not
> to touch.

### Specification-specific files

Never take the template's version of these.

```
modules/ROOT/pages/*.adoc      your chapters
modules/ROOT/nav.adoc          your site navigation
modules/ROOT/resources/*.bib   your bibliography
SPEC_STATE.md                  maintained by update-spec-state.sh
MAINTAINERS.md
```

### Files to delete if you inherited them

`0001-Automate-Versioning.patch` is a historical artifact of the template. It has
no function in a specification repository — delete it.

## B. Why this needs a procedure

When you create a repository with GitHub's **Use this template**, GitHub copies
the file tree and starts a brand-new history — a single initial commit with no
ancestry shared with `docs-spec-template`. That is usually what you want, since
your specification's history is its own, but it has one consequence:

> Git sees your repository and the template as two unrelated projects. There is
> no common ancestor, so there is no automatic three-way merge.

Everything in this guide is about restoring enough of a relationship that
upgrades become a routine, repeatable operation instead of a manual investigation
every time.

There is a second, less obvious problem. In your repository, **`v*` tags mean
*specification* versions, not template versions.** `v0.62` is a milestone of your
spec, maintained by `version-bot.yml`. Nothing in a downstream repository records
which template version it was built from — which is why section 1.3 has you write
that down.

## C. Other approaches

Section 2 uses per-path `git checkout`, which is the approach this guide supports:
it needs no shared history, produces no merge conflicts, and the file ownership
rules are enforced by which paths you type.

Two other approaches will work, and are noted here so you recognize them if you
see them, but neither is supported by this guide:

- **`git merge template/main --allow-unrelated-histories`** gives you real
  three-way merges on later upgrades, but the first merge conflicts on
  essentially every specification file at once, and it interleaves the template's
  history with your specification's permanently.
- **`git cherry-pick -x <template-commit>`** is fine for pulling in one specific
  upstream fix, but does not work as a general strategy, because template changes
  routinely span a workflow, a script, and a doc in separate commits.

If you use either, you are on your own for conflict resolution.

## D. The other guides in this repository

| Guide | Question it answers |
| --- | --- |
| [`MIGRATION.md`](MIGRATION.md) | "My repo predates the Antora dual build. How do I adopt the current toolchain once?" |
| **`UPGRADING.md`** (this) | "I'm already on the toolchain. How do I keep up with the template as it changes?" |
| [`ANTORA.md`](ANTORA.md) | "Why is the dual build designed this way?" |
| [`ARC_SUBMISSION.md`](ARC_SUBMISSION.md) | "What does the ARC actually require?" |

---

## Questions

Open an issue on
[`github.com/riscv/docs-spec-template`](https://github.com/riscv/docs-spec-template/issues).
A template-owned file that you had to customize locally is a template bug, and
worth reporting as one.
