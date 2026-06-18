# md++ Reference Implementation Roadmap

[md:profile]: md++
[md:profile-version]: 0.15
[md:title]: <md++ Reference Implementation Roadmap>
[md:status]: draft

Status: draft 0.15
Document type: Reference implementation planning document

This document turns the plugin catalog and component architecture into an implementation sequence.

---

## 1. Milestone 0: conformance fixtures

Goal: make the specs testable before large implementation work.

Deliverables:

- sample md++ files for directives, includes, repositories, requirements, fenced blocks, models, themes, layouts, and diagnostics;
- expected diagnostic JSON files;
- expected dependency lists;
- minimal expected HTML snapshots;
- schema validation tests.

Exit criteria:

- fixtures can be run by any implementation;
- diagnostics use the separate diagnostic catalog;
- artifacts validate against the schema skeleton or its refined version.

---

## 2. Milestone 1: core language processor

Goal: parse and resolve md++ without advanced rendering.

Deliverables:

- GFM parser adapter;
- directive collector;
- requirement parser;
- include resolver;
- theme-context include resolver;
- repository core;
- file and memory repository providers;
- fenced block info-string parser;
- model registry skeleton;
- diagnostics aggregation.

Exit criteria:

- nested includes work across relative paths and repositories;
- duplicate model and repository errors are detected;
- requirement syntax is parsed consistently;
- source origins are preserved.

---

## 3. Milestone 2: basic HTML rendering

Goal: produce a useful HTML-compatible render tree.

Deliverables:

- ordinary Markdown renderer;
- render snapshot generation;
- stable node ids;
- source map builder;
- HTML exporter;
- syntax highlighting plugin;
- math plugin.

Exit criteria:

- CLI can render ordinary md++ documents to HTML;
- source map entries exist for headings, paragraphs, code blocks, and plugin placeholders;
- diagnostics can be emitted as text and JSON.

---

## 4. Milestone 3: plugin system

Goal: make rendering extensible.

Deliverables:

- plugin manifest validation;
- plugin registry;
- plugin host API;
- lifecycle hook dispatcher;
- block renderer dispatch;
- model parser dispatch;
- default dispatch table;
- Mermaid plugin;
- DOT model and render plugins.

Exit criteria:

- model blocks are absorbed when parsed successfully;
- plugin-owned render blocks can consume models;
- missing capabilities and dispatch conflicts produce diagnostics.

---

## 5. Milestone 4: layout and page model

Goal: support pages, slides, named areas, flow, and area renderers.

Deliverables:

- layout resource parser;
- presentation resolver;
- `layout.markdown.sections` plugin;
- `layout.flow` plugin;
- `area.flow`, `area.stack`, and `area.cards` plugins;
- page model artifact;
- overflow diagnostics.

Exit criteria:

- a slide/report example renders with named areas;
- area renderer behavior is plugin-specific and replaceable;
- invalid layout references and flow errors produce diagnostics.

---

## 6. Milestone 5: PDF and bundle export

Goal: support practical static delivery.

Deliverables:

- PDF export plugin;
- asset collection;
- font handling through host policy;
- bundle exporter;
- dependency report;
- reproducible CLI options.

Exit criteria:

- CLI can produce HTML, PDF, and bundle outputs;
- bundle can be loaded by the React viewer without direct filesystem access.

---

## 7. Milestone 6: React viewer

Goal: run md++ in a React web app from provided resources or bundles.

Deliverables:

- browser-safe processor build;
- memory and bundle repositories;
- DOM adapter;
- React component wrapper;
- interaction binding mount/apply/dispatch;
- dynamic whole-resource updates;
- diagnostics callback API.

Exit criteria:

- viewer runs from `file://` using bundled/provided resources;
- interactions can toggle UI state or dispatch plugin actions;
- updates return and apply patches or full rerenders safely.

---

## 8. Milestone 7: incremental update hardening

Goal: make updates dependable enough for editors.

Deliverables:

- patch invariants test suite;
- interaction patch tests;
- source map replacement/merge rules;
- dependency invalidation tests;
- plugin state compatibility tests.

Exit criteria:

- update behavior is deterministic;
- invalid patches are diagnosed;
- full rerender fallback works reliably.

---

## 9. Milestone 8: visual editor prototype

Goal: prove editor feasibility without committing to full WYSIWYG.

Deliverables:

- source editor integration;
- rendered preview;
- source/render selection mapping;
- diagnostics panel;
- block inspector;
- layout inspector;
- plugin trace viewer;
- basic quick fixes.

Exit criteria:

- user can edit source and see updated preview;
- selecting rendered output locates source;
- diagnostics and quick fixes are useful for common errors.

---

## 10. Deferred standardization

The following should remain explicit TODOs until implementation experience exists:

- exact document artifact lifecycle and versioning rules;
- semantic payload contracts for every document type;
- official md++ bundle format;
- editor quick-fix protocol;
- reversible transformations for visual editing;
- pixel-level rendering conformance;
- plugin marketplace/package distribution rules.

<!-- BEGIN mdpp-office-pipeline-update-v0-15: roadmap -->

## 11. Milestone 6A: Office import normalization

Goal: make DOCX/PPTX-like inputs usable as semantic md++ source without pretending the conversion is lossless.

Deliverables:

- Office-like import provider skeleton;
- style-name to md++ class normalization;
- image extraction to assets;
- comment/review sidecar extraction;
- page furniture extraction for headers, footers, and page numbers;
- `MDPP0700`-range diagnostics for lossy import cases;
- examples `75` through `77` as normalized-output fixtures.

Exit criteria:

- a normal report-like DOCX can be converted to readable md++;
- comments and review notes are preserved as sidecar metadata;
- unsupported Office features produce stable diagnostic codes;
- generated md++ can still be rendered by the normal HTML/PDF pipeline.

<!-- END mdpp-office-pipeline-update-v0-15: roadmap -->
