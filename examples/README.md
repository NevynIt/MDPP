# md++ Example Suite

This folder contains hand-authored `md++ v0.14` source fixtures derived from:

- [specs/mdpp_language_spec_v0_14.md](/C:/Stuff/MDPP/specs/mdpp_language_spec_v0_14.md)
- [specs/mdpp_diagnostic_catalog_v0_14.md](/C:/Stuff/MDPP/specs/mdpp_diagnostic_catalog_v0_14.md)
- [implementation/mdpp_reference_plugin_catalog_v0_14.md](/C:/Stuff/MDPP/implementation/mdpp_reference_plugin_catalog_v0_14.md)

The suite is intentionally source-focused. Each example directory contains the md++ inputs needed to exercise one compliance scenario. Expected resolved artifacts are not included yet.

## Conventions

- Example folders use `NN-short-name`.
- The main source file is `root.mdpp`.
- Supporting files are local to the example directory unless the scenario is explicitly about repositories.
- Examples that need repository-qualified resources use a local `shared/` subtree inside the example directory.
- Examples that are meant to produce diagnostics include invalid source on purpose.

## Minimum proof plugins

The suite assumes only the minimum proof plugins discussed in the proposal:

- `math.latex`
- `diagram.mermaid`
- `model.dot`
- `diagram.dot.render`
- `layout.grid`
- `highlight.*`

Everything else should remain core-host behavior.
