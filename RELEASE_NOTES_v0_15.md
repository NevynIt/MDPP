# md++ Release Bundle 0.15

This bundle carries forward the draft 0.14 language/runtime specifications as draft 0.15 and adds theme composition, Office import profile alignment, and reference implementation planning updates.

## Included documents

### Specs

- `specs/mdpp_language_spec_v0_15.md`
- `specs/mdpp_reference_runtime_architecture_v0_15.md`
- `specs/mdpp_diagnostic_catalog_v0_15.md`

### Schemas

- `schemas/mdpp_artifact_schemas_v0_15.schema.json`

### Implementation planning

- `implementation/mdpp_reference_plugin_catalog_v0_15.md`
- `implementation/mdpp_reference_components_v0_15.md`
- `implementation/mdpp_application_profiles_v0_15.md`
- `implementation/mdpp_implementation_roadmap_v0_15.md`

## Main additions in 0.15

- internal profile version updated to `0.15` across the bundle;
- theme-level `[md:include]` composition in theme context;
- repeated-theme override clarification, including latest `default-template` wins;
- reference plugin catalog, component/module breakdown, app-specific profiles, and roadmap updates;
- compliance-oriented example suite with expected returns and diagnostic codes.

<!-- BEGIN mdpp-office-pipeline-update-v0-15: release-notes -->

## Additive Office-normalization update

This update extends the draft with:

- richer theme files using token groups, `## class`, `## component`, and `## page-furniture` declarations;
- page furniture for headers, footers, and page numbers;
- Office-like import guidance for DOCX/PPTX -> md++ normalization;
- sidecar conventions for imported comments and review metadata;
- diagnostic codes `MDPP0413`-`MDPP0418` and `MDPP0700`-`MDPP0705`;
- compliance fixtures `71` through `77`.

The DOCX importer and Word exporter prototypes now emit md++ 0.15 roots and root-adjacent sidecars such as `root.md.comments.json` and `root.md.import.json`.

Theme composition coverage is represented by compliance fixture `78`.

<!-- END mdpp-office-pipeline-update-v0-15: release-notes -->
