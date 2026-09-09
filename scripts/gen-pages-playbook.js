#!/usr/bin/env node
'use strict';

// Generate the GitHub Pages playbook by OVERLAYING a few keys onto the local
// preview playbook (antora-playbook.yml).
//
// Why derive instead of committing a second playbook: antora-playbook.yml
// carries a large `asciidoc.attributes` block that is a hand-maintained MIRROR
// of the central playbook (github.com/riscv-admin/antora.riscv.org) -- see
// ANTORA.md design rule #2. A second standalone playbook would duplicate that
// block, and the two copies would silently drift apart on the next central
// change. So the Pages build reuses it verbatim and overrides only:
//
//   site.url        -- the Pages base URL (project sites live under /<repo>/,
//                      not at the domain root, and Antora needs the base path
//                      for the sitemap and any absolute links)
//   content.sources -- the versions to publish (see build-pages-site.sh)
//   output.dir      -- separate from the preview output, so a publish never
//                      clobbers ./build/site
//   cover-logo      -- resolve the cover logo from THIS component instead of
//                      the central `common` component, which does not exist in
//                      a single-repo build (see antora.yml)
//
// Usage: gen-pages-playbook.js --out <file> [--url <base>] [--source <json>]...
// Each --source is a JSON object appended to content.sources, in order.

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

function parseArgs(argv) {
  const args = { sources: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (value === undefined) throw new Error(`missing value for ${flag}`);
    switch (flag) {
      case '--in': args.in = value; i += 1; break;
      case '--out': args.out = value; i += 1; break;
      case '--url': args.url = value; i += 1; break;
      case '--output-dir': args.outputDir = value; i += 1; break;
      case '--cover-logo': args.coverLogo = value; i += 1; break;
      case '--source': args.sources.push(JSON.parse(value)); i += 1; break;
      default: throw new Error(`unknown option: ${flag}`);
    }
  }
  if (!args.in) throw new Error('--in is required');
  if (!args.out) throw new Error('--out is required');
  if (!args.sources.length) throw new Error('at least one --source is required');
  return args;
}

const args = parseArgs(process.argv.slice(2));
const playbook = yaml.load(fs.readFileSync(args.in, 'utf8'));

playbook.site = playbook.site || {};
if (args.url) playbook.site.url = args.url;

playbook.content = playbook.content || {};
playbook.content.sources = args.sources;

if (args.outputDir) {
  playbook.output = playbook.output || {};
  playbook.output.dir = args.outputDir;
}

// Hard-set (no trailing `@`), so it takes precedence over the default in the
// component descriptor. antora.yml keeps the `common::` value that the central
// multi-source build needs; only this build swaps in the vendored copy.
if (args.coverLogo) {
  playbook.asciidoc = playbook.asciidoc || {};
  playbook.asciidoc.attributes = playbook.asciidoc.attributes || {};
  playbook.asciidoc.attributes['cover-logo'] = args.coverLogo;
}

const banner = [
  '# GENERATED FILE -- DO NOT EDIT, DO NOT COMMIT.',
  '# Produced by scripts/gen-pages-playbook.js from ' + path.basename(args.in) + '.',
  '# Edit that file (or scripts/build-pages-site.sh) instead.',
  '',
].join('\n');

fs.writeFileSync(args.out, banner + yaml.dump(playbook, { lineWidth: -1, noRefs: true }));
process.stdout.write(`wrote ${args.out}\n`);
