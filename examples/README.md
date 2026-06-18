# md++ Example Suite

This folder contains hand-authored `md++ v0.15` source fixtures derived from:

- [`../specs/mdpp_language_spec_v0_15.md`](../specs/mdpp_language_spec_v0_15.md)
- [`../specs/mdpp_diagnostic_catalog_v0_15.md`](../specs/mdpp_diagnostic_catalog_v0_15.md)
- [`../implementation/mdpp_reference_plugin_catalog_v0_15.md`](../implementation/mdpp_reference_plugin_catalog_v0_15.md)

The suite is source-focused. Each example directory contains the md++ inputs needed to exercise one compliance scenario. Expected behavior and diagnostics are listed in [`SUITE_MANIFEST.md`](SUITE_MANIFEST.md).

## Conventions

- Example folders use `NN-short-name`.
- The main source file is `root.md`.
- Supporting files are local to the example directory unless the scenario is explicitly about repositories.
- Examples that need repository-qualified resources use a local `shared/` subtree inside the example directory.
- Examples that are meant to produce diagnostics include invalid source on purpose.

## Minimum proof plugins

The suite assumes only the minimum proof plugins needed by the fixtures:

- `include`
- `resource`
- `math.latex`
- `diagram.mermaid`
- `model.dot`
- `diagram.dot`
- `diagram.dot.render`
- `highlight.prism` or `highlight.core`
- `layout.markdown.sections`
- `layout.flow`
- `area.flow`

Everything else should remain core-host behavior.

<!-- BEGIN mdpp-office-pipeline-update-v0-15: examples-readme -->

## Office-normalization fixtures

Examples `71` through `77` cover richer theme declarations, page furniture, and normalized Office-like import output. Examples `75` through `77` describe already-imported md++ output and the diagnostics an Office-like importer should have produced. They do not require DOCX/PPTX binary fixtures.

<!-- END mdpp-office-pipeline-update-v0-15: examples-readme -->

## Theme-composition fixtures

Example `78` covers v0.15 theme-level `[md:include]` composition. Included files are parsed in theme context and contribute declarations to the including theme at their include positions.

## External-model fixtures

Examples `79` through `86` cover v0.15 external model resources declared with `[md:model:NAME]: RESOURCE "INFO-STRING"`. They exercise successful resource-backed registration, invalid directive titles, invalid info strings, unsupported parser selectors, parser selection failure, resource parse failure, duplicate names, and missing model resources.
