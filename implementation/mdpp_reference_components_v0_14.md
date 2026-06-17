# md++ Reference Implementation Components

[md:profile]: md++
[md:profile-version]: 0.14
[md:title]: <md++ Reference Implementation Components>
[md:status]: draft

Status: draft 0.14  
Document type: Reference implementation planning document  
Related plugin catalog: `mdpp_reference_plugin_catalog_v0_14.md`

This document lists the reusable components required to implement md++ tools, with stable boundaries so components can be implemented and tested independently.

---

## 1. Component architecture goals

A real md++ implementation should avoid building one monolithic renderer. The same modules should support:

- a Node.js CLI that exports HTML and PDF;
- a React-compatible viewer that runs from `file://` using provided resources or bundles;
- a future visual editor.

The components should communicate through stable interfaces based on the md++ language spec, runtime architecture, diagnostic catalog, and artifact schemas.

---

## 2. Core packages

### 2.1. `@mdpp/types`

Owns shared TypeScript types and generated JSON Schema bindings.

Responsibilities:

- exported artifact interfaces;
- diagnostic shape;
- render tree shape;
- patch shape;
- interaction binding shape;
- plugin metadata and manifest shape;
- repository and resource envelope types;
- semantic version compatibility helpers.

Should not depend on React, Node-only APIs, browser DOM APIs, or any specific Markdown parser.

### 2.2. `@mdpp/schemas`

Owns official JSON Schemas.

Responsibilities:

- schema publication;
- schema versioning;
- runtime validation helpers;
- schema test fixtures.

The schema package should be usable from Node and browser environments.

### 2.3. `@mdpp/diagnostics`

Owns diagnostic codes and formatting.

Responsibilities:

- diagnostic catalog constants;
- severity normalization;
- diagnostic formatting for CLI, HTML, JSON, and editor output;
- source-origin formatting;
- conversion to diagnostic report documents.

---

## 3. Parsing and language components

### 3.1. `@mdpp/markdown-parser-gfm`

Parses ordinary GFM Markdown while preserving enough source information for md++ interpretation.

Responsibilities:

- parse GFM Markdown;
- preserve headings, block ranges, fenced block info strings, tables, links, and reference definitions;
- expose repeated `md:` link-reference definitions in source order;
- avoid normalizing away syntax needed for diagnostics.

### 3.2. `@mdpp/directives`

Collects and parses md++ directives.

Responsibilities:

- identify `md:` labels;
- collect repeated directives;
- parse profile, metadata, include, repository, theme, layout, stylesheet, and require directives;
- return structured diagnostics for invalid directive syntax.

### 3.3. `@mdpp/requirements`

Parses and resolves capability requirements.

Responsibilities:

- implement the formal `md:require` grammar;
- handle repository-scoped capability names;
- evaluate version constraints;
- produce unresolved and resolved requirement tables;
- provide deterministic provider selection inputs.

### 3.4. `@mdpp/info-string`

Parses fenced block info strings.

Responsibilities:

- parse block type;
- parse `key=value`, quoted values, and flags;
- preserve source ranges for attributes;
- report invalid forms.

---

## 4. Resource and repository components

### 4.1. `@mdpp/repository-core`

Defines repository interfaces and reference resolution utilities.

Responsibilities:

- canonical reference normalization;
- repository-qualified reference parsing;
- nested include base tracking;
- path normalization;
- read response envelope handling;
- metadata normalization.

### 4.2. `@mdpp/repository-file`

Node/editor local filesystem provider.

Responsibilities:

- read local files;
- optionally write/create/move/delete when host policy allows;
- detect path traversal outside allowed roots;
- return content hashes and metadata.

### 4.3. `@mdpp/repository-memory`

In-memory repository provider for tests, demos, React viewers, and sandboxes.

Responsibilities:

- read resources from a provided map;
- support dynamic updates;
- expose change events for rerendering;
- optionally support writes in editor/test contexts.

### 4.4. `@mdpp/repository-bundle`

Browser-friendly bundle provider.

Responsibilities:

- load md++ resource bundles;
- expose bundle entries as repository resources;
- support `file://` viewer operation without arbitrary local filesystem access;
- provide dependency hashes and metadata.

### 4.5. `@mdpp/repository-http`

HTTP/HTTPS provider for Node and hosted browser use when allowed.

Responsibilities:

- fetch remote resources;
- respect host policy;
- normalize media types;
- cache only according to host configuration.

---

## 5. Plugin infrastructure components

### 5.1. `@mdpp/plugin-registry`

Discovers, validates, and selects plugins.

Responsibilities:

- load plugin manifests;
- validate capabilities;
- resolve version constraints;
- build dispatch tables;
- expose selected plugin trace output.

### 5.2. `@mdpp/plugin-host`

Provides the restricted host API exposed to plugins.

Responsibilities:

- resource access;
- model repository access;
- diagnostics;
- presentation context access;
- policy decisions;
- lifecycle event dispatch.

### 5.3. `@mdpp/plugin-runner`

Runs plugin operations inline, in workers, or in external processes.

Responsibilities:

- lifecycle hook execution;
- block render calls;
- model parse calls;
- interaction calls;
- update calls;
- error isolation;
- timeout and cancellation integration when host supports it.

### 5.4. `@mdpp/rpc-json`

Implements the standard JSON-RPC profile for cross-language worker/process boundaries.

Responsibilities:

- request/response framing;
- artifact serialization;
- error mapping to diagnostics;
- cancellation messages;
- transport adapters for stdio, WebSocket, Web Worker, and MessagePort.

---

## 6. Processing pipeline components

### 6.1. `@mdpp/processor`

Coordinates parse, resolve, model registration, presentation resolution, and rendering.

Responsibilities:

- root source ingestion;
- include resolution;
- repository table construction;
- model block absorption;
- plugin dispatch;
- diagnostics aggregation;
- dependency tracking;
- incremental invalidation inputs.

### 6.2. `@mdpp/model-registry`

Owns resolved models.

Responsibilities:

- enforce unique model names;
- preserve model origins;
- expose model summaries and full model data;
- track model diagnostics;
- support invalidation and update.

### 6.3. `@mdpp/presentation-resolver`

Resolves themes, layouts, stylesheets, assets, and plugin defaults.

Responsibilities:

- apply resource precedence rules;
- resolve theme tokens;
- expose CSS variables;
- produce presentation diagnostics;
- provide plugin presentation defaults.

### 6.4. `@mdpp/layout-engine`

Coordinates layout interpretation and flow.

Responsibilities:

- parse layout resources;
- compute canvas and area structures;
- dispatch layout interpretation plugins;
- dispatch area renderer plugins;
- classify overflow;
- produce page model artifacts.

The actual interpretation of Markdown sections into pages and areas should be delegated to a layout plugin such as `layout.markdown.sections`.

---

## 7. Rendering and interaction components

### 7.1. `@mdpp/render-core`

Produces serializable render trees.

Responsibilities:

- render ordinary Markdown nodes;
- insert plugin render outputs;
- preserve semantic HTML hooks;
- produce stable renderer node identifiers;
- collect interaction bindings;
- collect source map inputs.

### 7.2. `@mdpp/dom-adapter`

Mounts render trees into an actual host UI.

Responsibilities:

- create DOM nodes from render snapshots;
- apply DOM patches;
- maintain node id to DOM element mapping;
- attach interaction bindings;
- normalize DOM events;
- dispatch host/plugin/worker actions.

This component is browser-specific but should not depend on React.

### 7.3. `@mdpp/react-viewer`

React wrapper around the processor, renderer, repository providers, and DOM adapter.

Responsibilities:

- expose a React component API;
- accept source text, entry refs, or bundles;
- support dynamic updates;
- expose diagnostics callbacks;
- expose interaction callbacks;
- operate from `file://` using memory or bundle repositories.

### 7.4. `@mdpp/source-map`

Builds and queries source maps.

Responsibilities:

- map rendered node ids to source ranges;
- map source ranges to rendered node ids;
- merge plugin-provided maps;
- support editor navigation;
- return precision metadata.

### 7.5. `@mdpp/interactions`

Owns normalized interaction dispatch.

Responsibilities:

- validate interaction bindings;
- authorize actions through host policy;
- dispatch host actions;
- dispatch main-thread plugin actions;
- dispatch worker actions;
- apply returned patches and interaction changes.

---

## 8. Export components

### 8.1. `@mdpp/export-html`

Serializes render trees into HTML.

Responsibilities:

- emit standalone HTML;
- emit embeddable fragments;
- include stylesheets and assets according to host policy;
- embed diagnostics optionally;
- preserve source map references when requested.

### 8.2. `@mdpp/export-pdf`

Converts rendered output to PDF.

Responsibilities:

- use a deterministic browser/export backend;
- apply page model geometry;
- wait for allowed async assets;
- report PDF-specific diagnostics;
- preserve metadata when possible.

### 8.3. `@mdpp/export-bundle`

Packages md++ documents and resources for portable browser viewing.

Responsibilities:

- collect dependency lists;
- copy or embed resources;
- generate a bundle manifest;
- optionally include pre-rendered assets;
- support React `file://` viewer input.

---

## 9. Application shell components

### 9.1. `@mdpp/cli`

Node.js command-line application.

Responsibilities:

- parse CLI arguments;
- configure host policy;
- load plugins;
- render HTML/PDF;
- emit diagnostics;
- support watch mode when requested;
- support JSON output for automation.

### 9.2. `@mdpp/viewer-react`

React component package.

Responsibilities:

- render md++ from source, ref, or bundle;
- expose props for host policy and plugin configuration;
- support dynamic resource updates;
- report diagnostics and selection events;
- avoid Node-only dependencies.

### 9.3. `@mdpp/editor-core`

Editor-neutral services for a future visual editor.

Responsibilities:

- maintain source document state;
- coordinate source edits and rerenders;
- expose source/render selection mapping;
- support block inspector data;
- support diagnostic quick-fix proposals.

### 9.4. `@mdpp/editor-react`

Optional React visual editor shell.

Responsibilities:

- compose source editor, rendered preview, diagnostics, and inspectors;
- call editor-core APIs;
- avoid defining language behavior.

The visual editor should be considered experimental until source maps, patches, diagnostics, and schemas are exercised by the CLI and viewer implementations.

---

## 10. Component dependency direction

Recommended dependency direction:

```text
@mdpp/types
@mdpp/schemas
@mdpp/diagnostics
  -> parsing/directives/requirements/info-string
  -> repository-core/providers
  -> plugin-registry/plugin-host/plugin-runner/rpc-json
  -> processor/model-registry/presentation-resolver/layout-engine
  -> render-core/source-map/interactions
  -> dom-adapter/react-viewer/exporters
  -> cli/editor shells
```

Lower-level packages must not depend on application shells.

---

## 11. Stable interface checkpoints

Before implementing application shells, stabilize these interfaces:

1. artifact schemas;
2. diagnostic shape and code catalog;
3. repository resource envelope;
4. plugin manifest shape;
5. plugin dispatch and lifecycle hooks;
6. render snapshot and patch shapes;
7. interaction binding and event payload shape;
8. source map query API;
9. layout/page model artifact shape.

<!-- BEGIN mdpp-office-pipeline-update-v0-14: components -->

## 12. Office import and page-furniture component additions

The Office-normalization update adds these implementation responsibilities.

### `@mdpp/types`

Additional responsibilities:

- page-furniture profile and slot types;
- theme class/component declaration types;
- comment/review sidecar types;
- import diagnostic metadata fields.

### `@mdpp/import-office`

Coordinates lossy Office-like import into semantic md++.

Responsibilities:

- read DOCX/PPTX-like source artifacts through host-approved providers;
- map headings, paragraphs, lists, tables, images, named styles, headers, footers, and page numbers into md++ resources;
- extract comments, speaker notes, and review metadata to sidecar artifacts;
- emit `MDPP0700`-range diagnostics for lossy or unsupported features;
- preserve source-origin and traceability metadata where possible.

### `@mdpp/presentation-resolver`

Additional responsibilities:

- resolve theme-defined style classes;
- resolve theme-defined components;
- resolve page-furniture profiles;
- expose generated page-furniture values to layout/export components.

### `@mdpp/layout-engine` and exporters

Additional responsibilities:

- attach active page-furniture profiles to page-model artifacts;
- resolve page numbers and page counts after pagination;
- emit `MDPP0416`, `MDPP0417`, and `MDPP0418` when page-furniture references cannot be resolved.

<!-- END mdpp-office-pipeline-update-v0-14: components -->
