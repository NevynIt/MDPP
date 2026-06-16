# md++ Draft 0.14 Bundle

This bundle contains the md++ language spec, reference runtime architecture, diagnostic catalog, artifact schema skeleton, reference implementation planning documents, and compliance-oriented source examples.

## Folder structure

```text
MDPP/
  README.md
  RELEASE_NOTES_v0_14.md
  specs/
    mdpp_language_spec_v0_14.md
    mdpp_reference_runtime_architecture_v0_14.md
    mdpp_diagnostic_catalog_v0_14.md
  schemas/
    mdpp_artifact_schemas_v0_14.schema.json
  implementation/
    mdpp_reference_plugin_catalog_v0_14.md
    mdpp_reference_components_v0_14.md
    mdpp_application_profiles_v0_14.md
    mdpp_implementation_roadmap_v0_14.md
  examples/
    README.md
    SUITE_MANIFEST.md
    01-plain-gfm-document/
    ...
    70-complete-minimal-document/
```

## Reading order

1. `specs/mdpp_language_spec_v0_14.md`
2. `specs/mdpp_reference_runtime_architecture_v0_14.md`
3. `specs/mdpp_diagnostic_catalog_v0_14.md`
4. `schemas/mdpp_artifact_schemas_v0_14.schema.json`
5. `implementation/mdpp_reference_plugin_catalog_v0_14.md`
6. `implementation/mdpp_reference_components_v0_14.md`
7. `implementation/mdpp_application_profiles_v0_14.md`
8. `implementation/mdpp_implementation_roadmap_v0_14.md`
9. `examples/README.md`
10. `examples/SUITE_MANIFEST.md`

## Implementation targets

The implementation documents are organized around three targets:

- Node.js CLI for HTML/PDF export;
- React-compatible viewer that can run from `file://` using supplied resources or bundles;
- future visual editor, currently treated as experimental.
