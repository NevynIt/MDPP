# md++ v0.15 Example Manifest

This manifest turns the language spec, diagnostic catalog, and compliance scenarios into concrete source fixtures.

## Drafting rules

- Keep fixtures minimal. Add only the source needed to prove the target behavior.
- Prefer `.md` for the main file and `.md`, `.css`, `.svg` for supporting resources where appropriate.
- Use deterministic content and simple wording.
- When a scenario is diagnostic-only, keep the rest of the document valid.
- Preserve source order for repeated directives.
- Repository examples keep repository content under `shared/` inside the example directory.
- Include examples use relative paths that make the intended resolution rule obvious.
- Layout, theme, and stylesheet examples use small readable resources rather than large integrated documents.

## Diagnostic code hints

- Invalid directive syntax: `MDPP0004`
- Duplicate explicit anchor: `MDPP0006`
- Invalid requirement syntax or mixed `@` and title range: `MDPP0100` or `MDPP0103`
- Missing required capability: `MDPP0102`
- Unknown repository in requirement: `MDPP0104`
- Missing include: `MDPP0200`
- Circular include: `MDPP0201`
- Repeated repository, same target: `MDPP0203`
- Duplicate repository, different target: `MDPP0204`
- Repository escape above root: `MDPP0206`
- Resource denied/failure/reference error: `MDPP0207`, `MDPP0208`, `MDPP0209`
- Invalid fenced info string: `MDPP0300`
- Duplicate model: `MDPP0301`
- Model parse failure: `MDPP0302`
- Plugin render failure or missing model render target: `MDPP0304`
- External model directive/info/parser issues: `MDPP0305`, `MDPP0306`, `MDPP0307`, `MDPP0308`, `MDPP0309`
- Invalid stylesheet/theme/layout: `MDPP0400`, `MDPP0401`, `MDPP0402`
- Unknown layout or area class: `MDPP0403`, `MDPP0404`
- Area declaration for missing grid area: `MDPP0405`
- Non-rectangular repeated area: `MDPP0406`
- Invalid track size: `MDPP0407`
- Overflow with `flow: none`: `MDPP0408`
- Invalid flow target or cycle: `MDPP0409`, `MDPP0410`
- Unsupported area renderer: `MDPP0411`
- Unknown token reference: `MDPP0412`
- Theme class/component/page-furniture issues: `MDPP0414`, `MDPP0415`, `MDPP0416`, `MDPP0417`, `MDPP0418`
- Lossy Office-like import: `MDPP0700`, `MDPP0703`, `MDPP0704`
- Imported style/comment mapping: `MDPP0701`, `MDPP0702`
- Import sidecar resolution or anchoring: `MDPP0705`

## Fixture expectations

| # | Fixture | Expected return | Expected diagnostics |
|---:|---|---|---|
| 1 | `01-plain-gfm-document` | Renders as ordinary GFM Markdown: heading, paragraph, image, list, table, quote, and code block. | none |
| 2 | `02-profile-only-document` | Collects profile, version, title, and status metadata; directives do not render visibly. | none |
| 3 | `03-directive-value-forms` | Accepts bare, angle-bracket, and titled directive values; rejects the three malformed directives after the heading. | MDPP0004 ×3 |
| 4 | `04-repeated-directives` | Collects repeated requirements, stylesheets, and themes in source order. | none |
| 5 | `05-requirement-parsing` | Parses valid requirement selectors and reports the mixed `@` plus title range. | MDPP0103 |
| 6 | `06-repository-scoped-requirements` | Resolves repository-scoped requirements whether they appear before or after the repository declaration. | none |
| 7 | `07-unknown-repository-requirement` | Reports a requirement scoped to an undeclared repository. | MDPP0104 |
| 8 | `08-missing-capability` | Reports that the requested capability has no provider in the proof environment. | MDPP0102 |
| 9 | `09-attribute-list-basics` | Preserves explicit anchors, classes, and key/value attributes on headings. | none |
| 10 | `10-duplicate-explicit-anchors` | Reports the second use of the same explicit anchor. | MDPP0006 |
| 11 | `11-fenced-info-string-grammar` | Parses valid fenced block types, key/value attributes, quoted values, flags, and order. | none |
| 12 | `12-invalid-fenced-info-strings` | Rejects malformed fenced block info strings. | MDPP0300 ×3 |
| 13 | `13-normal-code-block-rendering` | Renders known and unknown code fences as ordinary visible code blocks. | none |
| 14 | `14-syntax-highlighting-fallback` | Highlights supported code and keeps the unknown language fence visible as fallback source. | none |
| 15 | `15-inline-and-block-math` | Renders inline and display math through the math plugin, or shows source in fallback mode. | none |
| 16 | `16-mermaid-diagram-block` | Renders a Mermaid diagram block. | none |
| 17 | `17-plain-dot-block` | Renders or displays a normal DOT block without registering a model. | none |
| 18 | `18-dot-model-absorption` | Registers the DOT model and absorbs the model block from normal rendering. | none |
| 19 | `19-model-parse-failure` | Reports invalid DOT in a model block and leaves useful source visible. | MDPP0302 |
| 20 | `20-duplicate-model-names` | Reports the duplicate model name in the resolved model repository. | MDPP0301 |
| 21 | `21-model-render-block` | Registers a DOT model and renders it through `diagram.dot.render`. | none |
| 22 | `22-render-missing-model` | Reports that the render block references a missing model. | MDPP0304 |
| 23 | `23-simple-include` | Includes the sibling Markdown file at the directive position. | none |
| 24 | `24-nested-relative-include` | Includes `parent.md`, then resolves its nested include relative to `parent.md`. | none |
| 25 | `25-repository-qualified-include` | Resolves and includes `shared:chapters/intro.md`. | none |
| 26 | `26-repository-local-relative-references` | Includes repository content and resolves its stylesheet relative to the included file. | none |
| 27 | `27-repository-path-normalization` | Normalizes `shared:chapters/../intro.md` to `shared:intro.md` and includes it. | none |
| 28 | `28-repository-escape-error` | Rejects a repository-qualified path that escapes above the repository root. | MDPP0206 |
| 29 | `29-circular-include` | Detects the include cycle between `a.md` and `b.md`. | MDPP0201 |
| 30 | `30-missing-include` | Reports the absent include target. | MDPP0200 |
| 31 | `31-repeated-repository-same-target` | Reports the redundant repository declaration with the same canonical target. | MDPP0203 |
| 32 | `32-duplicate-repository-different-target` | Reports the duplicate repository name with a different target. | MDPP0204 |
| 33 | `33-included-metadata-scope` | Includes content while keeping included metadata scoped to the included source file. | none |
| 34 | `34-included-requirements-accumulation` | Accumulates requirements from the root and included file in resolved source order. | none |
| 35 | `35-included-model-availability` | Registers a model from an included file and renders it from the root. | none |
| 36 | `36-duplicate-model-across-include-boundary` | Reports duplicate model names after include resolution. | MDPP0301 |
| 37 | `37-plugin-resource-request-relative` | Renders a DOT model while resolving the plugin stylesheet request relative to the block source. | none |
| 38 | `38-plugin-resource-request-repository-qualified` | Renders a DOT model while resolving the plugin stylesheet request through `shared:`. | none |
| 39 | `39-plugin-resource-denied` | Reports a host policy denial for a remote plugin stylesheet request. | MDPP0208 |
| 40 | `40-stylesheet-directive` | Loads and applies a local CSS stylesheet. | none |
| 41 | `41-missing-stylesheet` | Reports that the stylesheet resource cannot be loaded. | MDPP0401 |
| 42 | `42-unsafe-stylesheet` | Reports rejection or sanitization of unsafe stylesheet features. | MDPP0401 |
| 43 | `43-simple-theme-resource` | Loads a theme resource and exposes its token sections. | none |
| 44 | `44-theme-references-layout-and-css` | Loads a theme that in turn references a local layout and stylesheet. | none |
| 45 | `45-theme-token-css-variables` | Maps theme tokens to canonical CSS custom properties. | none |
| 46 | `46-token-references-in-layout` | Resolves `{spacing.*}` token references inside layout properties. | none |
| 47 | `47-unknown-token-reference` | Reports the unresolved `{spacing.large}` token used by the layout. | MDPP0412 |
| 48 | `48-multiple-themes-override` | Applies themes in order, with later token values overriding earlier ones. | none |
| 49 | `49-document-overrides-theme-layout-style` | Applies document-level layout and stylesheet after theme-level defaults. | none |
| 50 | `50-minimal-layout-resource` | Loads the smallest valid layout resource with one body area. | none |
| 51 | `51-canvas-property-variants` | Loads several valid canvas size, orientation, padding, and gap variants. | none |
| 52 | `52-grid-merged-rectangle` | Accepts a repeated rectangular grid area. | none |
| 53 | `53-non-rectangular-grid-area` | Reports an L-shaped repeated grid area. | MDPP0406 |
| 54 | `54-invalid-track-size` | Reports the invalid grid track size. | MDPP0407 |
| 55 | `55-area-declaration-for-missing-area` | Reports an area declaration that does not exist in the grid. | MDPP0405 |
| 56 | `56-unknown-area-class-in-document` | Reports document content targeting an area not declared by the active layout. | MDPP0404 |
| 57 | `57-simple-page-slide-binding` | Binds a slide section to a layout and two child sections to `left` and `right` areas. | none |
| 58 | `58-html-root-contract` | Produces an `.mdpp-document` root suitable for HTML contract assertions. | none |
| 59 | `59-semantic-html-mapping` | Maps common Markdown constructs to predictable semantic HTML elements/classes. | none |
| 60 | `60-page-containers-and-areas` | Produces page and area containers for a report layout. | none |
| 61 | `61-flow-none-overflow` | Reports overflow in a tiny fixed area with `flow: none`. | MDPP0408 |
| 62 | `62-same-page-flow` | Continues overflow from `left` into `right` on the same page when needed. | none |
| 63 | `63-next-page-flow` | Continues body overflow into `body` on the next generated page when needed. | none |
| 64 | `64-multi-step-flow` | Applies `left -> right -> >left` multi-step flow when needed. | none |
| 65 | `65-invalid-flow-target` | Reports a flow target that does not name a layout area. | MDPP0409 |
| 66 | `66-unresolvable-flow-cycle` | Reports the same-page cycle between `left` and `right`. | MDPP0410 |
| 67 | `67-unsupported-area-renderer` | Reports an area renderer unavailable in the proof environment. | MDPP0411 |
| 68 | `68-plugin-defaults-from-theme` | Passes theme-provided defaults to the DOT render plugin. | none |
| 69 | `69-block-attributes-override-plugin-defaults` | Uses block attributes to override theme-provided plugin defaults. | none |
| 70 | `70-complete-minimal-document` | Resolves the integrated document: requirements, repository, theme, layout, stylesheet, include, math, Mermaid, external DOT model, DOT render, and page layout. | none |
| 71 | `71-theme-class-declarations` | Applies theme-defined class declarations to author-facing classes. | none |
| 72 | `72-theme-component-declarations` | Applies theme-defined component defaults to tables and figures. | none |
| 73 | `73-page-furniture-report-layout` | Applies layout-selected report page furniture for headers, footers, and page numbers. | none |
| 74 | `74-unknown-page-furniture-diagnostic` | Reports a layout selecting a page-furniture profile that the active theme does not define. | MDPP0416 |
| 75 | `75-office-import-style-classes` | Shows Word/PPT-style named styles normalized into md++ classes. | MDPP0701 ×2 |
| 76 | `76-office-comments-sidecar` | Keeps imported comments in a sidecar file targeted at anchors in the main document. | MDPP0702 |
| 77 | `77-lossy-office-import-diagnostics` | Reports lossy import cases for freeform positioning, embedded objects, and precise pagination. | MDPP0700, MDPP0703, MDPP0704 |
| 78 | `78-theme-include-composition` | Resolves theme-level includes in theme context and applies included tokens, formatting templates, and plugin defaults at the include positions. | none |
| 79 | `79-external-model-resource` | Registers a DOT model from a repository-qualified external resource and renders it through `diagram.dot.render`. | none |
| 80 | `80-invalid-external-model-directive` | Reports an external model directive whose title tries to supply `model=...`. | MDPP0305 |
| 81 | `81-invalid-external-model-info-string` | Reports malformed info-string syntax in an external model directive title. | MDPP0306 |
| 82 | `82-unsupported-external-model-parser` | Reports an external model parser selector that no proof parser claims. | MDPP0307 |
| 83 | `83-external-model-selection-failed` | Reports failed parser selection when an external model directive has no title and no useful resource metadata. | MDPP0308 |
| 84 | `84-external-model-parse-failure` | Reports parse failure after resolving an external DOT model resource. | MDPP0309 |
| 85 | `85-duplicate-external-model-name` | Reports a duplicate model name across an external model directive and an inline model block. | MDPP0301 |
| 86 | `86-missing-external-model-resource` | Reports that an external model resource cannot be fetched. | MDPP0207 |
