# md++ Reference Plugin Catalog

[md:profile]: md++
[md:profile-version]: 0.15
[md:title]: <md++ Reference Plugin Catalog>
[md:status]: draft

Status: draft 0.15
Document type: Reference implementation planning document
Related language spec: `../specs/mdpp_language_spec_v0_15.md`
Related runtime architecture: `../specs/mdpp_reference_runtime_architecture_v0_15.md`

This document describes a practical set of plugins that can provide useful md++ capability for three implementation targets:

- a Node.js CLI that renders md++ to HTML or PDF;
- a React-compatible viewer component that can run from `file://`, display md++, support interactions, and dynamically update content;
- a future visual editor for md++.

This document is not part of the md++ language. It defines a recommended plugin set for a reference implementation.

---

## 1. Plugin catalog principles

### 1.1. Plugin-specific behavior stays outside the language

The md++ language defines syntax, dispatch points, and portable semantics. Specialized behavior belongs to plugins or host-selected providers.

Examples:

- Mermaid rendering belongs to a diagram plugin.
- DOT parsing belongs to a model plugin.
- Area rendering such as `cards`, `timeline`, or `chevron-chain` belongs to area renderer plugins.
- Page/slide section mapping belongs to a layout interpretation plugin.
- PDF generation belongs to an export plugin or host component.

### 1.2. Stable plugin boundaries

Each plugin should expose capabilities, input document types, output document types, diagnostics, and update support in a stable way.

A plugin should be independently implementable when the following are known:

- capability names and versions;
- supported document types;
- supported transformation hooks;
- required host APIs;
- optional lifecycle hooks;
- security manifest requirements;
- diagnostics it may emit.

### 1.3. Minimum useful set

A minimum usable reference implementation should support:

- GFM Markdown parsing;
- md++ directive and fenced-block interpretation;
- include and repository resolution;
- theme/layout/stylesheet loading;
- HTML render tree generation;
- syntax highlighting;
- Mermaid diagrams;
- DOT model parsing and rendering;
- basic layout interpretation;
- source maps and diagnostics;
- PDF export for the CLI target;
- interaction bindings and DOM patch application for the React viewer target.

---

## 2. Plugin roles

### 2.1. Repository provider plugins

Repository providers resolve and access repository roots. They do not define md++ syntax.

| Plugin id | Capability | Required for | Purpose |
|---|---|---|---|
| `repository.file` | `repository.file@1` | Node CLI, editor | Read/write local filesystem resources. |
| `repository.http` | `repository.http@1` | Node CLI, hosted web apps | Read remote HTTP/HTTPS resources when allowed by host policy. |
| `repository.memory` | `repository.memory@1` | React `file://`, tests, editor | Provide resources from an in-memory map. |
| `repository.bundle` | `repository.bundle@1` | React `file://`, portable packages | Resolve resources from a provided bundle such as a zip, JSON package, or embedded asset map. |
| `repository.git` | `repository.git@1` | CLI, editor | Resolve resources from Git repositories when implemented by the host. |

`repository.file` should be treated as a Node/editor plugin, not a browser `file://` plugin. Browsers normally cannot read arbitrary local paths from a page loaded via `file://` without user selection or a packaged resource map.

### 2.2. Document type provider plugins

Document type providers define parsing, serialization, validation, patching, and semantic access for typed artifacts.

| Plugin id | Capability | Document types | Purpose |
|---|---|---|---|
| `document.markdown.gfm` | `markdown.gfm@1` | `text.markdown.gfm` | Parse ordinary GFM Markdown. |
| `document.mdpp.source` | `mdpp.source@1` | `mdpp.source` | Preserve source text, origin metadata, directives, and repeated reference definitions. |
| `document.mdpp.resolved` | `mdpp.resolved@1` | `mdpp.resolved-tree` | Represent an include-resolved md++ document tree. |
| `document.mdpp.block` | `mdpp.block@1` | `mdpp.block-source` | Represent fenced blocks and block fragments. |
| `document.mdpp.model` | `mdpp.model@1` | `mdpp.model` | Represent registered models with source and parsed semantic data. |
| `document.mdpp.render-tree` | `mdpp.render-tree@1` | `mdpp.render-tree` | Represent serializable render snapshots. |
| `document.mdpp.page-model` | `mdpp.page-model@1` | `mdpp.page-model` | Represent generated pages, areas, flow, and overflow state. |
| `document.html.fragment` | `html.fragment@1` | `html.fragment` | Represent sanitized HTML fragments. |
| `document.svg` | `svg.document@1` | `svg.document` | Represent SVG output. |
| `document.pdf` | `pdf.document@1` | `pdf.document` | Represent PDF output. |
| `document.diagnostics` | `mdpp.diagnostics@1` | `mdpp.diagnostics` | Represent diagnostics as a report document when needed. |

### 2.3. Core transformation plugins

These plugins provide the md++ processing pipeline.

| Plugin id | Capability | Input | Output | Purpose |
|---|---|---|---|---|
| `mdpp.directive.collector` | `mdpp.directives@1` | `mdpp.source` | directive table | Collect `md:` directives in source order. |
| `mdpp.requirements.resolver` | `mdpp.requirements@1` | directive table | resolved requirements | Parse and resolve capability requirements. |
| `mdpp.include.resolver` | `include@1` | `mdpp.source` | `mdpp.resolved-tree` | Resolve nested includes and preserve source origins. |
| `mdpp.resource.resolver` | `resource@1` | resource refs | resources | Resolve relative and repository-qualified resources. |
| `mdpp.model.registry` | `mdpp.models@1` | model parse results | model repository | Register unique named models. |
| `mdpp.presentation.resolver` | `mdpp.presentation@1` | directives/resources | presentation context | Resolve themes, layouts, stylesheets, assets, and plugin defaults. |
| `mdpp.html.renderer` | `mdpp.render.html@1` | `mdpp.resolved-tree` | `mdpp.render-tree` | Render md++ content to a serializable HTML-compatible tree. |
| `mdpp.source-map.builder` | `mdpp.source-map@1` | render results | source map | Build node-to-source and source-to-node mappings. |
| `mdpp.diagnostic.reporter` | `mdpp.diagnostics@1` | diagnostics | diagnostic report | Normalize diagnostics and optionally materialize them as a document. |

Some implementations may treat these as internal modules rather than separately installed plugins. They should still preserve stable interfaces so they can be tested and replaced independently.

### 2.4. Syntax highlighting plugins

| Plugin id | Capability | Purpose |
|---|---|---|
| `highlight.core` | `highlight.core@1` | Provide generic code block rendering and language fallback. |
| `highlight.prism` | `highlight.prism@1` | Reference syntax highlighter for browser and Node targets. |
| `highlight.shiki` | `highlight.shiki@1` | Optional high-quality syntax highlighting, especially for CLI/static export. |

The reference implementation should support at least one highlighter plugin. `highlight.prism` is the simplest browser-friendly default; `highlight.shiki` is useful for richer static exports.

### 2.5. Math plugins

| Plugin id | Capability | Purpose |
|---|---|---|
| `math.latex.katex` | `math.latex@1` | Render LaTeX-compatible inline and block math. |

The language defines math syntax. Rendering quality and exact supported LaTeX commands belong to the math plugin.

### 2.6. Diagram and model plugins

| Plugin id | Capability | Input | Output | Purpose |
|---|---|---|---|---|
| `diagram.mermaid` | `diagram.mermaid@1` | Mermaid block source | render tree or SVG | Render Mermaid fenced blocks. |
| `model.dot` | `model.dot@1` | DOT block source with `model=NAME` | `mdpp.model` | Parse DOT as a named model. |
| `diagram.dot` | `diagram.dot@1` | DOT block source | render tree or SVG | Render ordinary DOT blocks. |
| `diagram.dot.render` | `diagram.dot.render@1` | model reference + render block | render tree or SVG | Render a named DOT model. |

DOT parsing and DOT rendering may be implemented by the same package, but they should expose separate capabilities so authors and hosts can require them independently.

### 2.7. Layout interpretation and area renderer plugins

The language defines layout resources, areas, and flow properties. The interpretation of Markdown fragments into pages, slides, and area-local structures should be provided by layout and area plugins.

| Plugin id | Capability | Input | Output | Purpose |
|---|---|---|---|---|
| `layout.markdown.sections` | `layout.markdown.sections@1` | Markdown fragment + active layout | page model | Interpret headings/classes into page and area assignments. |
| `layout.flow` | `layout.flow@1` | page model + render tree | paginated page model | Apply area flow and overflow continuation. |
| `area.flow` | `area.flow@1` | area fragment | render tree | Render ordinary content in source order. |
| `area.stack` | `area.stack@1` | area fragment | render tree | Stack child blocks vertically. |
| `area.cards` | `area.cards@1` | area fragment | render tree | Render child sections as cards. |
| `area.chevron-chain` | `area.chevron-chain@1` | area fragment | render tree | Render child sections as chevron steps. |
| `area.timeline` | `area.timeline@1` | area fragment | render tree | Render child sections as timeline items. |
| `area.cycle` | `area.cycle@1` | area fragment | render tree | Render child sections as a cycle. |
| `area.hub-spoke` | `area.hub-spoke@1` | area fragment | render tree | Render one hub item and surrounding spokes. |

The minimum reference implementation should include `layout.markdown.sections`, `layout.flow`, `area.flow`, `area.stack`, and one visual area renderer such as `area.cards` or `area.chevron-chain`.

### 2.8. Interaction plugins

| Plugin id | Capability | Purpose |
|---|---|---|
| `interaction.host-actions` | `interaction.host-actions@1` | Implement built-in host actions such as show/hide, toggle class, scroll, and emit. |
| `interaction.state-store` | `interaction.state-store@1` | Provide simple stateful interactions for examples and demos. |
| `interaction.diagram-selection` | `interaction.diagram-selection@1` | Provide selection/highlight behavior for diagram renderers. |

Interaction plugins should declare whether actions run on the main thread, in a worker, or as host actions. The host still decides whether to allow them.

### 2.9. Export plugins

| Plugin id | Capability | Required for | Purpose |
|---|---|---|---|
| `export.html.static` | `export.html@1` | CLI, viewer tests | Serialize render tree to standalone or embedded HTML. |
| `export.pdf.playwright` | `export.pdf@1` | Node CLI | Convert rendered HTML/page model to PDF. |
| `export.png.playwright` | `export.image@1` | Optional CLI | Export selected pages or areas to images. |
| `export.bundle` | `export.bundle@1` | React `file://` | Package md++ sources and resources into a portable bundle. |

PDF export is implementation-specific. The reference Node CLI should define one concrete default plugin so outputs are reproducible.

### 2.10. Validation and analysis plugins

| Plugin id | Capability | Purpose |
|---|---|---|
| `validate.mdpp.core` | `validate.mdpp@1` | Validate directives, requirements, includes, model names, layout references, and diagnostics. |
| `validate.links` | `validate.links@1` | Validate local and repository-qualified links/resources. |
| `validate.accessibility` | `validate.accessibility@1` | Check headings, alt text, contrast metadata, and semantic output. |
| `analyze.dependencies` | `analyze.dependencies@1` | Produce dependency graphs for includes, resources, models, and plugins. |

### 2.11. Visual editor support plugins

The visual editor target should be treated as experimental until the language and runtime stabilize further.

| Plugin id | Capability | Purpose |
|---|---|---|
| `editor.source-map.navigator` | `editor.source-map@1` | Navigate from rendered nodes to source ranges. |
| `editor.block-inspector` | `editor.block-inspector@1` | Inspect block attributes, plugin ownership, and diagnostics. |
| `editor.layout-inspector` | `editor.layout-inspector@1` | Inspect pages, areas, flow, overflow, and area renderer decisions. |
| `editor.quick-fixes` | `editor.quick-fixes@1` | Offer structured fixes for known diagnostic codes. |
| `editor.schema-assist` | `editor.schema-assist@1` | Provide completion and validation from JSON Schemas and plugin manifests. |

These plugins should depend on stable diagnostics, source maps, schemas, and document artifact contracts. They should not invent language semantics.

---

## 3. Minimum plugin bundles

### 3.1. Node CLI HTML bundle

Minimum plugins:

```text
repository.file
repository.memory
document.markdown.gfm
document.mdpp.source
document.mdpp.resolved
document.mdpp.block
document.mdpp.model
document.mdpp.render-tree
mdpp.directive.collector
mdpp.requirements.resolver
mdpp.include.resolver
mdpp.resource.resolver
mdpp.model.registry
mdpp.presentation.resolver
mdpp.html.renderer
mdpp.source-map.builder
mdpp.diagnostic.reporter
highlight.prism
math.latex.katex
diagram.mermaid
model.dot
diagram.dot
diagram.dot.render
layout.markdown.sections
layout.flow
area.flow
area.stack
area.cards
export.html.static
validate.mdpp.core
```

### 3.2. Node CLI PDF bundle

Add:

```text
export.pdf.playwright
```

Optional:

```text
highlight.shiki
export.png.playwright
validate.accessibility
analyze.dependencies
```

### 3.3. React `file://` viewer bundle

Minimum plugins:

```text
repository.memory
repository.bundle
document.markdown.gfm
document.mdpp.source
document.mdpp.resolved
document.mdpp.block
document.mdpp.model
document.mdpp.render-tree
mdpp.directive.collector
mdpp.requirements.resolver
mdpp.include.resolver
mdpp.resource.resolver
mdpp.model.registry
mdpp.presentation.resolver
mdpp.html.renderer
mdpp.source-map.builder
mdpp.diagnostic.reporter
highlight.prism
math.latex.katex
diagram.mermaid
model.dot
diagram.dot.render
layout.markdown.sections
layout.flow
area.flow
area.stack
area.cards
interaction.host-actions
interaction.state-store
validate.mdpp.core
```

The viewer should accept resources through props, an in-memory bundle, drag/drop, file picker APIs, or a prebuilt package. It should not assume arbitrary local path reads from `file://`.

### 3.4. Visual editor experimental bundle

Start from the React viewer bundle and add:

```text
repository.file or repository.workspace
editor.source-map.navigator
editor.block-inspector
editor.layout-inspector
editor.quick-fixes
editor.schema-assist
validate.links
validate.accessibility
analyze.dependencies
```

A serious visual editor should wait until source maps, patch/update invariants, diagnostic codes, plugin manifests, and schemas have been exercised by the CLI and viewer targets.

---

## 4. Default dispatch table

A reference implementation should use a deterministic default dispatch table.

| Input condition | Preferred plugin |
|---|---|
| local filesystem repository root in Node/editor | `repository.file` |
| in-memory bundle repository root | `repository.bundle` |
| unresolved test/demo resource map | `repository.memory` |
| ordinary GFM Markdown | `document.markdown.gfm` |
| `md:` directives | `mdpp.directive.collector` |
| `[md:include]:` | `mdpp.include.resolver` |
| `model=NAME` on `dot` block | `model.dot` |
| ordinary `mermaid` block | `diagram.mermaid` |
| ordinary `dot` block | `diagram.dot` |
| `diagram.dot.render` block | `diagram.dot.render` |
| `$$` or inline math | `math.latex.katex` |
| unknown code language | `highlight.core` |
| known code language in browser | `highlight.prism` |
| known code language in static export | `highlight.prism` or `highlight.shiki`, according to host configuration |
| active layout to pages/areas | `layout.markdown.sections` |
| area with no declared renderer | `area.flow` |
| area with `renderer: stack` | `area.stack` |
| area with `renderer: cards` | `area.cards` |
| area with `renderer: chevron-chain` | `area.chevron-chain` |
| HTML export | `export.html.static` |
| PDF export | `export.pdf.playwright` |

Host configuration may override this table. Overrides should be visible in diagnostics or trace output.

---

## 5. Plugin manifest expectations

Each plugin package should include an `mdpp-plugin.json` manifest.

Recommended fields:

```json
{
  "id": "diagram.mermaid",
  "version": "1.0.0",
  "capabilities": [
    { "name": "diagram.mermaid", "version": "1.0.0" }
  ],
  "roles": ["block-renderer"],
  "documentTypes": {
    "inputs": ["mdpp.block-source"],
    "outputs": ["mdpp.render-tree", "svg.document"]
  },
  "workerEntryPoint": "./worker.js",
  "mainThreadEntryPoint": "./main.js",
  "permissions": {
    "resources": [],
    "network": false,
    "filesystem": false,
    "mainThreadActions": ["diagram.select"]
  }
}
```

The manifest declares requested permissions. The host decides whether to approve, deny, restrict, or substitute capabilities.

---

## 6. Open items

The following should remain tracked in the runtime architecture or future implementation documents:

- exact semantic model shape for each document type;
- compatibility rules for plugin version upgrades;
- official test corpus per plugin role;
- exact visual output expectations for area renderer plugins;
- editor-grade reversible transformations between source and rendered structure;
- packaging format for browser-friendly md++ bundles.

<!-- BEGIN mdpp-office-pipeline-update-v0-15: plugin-catalog -->

## 7. Office import and presentation helper plugins

| Plugin id | Capability | Input | Output | Purpose |
|---|---|---|---|---|
| `document.mdpp.comment-sidecar` | `mdpp.comment-sidecar@1` | sidecar resource | `mdpp.comment-sidecar` | Represent imported comments, review notes, speaker notes, and traceability metadata. |
| `import.office.openxml` | `import.office@1` | `office.docx`, `office.pptx` | `mdpp.source`, `mdpp.comment-sidecar`, diagnostics | Convert DOCX/PPTX into semantic md++ with lossy-import diagnostics. |
| `presentation.theme-classes` | `mdpp.presentation@1` | theme resource | presentation context | Resolve `## class`, `## component`, and `## page-furniture` declarations. |

The importer should prefer semantic Markdown/md++ output over full Office object-model fidelity. Unsupported source features should produce `MDPP0700`-range diagnostics and, when useful, static assets or placeholders.

Optional Office-normalization plugins for a reference implementation:

```text
document.mdpp.comment-sidecar
import.office.openxml
presentation.theme-classes
```

<!-- END mdpp-office-pipeline-update-v0-15: plugin-catalog -->
