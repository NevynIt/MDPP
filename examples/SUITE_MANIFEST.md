# md++ v0.14 Example Manifest

This manifest turns the spec and the proposed compliance list into concrete source-fixture drafting guidance.

## Drafting rules

- Keep fixtures minimal. Add only the source needed to prove the target behavior.
- Prefer `.mdpp` for the main file and `.md`, `.css`, `.svg` for supporting resources where appropriate.
- Use deterministic content and simple wording.
- When a scenario is diagnostic-only, keep the rest of the document valid.
- Preserve source order for repeated directives.
- Repository examples should keep repository content under `shared/` inside the example directory.
- Include examples should use relative paths that make the intended resolution rule obvious.
- Layout, theme, and stylesheet examples should use small readable resources rather than large integrated documents.

## Diagnostic code hints

- Invalid requirement syntax or mixed `@` and title range: `MDPP0100` or `MDPP0103`
- Missing required capability: `MDPP0102`
- Unknown repository in requirement: `MDPP0104`
- Missing include: `MDPP0200`
- Circular include: `MDPP0201`
- Duplicate repository, different target: `MDPP0204`
- Repository escape above root: `MDPP0206`
- Resource denied/failure/reference error: `MDPP0207`, `MDPP0208`, `MDPP0209`
- Invalid fenced info string: `MDPP0300`
- Duplicate model: `MDPP0301`
- Model parse failure: `MDPP0302`
- Plugin render failure or missing model render target: `MDPP0304`
- Invalid stylesheet/theme/layout: `MDPP0400`, `MDPP0401`, `MDPP0402`
- Unknown layout or area class: `MDPP0403`, `MDPP0404`
- Missing grid area declaration: `MDPP0405`
- Non-rectangular repeated area: `MDPP0406`
- Invalid track size: `MDPP0407`
- Overflow with `flow: none`: `MDPP0408`
- Invalid flow target or cycle: `MDPP0409`, `MDPP0410`
- Unsupported area renderer: `MDPP0411`
- Unknown token reference: `MDPP0412`

## Fixture list

1. `01-plain-gfm-document`: ordinary Markdown only; no md++ directives.
2. `02-profile-only-document`: metadata directives only; directives should not render visibly.
3. `03-directive-value-forms`: bare destination, angle-bracket destination, one quoted title, plus a few invalid directive lines.
4. `04-repeated-directives`: repeated `md:require`, `md:stylesheet`, `md:theme` in source order.
5. `05-requirement-parsing`: valid requirement forms and one invalid mixed `@` plus title range.
6. `06-repository-scoped-requirements`: `shared:` scoped requirements before and after repository declaration.
7. `07-unknown-repository-requirement`: missing repository-scoped requirement.
8. `08-missing-capability`: nonexistent capability requirement.
9. `09-attribute-list-basics`: headings with id, class, and key/value attributes.
10. `10-duplicate-explicit-anchors`: duplicate heading anchors.
11. `11-fenced-info-string-grammar`: valid keys, quoted values, flags, preserved order.
12. `12-invalid-fenced-info-strings`: malformed fenced attributes.
13. `13-normal-code-block-rendering`: known and unknown languages as ordinary code blocks.
14. `14-syntax-highlighting-fallback`: highlighter requirement plus known/unknown language fallback source.
15. `15-inline-and-block-math`: inline math and display math.
16. `16-mermaid-diagram-block`: plain Mermaid fenced block.
17. `17-plain-dot-block`: ordinary DOT block without `model=`.
18. `18-dot-model-absorption`: DOT model block that should register and disappear from normal rendering.
19. `19-model-parse-failure`: invalid DOT with `model=bad`.
20. `20-duplicate-model-names`: duplicate `model=system`.
21. `21-model-render-block`: DOT model plus `diagram.dot.render source=...`.
22. `22-render-missing-model`: render block referencing unknown model.
23. `23-simple-include`: include a sibling file.
24. `24-nested-relative-include`: included file includes another relative file.
25. `25-repository-qualified-include`: `shared:` repository include.
26. `26-repository-local-relative-references`: included repository file references a sibling stylesheet.
27. `27-repository-path-normalization`: repository include with `../` normalization.
28. `28-repository-escape-error`: repository path that escapes above root.
29. `29-circular-include`: two files that include each other.
30. `30-missing-include`: include target absent.
31. `31-repeated-repository-same-target`: same repository name and same canonical target twice.
32. `32-duplicate-repository-different-target`: same repository name with different targets.
33. `33-included-metadata-scope`: included file has its own title metadata.
34. `34-included-requirements-accumulation`: requirements from root and included files.
35. `35-included-model-availability`: model declared in included file and rendered in root.
36. `36-duplicate-model-across-include-boundary`: duplicate model names across root and include.
37. `37-plugin-resource-request-relative`: render block plus local resource path payload.
38. `38-plugin-resource-request-repository-qualified`: render block plus `shared:` resource path payload.
39. `39-plugin-resource-denied`: resource request shaped to require host denial handling.
40. `40-stylesheet-directive`: valid stylesheet directive and local CSS file.
41. `41-missing-stylesheet`: stylesheet target absent.
42. `42-unsafe-stylesheet`: stylesheet with `@import` and script-like patterns for sanitization/rejection.
43. `43-simple-theme-resource`: theme file with token sections.
44. `44-theme-references-layout-and-css`: theme file that declares local layout and stylesheet resources.
45. `45-theme-token-css-variables`: theme tokens for colors and spacing.
46. `46-token-references-in-layout`: layout using `{spacing.large}` style references.
47. `47-unknown-token-reference`: layout referencing missing token.
48. `48-multiple-themes-override`: base theme then override theme in order.
49. `49-document-overrides-theme-layout-style`: document-level layout and stylesheet after theme-level ones.
50. `50-minimal-layout-resource`: smallest valid layout resource.
51. `51-canvas-property-variants`: several layout files covering canvas-size and padding variants.
52. `52-grid-merged-rectangle`: valid repeated rectangular area.
53. `53-non-rectangular-grid-area`: invalid L-shaped area.
54. `54-invalid-track-size`: invalid row or column size.
55. `55-area-declaration-for-missing-area`: declaration for an area not present in grid.
56. `56-unknown-area-class-in-document`: content uses an area class not in the active layout.
57. `57-simple-page-slide-binding`: headings with layout and area classes.
58. `58-html-root-contract`: minimal md++ document suitable for HTML root contract assertions.
59. `59-semantic-html-mapping`: common Markdown constructs in one document.
60. `60-page-containers-and-areas`: page/area binding example for page model assertions.
61. `61-flow-none-overflow`: tiny layout with `flow: none`.
62. `62-same-page-flow`: `left` flows into `right`.
63. `63-next-page-flow`: `body` flows to `>body`.
64. `64-multi-step-flow`: `left -> right -> >left`.
65. `65-invalid-flow-target`: flow to missing area.
66. `66-unresolvable-flow-cycle`: cycle between areas.
67. `67-unsupported-area-renderer`: area with unknown renderer.
68. `68-plugin-defaults-from-theme`: theme `## plugin diagram.dot.render` defaults plus render block.
69. `69-block-attributes-override-plugin-defaults`: render block overrides theme plugin defaults.
70. `70-complete-minimal-document`: integrated example using profile, requirements, repository, theme, layout, include, math, Mermaid, DOT model, DOT render, stylesheet, and page layout.
