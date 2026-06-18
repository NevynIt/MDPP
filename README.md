# md++ Draft 0.15 Bundle

This bundle contains the md++ language spec, reference runtime architecture, diagnostic catalog, artifact schema skeleton, Office import profile, reference implementation planning documents, and compliance-oriented source examples.

## Folder structure

```text
MDPP/
  README.md
  RELEASE_NOTES_v0_15.md
  specs/
    mdpp_language_spec_v0_15.md
    mdpp_reference_runtime_architecture_v0_15.md
    mdpp_diagnostic_catalog_v0_15.md
    mdpp_office_import_profile_v0_15.md
  schemas/
    mdpp_artifact_schemas_v0_15.schema.json
  implementation/
    mdpp_reference_plugin_catalog_v0_15.md
    mdpp_reference_components_v0_15.md
    mdpp_application_profiles_v0_15.md
    mdpp_implementation_roadmap_v0_15.md
  examples/
    README.md
    SUITE_MANIFEST.md
    01-plain-gfm-document/
    ...
    70-complete-minimal-document/
```

## Reading order

1. `specs/mdpp_language_spec_v0_15.md`
2. `specs/mdpp_reference_runtime_architecture_v0_15.md`
3. `specs/mdpp_diagnostic_catalog_v0_15.md`
4. `specs/mdpp_office_import_profile_v0_15.md`
5. `schemas/mdpp_artifact_schemas_v0_15.schema.json`
6. `implementation/mdpp_reference_plugin_catalog_v0_15.md`
7. `implementation/mdpp_reference_components_v0_15.md`
8. `implementation/mdpp_application_profiles_v0_15.md`
9. `implementation/mdpp_implementation_roadmap_v0_15.md`
10. `examples/README.md`
11. `examples/SUITE_MANIFEST.md`

## Implementation targets

The implementation documents are organized around three targets:

- Node.js CLI for HTML/PDF export;
- React-compatible viewer that can run from `file://` using supplied resources or bundles;
- future visual editor, currently treated as experimental.

<!-- BEGIN mdpp-office-pipeline-update-v0-15: readme -->

## Office import and richer theme update

The bundle also includes an additive Office-normalization profile:

- richer theme declarations for author-facing classes, components, and page furniture;
- theme-level `[md:include]` composition for theme fragments;
- page-furniture conventions for headers, footers, and page numbers;
- Office-like DOCX/PPTX normalization into text-editable md++;
- v0.15 sidecar naming guidance for imported comments, review metadata, and import diagnostics;
- stable diagnostic codes for page furniture and lossy import cases;
- compliance examples `71` through `78`.

<!-- END mdpp-office-pipeline-update-v0-15: readme -->
