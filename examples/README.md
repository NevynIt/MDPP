# md++ Example Suite

This folder contains hand-authored `md++ v0.14` source fixtures derived from:

- [`../specs/mdpp_language_spec_v0_14.md`](../specs/mdpp_language_spec_v0_14.md)
- [`../specs/mdpp_diagnostic_catalog_v0_14.md`](../specs/mdpp_diagnostic_catalog_v0_14.md)
- [`../implementation/mdpp_reference_plugin_catalog_v0_14.md`](../implementation/mdpp_reference_plugin_catalog_v0_14.md)

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
