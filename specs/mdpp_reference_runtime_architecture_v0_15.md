# md++ Reference Runtime Architecture

[md:profile]: md++
[md:profile-version]: 0.15
[md:title]: <md++ Reference Runtime Architecture>
[md:status]: draft

Status: draft 0.15
Document type: Reference implementation architecture
Related language spec: `mdpp_language_spec_v0_15.md`

This document describes a recommended architecture for implementing md++ processors, renderers, editors, repositories, plugins, transformations, and interactive outputs.

Related documents:

- `mdpp_language_spec_v0_15.md`
- `mdpp_diagnostic_catalog_v0_15.md`
- `mdpp_artifact_schemas_v0_15.schema.json`
- `implementation/mdpp_reference_plugin_catalog_v0_15.md`
- `implementation/mdpp_reference_components_v0_15.md`
- `implementation/mdpp_application_profiles_v0_15.md`
- `implementation/mdpp_implementation_roadmap_v0_15.md`

The normative Markdown-compatible authoring profile is defined separately in `mdpp_language_spec_v0_15.md`.

---

## 1. Purpose and scope

The md++ language specification defines what authors can write and what portable md++ content means.

This reference runtime architecture defines one recommended way to implement a complete md++ ecosystem. It covers host responsibilities, typed document artifacts, document type providers, transformation providers, repository providers, plugins, renderer lifecycle, snapshots, patches, source maps, interactions, workers, and jobs.

The architecture is intended to guide interoperable implementations, but it should not make the md++ language itself depend on a specific application framework, package format, worker model, editor, DOM adapter, or repository backend.

### 1.1. Normative status and keywords

This document is a reference architecture, not the md++ language definition. It standardizes recommended runtime boundaries and exchange formats where interoperability matters.

The capitalized words MUST, MUST NOT, REQUIRED, SHOULD, SHOULD NOT, RECOMMENDED, MAY, and OPTIONAL are normative when they appear in this architecture. Lowercase uses of those words are ordinary prose.

Host-specific implementation choices remain allowed unless this architecture explicitly marks a runtime exchange behavior as REQUIRED for interoperability.

---

## 2. Runtime design principles

1. **The language remains Markdown-based**
   Runtime architecture must not add author-facing syntax that belongs outside the md++ language specification.

2. **The host owns policy**
   Resource access, plugin loading, persistence, remote fetching, unsafe HTML, stylesheets, fonts, interactions, workers, and jobs are governed by host policy.

3. **Plugins communicate through APIs, not ambient access**
   Portable plugins should not depend on direct filesystem, network, process, or live DOM access.

4. **Runtime exchange uses typed document artifacts**
   Hosts, repositories, renderers, and plugins exchange typed document artifacts plus structured diagnostics.

5. **Rendering is one transformation**
   The same architecture can support parsing, validation, import, export, analysis, publishing, and rendering.

6. **Worker boundaries use serializable data**
   Portable renderers and plugins exchange snapshots, patches, source maps, interactions, resources, plugin lists, state, and diagnostics as serializable objects.

7. **Plugin-specific behavior stays plugin-specific**
   The architecture defines dispatch points and exchange contracts. Specialized behavior such as area rendering, diagram rendering, model parsing, importers, exporters, and layout interpretation belongs to plugins or host-selected providers.

---

## 3. Core runtime and document artifact model

md++ defines a portable authoring profile, but practical hosts usually run a broader document-processing ecosystem around that profile.

The core runtime model is intentionally small:

- the host owns plugin selection, repository access, policy, workers, jobs, caches, and UI integration;
- repositories provide resources and, when allowed, persistence operations;
- document type providers define how typed documents are parsed, serialized, patched, validated, and exposed semantically;
- transformation providers convert typed input documents into typed output documents plus diagnostics;
- renderers are specialized transformation providers that produce render trees, patches, source maps, interaction bindings, dependency lists, and renderer state.

The portable core profile defines the concepts and exchange shapes. It does not define plugin packaging, installation, scheduler internals, cache policy, database schema, remote execution, or a full security model.

### 3.1. Host interface

The host is the authority that coordinates md++ processing.

A host may expose services equivalent to:

```typescript
interface MdHost {
  plugins: MdPluginRegistry;
  repositories: MdRepositoryRegistry;
  documentTypes: MdDocumentTypeRegistry;
  jobs: MdJobScheduler;
  policy?: MdHostPolicy;
}
```

This interface is conceptual. Portable plugins should normally receive the narrower `MdPluginHost` interface defined later in this specification, not unrestricted access to the full host.

The host decides whether work runs inline, in a worker, in a separate process, in a job queue, or through another host-managed execution mechanism. Portable plugins should expose asynchronous operations and should not require direct worker, process, network, filesystem, or live DOM access.

### 3.2. Document artifacts

A document artifact is a typed, metadata-bearing value exchanged between the host, repositories, renderers, and plugins.

A document artifact may represent source text, a resolved Markdown tree, a fenced block, a parsed model, a render tree, a DOM patch set, a source map, a diagnostic report, a stylesheet, a theme, a layout, an SVG document, an HTML fragment, a PDF, or any other document-like value used by the ecosystem.

Recommended base shape:

```typescript
interface MdDocument {
  id: string;
  type: string;
  version?: string;
  mediaType?: string;
  ref?: string;
  origin?: MdSourceOrigin;
  metadata?: Record<string, unknown>;
  content?: unknown;
  semantic?: unknown;
  diagnostics?: MdDiagnostic[];
  patches?: MdDocumentPatch[];
}

type MdDocumentPatch = unknown;
```

Fields:

| Field | Meaning |
|---|---|
| `id` | Host- or provider-assigned document artifact identifier |
| `type` | Stable document type identifier |
| `version` | Optional artifact version, schema version, or provider version |
| `mediaType` | Optional media type for serialization or repository storage |
| `ref` | Optional repository reference, URI, path, or host identifier |
| `origin` | Optional source origin for diagnostics and traceability |
| `metadata` | Extensible artifact metadata |
| `content` | Provider-owned concrete payload |
| `semantic` | Optional semantic representation exposed to other providers |
| `diagnostics` | Diagnostics directly associated with this artifact |
| `patches` | Optional changesets or patches associated with this artifact |

The `semantic` field is intended to reduce repeated parser and serializer work across plugins. A document type provider may expose semantic data such as an abstract syntax tree, symbol table, graph model, table model, layout tree, page model, or typed model object. Portable consumers must treat unsupported semantic shapes as opaque.

Diagnostics remain structured sidecar data even when they are also materialized as a diagnostic document artifact.

#### 3.2.1. Open standardization items

The base artifact shape is intentionally small in draft 0.15. The following details are TODOs for a later runtime release:

- artifact identifier stability across sessions;
- artifact version semantics;
- common patch formats for text, trees, binary resources, and semantic models;
- rules for when diagnostics attach to a document artifact versus a transformation result;
- conventions for serializing or caching `semantic` payloads;
- compatibility rules for document type schema evolution.

### 3.3. Common document types

The following type names are recommended for portable md++ ecosystems:

| Type | Meaning |
|---|---|
| `mdpp.source` | Markdown-compatible md++ source text |
| `mdpp.resolved-tree` | Resolved document tree after include composition |
| `mdpp.fenced-block` | Fenced block source, attributes, and origin |
| `mdpp.model` | Parsed named model artifact |
| `mdpp.model-repository` | Collection of resolved model artifacts |
| `mdpp.presentation-context` | Resolved theme, layout, stylesheet, token, asset, and plugin-default context |
| `mdpp.page-model` | Host-managed page, slide, area, flow, and pagination model |
| `mdpp.render-tree` | Serializable render tree using `MdNode` |
| `mdpp.dom-patch-set` | Serializable DOM patches using `MdPatch[]` |
| `mdpp.source-map` | Source mapping using `MdSourceMap` |
| `mdpp.interactions` | Interaction binding collection |
| `mdpp.diagnostics` | Diagnostic report document |
| `css.stylesheet` | CSS stylesheet resource |
| `theme.md` | Theme resource parsed in theme context |
| `layout.md` | Layout resource parsed in layout context |
| `svg.document` | SVG document or subtree |
| `html.fragment` | Sanitized or host-owned HTML fragment |
| `pdf.document` | PDF output document |

Hosts and plugins may define additional document types. Portable type names should use lowercase letters, digits, dots, and hyphens.

### 3.4. Document type providers

A document type provider owns one or more document types.

A provider may define:

- accepted media types and filename conventions;
- parse and serialize operations;
- validation rules;
- patch and changeset formats;
- semantic representations;
- preview or default rendering behavior;
- import and export mappings;
- diagnostics produced while handling the document type.

Recommended conceptual shape:

```typescript
interface MdDocumentTypeProvider {
  metadata: MdPluginMetadata;
  documentTypes: MdDocumentTypeMetadata[];
  parse?(request: MdDocumentParseRequest, host: MdPluginHost): Promise<MdDocumentResult>;
  serialize?(request: MdDocumentSerializeRequest, host: MdPluginHost): Promise<MdDocumentSerializeResult>;
  applyPatch?(request: MdDocumentPatchRequest, host: MdPluginHost): Promise<MdDocumentResult>;
  validateDocument?(request: MdDocumentValidationRequest, host: MdPluginHost): Promise<MdValidationResult>;
  getSemantic?(request: MdSemanticRequest, host: MdPluginHost): Promise<MdSemanticResult>;
}

interface MdDocumentTypeMetadata {
  type: string;
  version?: string;
  mediaTypes?: string[];
  fileExtensions?: string[];
}

interface MdDocumentResult {
  document?: MdDocument;
  diagnostics: MdDiagnostic[];
}

interface MdDocumentParseRequest {
  type?: string;
  mediaType?: string;
  ref?: string;
  text?: string;
  content?: ArrayBuffer;
  origin?: MdSourceOrigin;
}

interface MdDocumentSerializeRequest {
  document: MdDocument;
  mediaType?: string;
}

interface MdDocumentSerializeResult {
  text?: string;
  content?: ArrayBuffer;
  mediaType?: string;
  diagnostics: MdDiagnostic[];
}

interface MdDocumentPatchRequest {
  document: MdDocument;
  patches: MdDocumentPatch[];
}

interface MdDocumentValidationRequest {
  document: MdDocument;
}

interface MdSemanticRequest {
  document: MdDocument;
  selector?: string;
}

interface MdSemanticResult {
  semantic?: unknown;
  diagnostics: MdDiagnostic[];
}
```

The portable core does not require every provider to implement every operation. A provider may be read-only, parse-only, render-only, validation-only, or host-specific.

### 3.5. Transformation providers

A transformation provider consumes typed document artifacts and produces typed document artifacts.

Rendering is one transformation. Model parsing, validation, import, export, report generation, diagram layout, page pagination, and publishing are also transformations.

Recommended conceptual shape:

```typescript
interface MdTransformationProvider {
  metadata: MdPluginMetadata;
  canTransform(request: MdTransformCapabilityRequest, host: MdPluginHost): Promise<MdTransformCapabilityResult>;
  transform(request: MdTransformRequest, host: MdPluginHost): Promise<MdTransformResult>;
}

interface MdTransformCapabilityRequest {
  inputTypes: string[];
  outputType?: string;
  purpose?: string;
}

interface MdTransformCapabilityResult {
  accepted: boolean;
  outputTypes?: string[];
  diagnostics: MdDiagnostic[];
}

interface MdTransformRequest {
  inputs: MdDocument[];
  targetType?: string;
  context?: MdTransformContext;
}

interface MdTransformContext {
  presentation?: MdDocument;
  models?: MdDocument;
  options?: Record<string, unknown>;
  origin?: MdSourceOrigin;
}

interface MdTransformResult {
  documents: MdDocument[];
  diagnostics: MdDiagnostic[];
  resources?: MdUsedResource[];
  plugins?: MdUsedPlugin[];
}
```

A transformation may be deterministic and pure, or it may depend on host-provided resources, selected plugins, repository content, policy, or user interaction. Such dependencies should be reported through used resource and used plugin lists where practical.

### 3.6. Rendering as a specialized transformation

The renderer lifecycle defined later in this specification is a specialized transformation path.

Conceptually, an initial render is:

```text
mdpp.source + host context -> mdpp.render-tree + mdpp.source-map + mdpp.interactions + renderer state + diagnostics
```

A block renderer is:

```text
mdpp.fenced-block + mdpp.model-repository + mdpp.presentation-context -> mdpp.render-tree + diagnostics
```

A layout interpretation provider may treat a Markdown fragment, section, or resolved tree as input and produce a page model:

```text
mdpp.resolved-tree + mdpp.presentation-context + mdpp.layout -> mdpp.page-model + diagnostics
```

An area renderer may then render the content assigned to a specific layout area:

```text
mdpp.area-content + mdpp.presentation-context -> mdpp.render-tree + diagnostics
```

The language specification defines layout and area syntax. The runtime chooses the layout interpretation provider and area renderer plugins.

A model parser is:

```text
mdpp.fenced-block -> mdpp.model + diagnostics
```

An exporter may be:

```text
mdpp.render-tree + mdpp.page-model -> pdf.document
```

The specialized renderer API remains useful because interactive rendering needs renderer state, incremental update, source lookup, DOM patches, and interaction dispatch. Hosts may nevertheless expose the same work through a more general transformation registry.

### 3.7. Repository providers and persistence capabilities

Repository providers resolve repository roots and return host-managed repository instances.

A repository instance may support only read access, or it may support persistence operations when allowed by host policy.

Recommended capability names:

```typescript
type MdRepositoryCapability =
  | "read"
  | "write"
  | "create"
  | "delete"
  | "move"
  | "copy"
  | "list"
  | "metadata"
  | "watch"
  | "history"
  | "lock";
```

Recommended conceptual shape:

```typescript
interface MdRepository {
  id: string;
  name: string;
  root: string;
  canonicalRef?: string;
  providerId: string;
  capabilities: MdRepositoryCapability[];
  read(ref: string): Promise<MdResourceResponse>;
  write?(ref: string, document: MdDocument): Promise<MdResourceResponse>;
  create?(ref: string, document: MdDocument): Promise<MdResourceResponse>;
  list?(ref: string): Promise<MdRepositoryListResult>;
  move?(from: string, to: string): Promise<MdRepositoryOperationResult>;
  delete?(ref: string): Promise<MdRepositoryOperationResult>;
  metadata?(ref: string): Promise<MdRepositoryMetadataResult>;
  watch?(ref: string): Promise<MdRepositoryWatchResult>;
}

interface MdRepositoryEntry {
  ref: string;
  name?: string;
  kind: "file" | "folder" | "resource" | string;
  mediaType?: string;
  size?: number;
  modifiedAt?: string;
  metadata?: Record<string, unknown>;
}

interface MdRepositoryListResult {
  entries: MdRepositoryEntry[];
  diagnostics: MdDiagnostic[];
}

interface MdRepositoryOperationResult {
  diagnostics: MdDiagnostic[];
}

interface MdRepositoryMetadataResult {
  metadata?: Record<string, unknown>;
  diagnostics: MdDiagnostic[];
}

interface MdRepositoryWatchResult {
  subscriptionId?: string;
  diagnostics: MdDiagnostic[];
}
```

The portable core profile only requires read-like behavior for includes and plugin resources. Write, create, move, delete, list, watch, history, and locking are host capabilities and must remain subject to host policy.

### 3.8. Jobs, workers, and scheduling

Jobs are host-managed execution units for operations such as rendering, validation, transformation, import, export, publishing, repository synchronization, or long-running analysis.

Recommended conceptual shape:

```typescript
interface MdJobScheduler {
  submit(request: MdJobRequest): Promise<MdJobResult>;
}

interface MdJobRequest {
  kind: "render" | "transform" | "validate" | "import" | "export" | "repository" | string;
  inputs?: MdDocument[];
  targetType?: string;
  options?: Record<string, unknown>;
  origin?: MdSourceOrigin;
}

interface MdJobResult {
  documents?: MdDocument[];
  diagnostics: MdDiagnostic[];
  resources?: MdUsedResource[];
  plugins?: MdUsedPlugin[];
}
```

The portable spec does not require a background job protocol. A host may execute a job immediately and return the result, or may implement its own asynchronous scheduling outside the portable core profile.

Workers are an implementation detail of the host. A portable renderer or plugin may be worker-compatible, but should not require direct control over worker creation, message channels, or thread lifecycle.

#### 3.8.1. Portable worker IPC/RPC profile

For cross-language worker and process boundaries, a conforming reference implementation SHOULD expose runtime calls through JSON-RPC 2.0 message envelopes.

The REQUIRED envelope shape is:

```typescript
interface MdRpcRequest {
  jsonrpc: "2.0";
  id?: string | number;
  method: string;
  params?: unknown;
}

interface MdRpcSuccessResponse {
  jsonrpc: "2.0";
  id: string | number;
  result: unknown;
}

interface MdRpcErrorResponse {
  jsonrpc: "2.0";
  id?: string | number | null;
  error: {
    code: number;
    message: string;
    data?: unknown;
  };
}
```

Recommended transports:

| Transport | Framing |
|---|---|
| standard input/output | one UTF-8 JSON object per line |
| WebSocket | one JSON object per text frame |
| browser Worker `postMessage` | one structured-clone JSON-compatible object per message |
| in-process host call | same request and response objects without byte framing |

Recommended method names:

| Method | Params | Result |
|---|---|---|
| `mdpp.render` | `MdRenderDocumentRequest` | `MdRenderDocumentResult` |
| `mdpp.update` | `MdRenderUpdateRequest` | `MdRenderUpdateResult` |
| `mdpp.locateSource` | `MdSourceLocationRequest` | `MdSourceLocationResult` |
| `mdpp.handleInteraction` | `MdInteractionRequest` | `MdInteractionResult` |
| `mdpp.transform` | `MdTransformRequest` | `MdTransformResult` |
| `mdpp.validate` | `MdValidationRequest` | `MdValidationResult` |
| `mdpp.getResource` | `MdRepositoryResourceRequest` or host-defined resource request | `MdResourceResponse` |

Binary content SHOULD be exchanged by reference through repository/resource identifiers. When inline binary content is unavoidable, it SHOULD be base64 encoded in a JSON object that declares media type and encoding.

JSON-RPC errors describe transport or protocol failures. Ordinary authoring, parsing, rendering, security-denial, and validation problems SHOULD be returned as `MdDiagnostic` values in successful JSON-RPC responses.

### 3.9. Provider roles

A plugin may provide one or more roles:

| Role | Meaning |
|---|---|
| `repository-provider` | Resolves repository roots and provides repository access |
| `document-type-provider` | Owns parsing, serialization, validation, patching, and semantic access for document types |
| `transformation-provider` | Converts typed document artifacts into other typed document artifacts |
| `model-parser` | Parses model blocks into `mdpp.model` artifacts |
| `block-renderer` | Renders fenced blocks or plugin-owned blocks into `mdpp.render-tree` artifacts |
| `mdpp-renderer` | Renders a resolved md++ document into a render tree and related interactive artifacts |
| `layout-interpreter` | Maps resolved Markdown fragments, layouts, and presentation context into a page model |
| `area-renderer` | Renders content assigned to a layout area |
| `validator` | Produces diagnostics for documents, models, or render results |
| `stylesheet-processor` | Processes stylesheets or token-aware style resources |
| `interaction-runtime` | Handles authorized main-thread or worker-side interaction actions |
| `exporter` | Produces external output formats such as PDF, SVG, PNG, HTML, or package artifacts |
| `importer` | Converts external formats into md++ or other typed document artifacts |

These roles are descriptive. Capability resolution and dispatch remain host-controlled and deterministic.

---

---

## 4. Repository providers and resource access

### 4.1. Repository provider plugins

A repository root may be resolved by the host directly or by a repository provider plugin. This allows portable documents to use repository kinds that are not built into the core processor, such as Git repositories, package registries, artifact stores, workspace references, or organization-specific content services.

A repository provider participates in the runtime model defined in the core runtime and document artifact model. It resolves a repository root and may return a repository instance with capabilities such as read, write, create, move, list, metadata, or watch. The portable core profile only depends on read-like access for includes and plugin resources; persistence operations are optional host capabilities.

Repository provider plugins are ordinary md++ plugins that declare repository-related capabilities, for example:

```markdown
[md:require]: repository.git@^1
[md:repository:shared]: git:https://example.org/company/shared-mdpp.git
```

When a processor encounters an `[md:repository:*]:` directive, it asks available repository providers whether they can resolve the repository root. A provider that accepts the root returns a canonical resolved target and is registered as the content provider for that repository name. Later references such as `shared:icons/database.svg` are routed to the registered provider.

A host-provided filesystem or URL resolver is treated as a repository provider for priority purposes.

Repository provider selection uses this priority order:

| Priority | Selection source | Meaning |
|---|---|---|
| 1 | explicit host configuration | A user or host-selected provider for the repository name or root wins |
| 2 | explicit required capability | A provider satisfying a relevant `[md:require]: repository.*` capability is preferred |
| 3 | exact scheme or root-kind match | A provider that explicitly claims the root scheme, such as `git:` or `pkg:`, is preferred |
| 4 | built-in host provider | Host filesystem, HTTP, workspace, or package providers may resolve known roots |
| 5 | fallback failure | If no provider can resolve the root, the repository directive produces a diagnostic |

If multiple providers at the same priority can resolve the same repository root, the host must choose deterministically and should report an informational diagnostic identifying the selected provider. A host should report a warning or error if the ambiguity could change resolved content.

A repository provider must not bypass host policy. It receives repository resolution and resource requests through the host/plugin API, and the host may deny, sanitize, cache, trace, or audit the access according to its policy.

### 4.2. Repository canonicalization and path contract

Repository providers SHOULD return stable canonical references for resolved repository roots and resources.

Recommended canonical reference form:

```text
provider-id:repository-name:/normalized/path
```

Hosts MAY use provider-specific canonical forms when needed, but a canonical reference SHOULD be stable enough for diagnostics, dependency tracking, cache keys, and update invalidation.

Path contract for repository-qualified references:

1. Repository names are case-sensitive.
2. Portable paths use `/` as the separator.
3. The host normalizes `.` and `..` segments before calling the repository provider.
4. The host MUST reject repository-qualified paths that escape above the repository root.
5. The provider SHOULD receive normalized paths relative to the repository root.
6. Read failures MUST return an `MdResourceResponse` without `content` and with diagnostics.
7. Metadata SHOULD include media type, size, content hash, modified time when available, and provider-specific fields under `metadata`.
8. List operations SHOULD return entries sorted by normalized path unless the provider declares a different stable order.
9. Write, create, move, copy, delete, lock, and watch operations are OPTIONAL and remain subject to host policy.
10. Write conflicts SHOULD produce diagnostics rather than silently overwriting content. The exact conflict strategy is host-defined.

### 4.3. Plugin resource access

The host provides resource access to plugins during parsing and rendering.

A plugin may request a resource using the same repository-qualified reference form:

```text
repository-name:path/inside/repository.ext
```

For example:

```text
shared:icons/database.svg
corporate:themes/company.theme.md
```

The host resolves the repository name through the global repository table, calls the registered repository provider, applies its own access policy, fetches the content when allowed, and returns either a resource response or an error diagnostic to the plugin.

Relative resource requests should be resolved against the source file that contains the requesting block, unless the plugin or host defines a more specific base.

Plugins should not fetch external resources directly in portable md++ processing. The interaction boundary is the host resource API: plugins ask the host for a resource, and the host either provides it or returns a diagnostic according to host policy.

### 4.4. Resource response envelope

When the host returns a resource to a plugin, it should include a standard metadata envelope.

Recommended shape:

```typescript
interface MdResourceResponse {
  requestedRef: string;
  resolvedRef?: string;
  mediaType?: string;
  size?: number;
  hash?: {
    algorithm: string;
    value: string;
  };
  sourceOrigin?: {
    repository?: string;
    file?: string;
    line?: number;
  };
  diagnostics: MdDiagnostic[];
  content?: string | ArrayBuffer;
}
```

Fields:

| Field | Meaning |
|---|---|
| `requestedRef` | The exact reference requested by the plugin |
| `resolvedRef` | The resolved host reference, URI, path, or canonical identifier when available |
| `mediaType` | Media type such as `image/svg+xml`, `text/css`, or `application/json` when known |
| `size` | Resource size in bytes when known |
| `hash` | Content hash when available |
| `sourceOrigin` | Repository, file, or source location associated with the resource |
| `diagnostics` | Diagnostics produced while resolving or reading the resource |
| `content` | Resource content, omitted when unavailable or denied |

If a resource cannot be resolved, is denied by policy, or cannot be read, `content` is omitted and `diagnostics` describes the failure.

---

## 5. Renderer lifecycle, snapshots, patches, source maps, and interactions

### 5.1. Plugin output contract

A rendering plugin returns portable render output for the block position it owns.

Portable plugin results should not require access to live host DOM nodes. Suitable plugin results include:

- a serializable md++ render node subtree;
- a sanitized HTML fragment, when allowed by host policy;
- an inline or block `svg` subtree represented through the serializable node model;
- a table subtree;
- a rendered math subtree;
- a placeholder/error subtree with diagnostics;
- source-map entries for the generated output;
- interaction bindings for authorized user interactions.

The host sanitizes, scopes, inserts, measures, styles, maps, and binds plugin output according to its security and rendering policy.

In browser hosts, plugins intended for portable md++ rendering should be compatible with worker execution. They must not require direct filesystem, network, process, or live DOM access. Main-thread interaction is expressed through the interaction binding model defined in this runtime architecture.

### 5.2. Resource access during rendering

During rendering, plugins may request resources such as icons, templates, included model fragments, data files, fonts, stylesheets, or image assets.

The host resolves these requests through repository roots and file-relative paths, then returns a resource response envelope or a diagnostic.

### 5.3. Renderer lifecycle, worker boundary, and interaction contract

An md++ renderer is a stateful transformation provider that transforms an md++ entry source or resolved document artifact into a rendered representation and keeps enough state to support later updates, source mapping, and interaction.

The portable renderer contract is designed to work across worker, process, and thread boundaries. A portable renderer must not require access to live host DOM nodes, browser `Node` objects, or host-specific UI objects.

A renderer may use any internal representation, including a DOM-like tree, a virtual DOM, an incremental tree, direct string building, or a host-specific representation. This internal representation is not part of the portable contract.

Across the portable boundary, the renderer communicates using serializable objects and typed document artifacts:

- a render snapshot for initial mounting or full replacement;
- DOM patches for updates;
- source maps for DOM-to-source lookup;
- interaction bindings for event handling;
- an opaque renderer state object;
- used resource and plugin lists;
- diagnostics.

In browser hosts, the actual DOM is owned by the main UI thread. A host-side DOM adapter mounts render snapshots, applies DOM patches, binds events, dispatches interactions, and maps actual DOM elements to renderer node identifiers.

Recommended interface:

```typescript
interface MdRenderer {
  render(request: MdRenderDocumentRequest): Promise<MdRenderDocumentResult>;
  update(request: MdRenderUpdateRequest): Promise<MdRenderUpdateResult>;
  locateSource(request: MdSourceLocationRequest): Promise<MdSourceLocationResult>;
  handleInteraction?(request: MdInteractionRequest): Promise<MdInteractionResult>;
}
```

#### 5.3.1. Initial render

```typescript
interface MdRenderDocumentRequest {
  entry: MdResourceInput;
  context: MdRenderContext;
  options?: MdRenderOptions;
}

type MdResourceInput =
  | { kind: "ref"; ref: string }
  | { kind: "source"; ref?: string; text: string };

interface MdRenderDocumentResult {
  snapshot: MdNode;
  state: MdRendererState;
  resources: MdUsedResource[];
  plugins: MdUsedPlugin[];
  sourceMap: MdSourceMap;
  interactions?: MdInteractionBinding[];
  diagnostics: MdDiagnostic[];
}
```

`snapshot` is a serializable tree describing the rendered md++ output. It is the payload of an `mdpp.render-tree` document artifact. The host-side DOM adapter turns it into actual DOM or another host UI representation.

`state` is opaque to the host. The host stores it and passes it back to the renderer for later update, source-location, and worker-action operations.

`resources` records all external resources that contributed to the result, including included files, repository roots, themes, layouts, stylesheets, assets, fonts, plugin-requested resources, and repository-provided content.

`plugins` records all plugins selected or used during rendering.

`sourceMap` records mappings from renderer node identifiers to source ranges.

`interactions` records event bindings that the host-side DOM adapter should attach to mounted nodes.

#### 5.3.2. Render context

```typescript
interface MdRenderContext {
  resolvePlugin(request: MdPluginResolveRequest): Promise<MdPluginResolveResult>;
  getResource(ref: string, origin?: MdSourceOrigin): Promise<MdResourceResponse>;
  diagnostic(diagnostic: MdDiagnostic): void;
  policy?: MdHostPolicy;
}
```

The render context is host-defined, but portable renderers should only rely on plugin resolution, resource access, diagnostics, and policy information exposed through this contract.

#### 5.3.3. Serializable render tree

The render snapshot uses a deliberately small serializable node model.

```typescript
type MdNode = MdElementNode | MdTextNode;

interface MdElementNode {
  id: string;
  tag: string;
  attrs?: Record<string, string>;
  children?: MdNode[];
}

interface MdTextNode {
  id: string;
  text: string;
}
```

`id` values are renderer-owned node identifiers. They must be unique within the rendered result and stable enough to support updates, source mapping, and interaction dispatch for the lifetime of the renderer state.

Element nodes SHOULD include the predictable semantic elements and md++ classes defined by the md++ language specification. The host-side DOM adapter should preserve those elements and attributes when mounting into an HTML DOM.

The node model is the portable exchange format. Implementations may use richer internal node models, but those richer models must be lowered to this serializable form at the portable boundary.

#### 5.3.4. Renderer state

```typescript
interface MdRendererState {
  rendererId: string;
  rendererVersion: string;
  entryRef?: string;
  documentVersion?: string;
  opaque: unknown;
}
```

The `opaque` field is owned by the renderer. Hosts must not interpret it.

A renderer state should contain enough information to support:

- dependency tracking;
- plugin dispatch reuse;
- model repository reuse;
- source-to-node mapping;
- node-to-source mapping;
- interaction dispatch;
- incremental update when possible.

#### 5.3.5. Used resources and plugins

```typescript
interface MdUsedResource {
  requestedRef: string;
  resolvedRef?: string;
  role:
    | "entry"
    | "include"
    | "repository"
    | "theme"
    | "layout"
    | "stylesheet"
    | "asset"
    | "font"
    | "plugin-resource"
    | "model-source"
    | "other";
  mediaType?: string;
  hash?: MdContentHash;
  version?: string;
  providerId?: string;
  origin?: MdSourceOrigin;
}

interface MdUsedPlugin {
  id: string;
  version: string;
  capabilities: MdPluginCapability[];
  role:
    | "repository-provider"
    | "document-type-provider"
    | "transformation-provider"
    | "model-parser"
    | "block-renderer"
    | "mdpp-renderer"
    | "area-renderer"
    | "validator"
    | "stylesheet-processor"
    | "interaction-runtime"
    | "importer"
    | "exporter"
    | "other";
}
```

The returned resource and plugin lists describe the current rendered result. After an update, the newly returned lists replace the previous lists.

#### 5.3.6. Updating an existing mounted result

A renderer must support updating a previously rendered result using the state object returned by an earlier render.

The portable renderer does not receive the live DOM. It receives changed resources and returns serializable patches or a replacement snapshot. The host-side DOM adapter applies those changes to the mounted DOM.

```typescript
interface MdRenderUpdateRequest {
  state: MdRendererState;
  changes: MdResourceChange[];
  context: MdRenderContext;
  options?: MdRenderOptions;
}

type MdResourceChange =
  | MdWholeResourceChange
  | MdTextDiffResourceChange
  | MdBinaryResourceChange
  | MdDeletedResourceChange;

interface MdWholeResourceChange {
  kind: "whole";
  ref: string;
  text: string;
  hash?: MdContentHash;
}

interface MdTextDiffResourceChange {
  kind: "text-diff";
  ref: string;
  diff: MdTextDiff;
  resultingHash?: MdContentHash;
}

interface MdBinaryResourceChange {
  kind: "binary";
  ref: string;
  content: ArrayBuffer;
  hash?: MdContentHash;
}

interface MdDeletedResourceChange {
  kind: "deleted";
  ref: string;
}

interface MdRenderUpdateResult {
  patches: MdPatch[];
  state: MdRendererState;
  resources: MdUsedResource[];
  plugins: MdUsedPlugin[];
  sourceMap: MdSourceMap;
  interactionPatches?: MdInteractionPatch[];
  diagnostics: MdDiagnostic[];
  updateKind: "incremental" | "partial-rerender" | "full-rerender";
}
```

A renderer should produce the smallest practical patch set, but incremental patching is an optimization. A renderer may satisfy the update contract by returning a full replacement patch.

The returned `resources` and `plugins` replace the previous lists. They represent the current rendered state after the update.

#### 5.3.7. DOM patch model

DOM patches are serializable mutation instructions applied by the host-side DOM adapter.

```typescript
type MdPatch =
  | { op: "replace-tree"; node: MdNode }
  | { op: "replace"; id: string; node: MdNode }
  | { op: "remove"; id: string }
  | { op: "append"; parentId: string; node: MdNode }
  | { op: "insert"; parentId: string; index: number; node: MdNode }
  | { op: "setAttr"; id: string; name: string; value: string }
  | { op: "removeAttr"; id: string; name: string }
  | { op: "setText"; id: string; text: string };
```

The adapter should maintain a mapping from renderer node identifiers to actual host nodes. In HTML hosts, the adapter should expose the renderer node identifier on mounted element nodes using `data-md-node`, unless host policy or embedding constraints require an equivalent private mapping.

Example mounted HTML:

```html
<p class="mdpp-paragraph" data-md-node="n42">
  Text
</p>
```

Portable CSS MUST NOT depend on `data-md-node`. It is for host mapping, source lookup, diagnostics, and interaction dispatch.

##### 5.3.7.1. Patch and update invariants

A renderer update result SHOULD obey these invariants:

1. Patches are applied in list order.
2. A patch list is interpreted against the mounted tree produced by the previous successful render or update.
3. `replace-tree` replaces the whole mounted render tree and invalidates all previous node-id mappings.
4. A patch that targets an unknown node id is invalid. The host SHOULD stop applying the affected patch list, report a diagnostic, and request or perform a full rerender when practical.
5. Interaction patches are applied after DOM patches unless the host has an equivalent atomic transaction model.
6. Returned `resources`, `plugins`, and `sourceMap` replace the previous dependency list, plugin list, and source map for the renderer state unless a future profile defines an explicit merge operation.
7. Node ids SHOULD remain stable for unchanged rendered nodes across updates for the lifetime of a compatible renderer state.
8. A renderer MUST NOT intentionally reuse a node id for a different semantic node within the same renderer state lifetime.
9. A renderer MAY satisfy any update by returning a full replacement patch.
10. If plugin update hooks fail, the renderer SHOULD fall back to rerendering the affected subtree or the full tree and SHOULD return diagnostics.

#### 5.3.8. DOM-to-source location

A renderer must support locating the source that produced a rendered node.

The host should not send live DOM nodes to the renderer. Instead, the host-side DOM adapter extracts the renderer node identifier and calls `locateSource` with that identifier.

```typescript
interface MdSourceLocationRequest {
  state: MdRendererState;
  nodeId: string;
  coordinate?: MdDomCoordinate;
}

interface MdDomCoordinate {
  x: number;
  y: number;
  unit?: "css-px";
}

interface MdSourceLocationResult {
  locations: MdSourceMappedRange[];
  precision: "exact" | "nearest-block" | "generated" | "unknown";
  diagnostics: MdDiagnostic[];
}

interface MdSourceMap {
  entries: MdSourceMapEntry[];
}

interface MdSourceMapEntry {
  nodeId: string;
  sourceRange: MdSourceOrigin;
  generatedRange?: MdGeneratedRange;
  role?: string;
}

interface MdGeneratedRange {
  startOffset?: number;
  endOffset?: number;
  x?: number;
  y?: number;
  width?: number;
  height?: number;
}

interface MdSourceMappedRange {
  origin: MdSourceOrigin;
  role?:
    | "markdown"
    | "directive"
    | "fenced-block"
    | "model"
    | "plugin-output"
    | "layout"
    | "theme"
    | "stylesheet"
    | "generated";
  confidence?: number;
}
```

If the rendered node maps directly to Markdown source, the renderer should return the exact source range.

If the node was generated by a plugin, the renderer should return the most precise source location supplied by the plugin.

If only block-level mapping is available, the renderer should return the source range of the owning block and set `precision` to `nearest-block`.

If the node is generated entirely by the renderer, layout engine, or pagination engine, the renderer should return the closest meaningful source origin and set `precision` to `generated`.

#### 5.3.9. Interaction bindings

Interactive behavior is declared through serializable interaction bindings. The renderer and plugins must not communicate executable JavaScript source as portable interaction behavior.

```typescript
interface MdInteractionBinding {
  id: string;
  targetId: string;
  event: MdDomEventName;
  action: MdInteractionAction;
  options?: MdEventOptions;
  source?: MdSourceOrigin;
}

type MdDomEventName =
  | "click"
  | "dblclick"
  | "input"
  | "change"
  | "keydown"
  | "keyup"
  | "pointerenter"
  | "pointerleave"
  | "pointerdown"
  | "pointerup"
  | string;

interface MdEventOptions {
  capture?: boolean;
  once?: boolean;
  passive?: boolean;
}

type MdInteractionAction = MdHostAction | MdPluginAction | MdWorkerAction;
```

A binding says: when event `event` occurs on rendered node `targetId`, run `action`.

Bindings are produced by the renderer or by plugins. The host-side DOM adapter attaches actual event listeners to mounted DOM nodes.

Interaction bindings are part of the rendered result and are updated through interaction patches:

```typescript
type MdInteractionPatch =
  | { op: "replace-all-interactions"; interactions: MdInteractionBinding[] }
  | { op: "addInteraction"; binding: MdInteractionBinding }
  | { op: "removeInteraction"; id: string }
  | { op: "replaceInteraction"; id: string; binding: MdInteractionBinding };
```

#### 5.3.10. Interaction actions

Portable md++ defines three interaction action kinds.

Host actions are small built-in actions performed by the host-side DOM adapter:

```typescript
interface MdHostAction {
  kind: "host-action";
  action:
    | "toggle-class"
    | "set-attribute"
    | "remove-attribute"
    | "show"
    | "hide"
    | "scroll-to"
    | "emit";
  params?: Record<string, unknown>;
}
```

Plugin actions are handled by an authorized main-thread runtime for the selected plugin:

```typescript
interface MdPluginAction {
  kind: "plugin-action";
  pluginId: string;
  action: string;
  params?: Record<string, unknown>;
}
```

Worker actions are forwarded to the renderer or worker-side plugin logic and may return DOM patches, interaction patches, updated state, and diagnostics:

```typescript
interface MdWorkerAction {
  kind: "worker-action";
  pluginId?: string;
  action: string;
  params?: Record<string, unknown>;
}
```

A host must authorize host actions, plugin actions, and worker actions according to policy. Unsupported or denied actions should produce diagnostics and should not execute.

#### 5.3.11. Interaction dispatch

The host-side DOM adapter owns actual event listener registration and dispatch.

When a real UI event fires, the adapter converts it into a normalized portable event payload. It does not pass the raw browser event, live target element, or live DOM objects to the renderer.

```typescript
interface MdInteractionEvent {
  bindingId: string;
  targetId: string;
  event: MdDomEventName;
  value?: string | number | boolean;
  checked?: boolean;
  selected?: string[];
  coordinate?: MdDomCoordinate;
  key?: string;
  modifiers?: {
    alt?: boolean;
    ctrl?: boolean;
    meta?: boolean;
    shift?: boolean;
  };
}

interface MdInteractionRequest {
  state: MdRendererState;
  event: MdInteractionEvent;
  action: MdWorkerAction;
}

interface MdInteractionResult {
  patches?: MdPatch[];
  interactionPatches?: MdInteractionPatch[];
  state?: MdRendererState;
  resources?: MdUsedResource[];
  plugins?: MdUsedPlugin[];
  sourceMap?: MdSourceMap;
  diagnostics?: MdDiagnostic[];
}
```

Conceptually, dispatch follows this process:

1. the adapter receives a real UI event from the mounted DOM;
2. the adapter finds the relevant interaction binding;
3. the adapter builds an `MdInteractionEvent` with safe event details;
4. for `host-action`, the adapter performs the action directly;
5. for `plugin-action`, the adapter calls the authorized main-thread runtime for that plugin;
6. for `worker-action`, the adapter sends `MdInteractionRequest` to the renderer;
7. returned patches, interaction patches, source maps, resource lists, plugin lists, state, and diagnostics are applied or stored by the host.

Example binding:

```json
{
  "id": "bind-1",
  "targetId": "n42",
  "event": "click",
  "action": {
    "kind": "plugin-action",
    "pluginId": "diagram.dot.render",
    "action": "select-node",
    "params": {
      "graphNodeId": "ServiceA"
    }
  }
}
```

Example normalized event:

```json
{
  "bindingId": "bind-1",
  "targetId": "n42",
  "event": "click",
  "coordinate": {
    "x": 120,
    "y": 8,
    "unit": "css-px"
  }
}
```

#### 5.3.12. Host-side DOM adapter

The host-side DOM adapter is not part of the renderer, but the portable contract assumes equivalent behavior.

Recommended conceptual API:

```typescript
interface MdDomAdapter {
  mount(snapshot: MdNode, container: unknown): void;
  applyPatches(patches: MdPatch[]): void;
  applyInteractionPatches(patches: MdInteractionPatch[]): void;
  getNodeId(hostElement: unknown): string | undefined;
  dispatch(event: MdInteractionEvent): Promise<void>;
}
```

The `container` and `hostElement` types are host-specific. Browser hosts use actual DOM elements. Other hosts may use virtual views, editor nodes, native UI widgets, or server-side render targets.

Portable renderers and plugins should not depend on the adapter implementation. They only produce snapshots, patches, source maps, interaction bindings, state, resource lists, plugin lists, and diagnostics.

---

---

## 6. Plugin delegation model

md++ core is intentionally small.

Core responsibilities:

- parse Markdown-compatible directives;
- collect requirements;
- resolve includes and fetch resources for plugins;
- create and pass typed document artifacts between runtime phases;
- identify fenced blocks and their attributes;
- recognize `model=NAME`;
- build the model registry when plugins are available;
- expose the resolved model repository to plugins;
- process layout declarations where supported;
- produce diagnostics.

Plugin and provider responsibilities:

| Responsibility | Example plugin |
|---|---|
| Resolve repository roots and provide repository content | `repository.git` |
| Provide parsing, serialization, patching, semantic access, or validation for a document type | `document.yaml` |
| Transform one document type into another | `transform.markdown-to-html` |
| Render ordinary Mermaid blocks | `diagram.mermaid` |
| Render ordinary DOT blocks | `diagram.dot` |
| Parse DOT as a named model | `model.dot` |
| Render DOT model output | `diagram.dot.render` |
| Validate a model | `model.validation` |
| Render generated reports | `report.render` |
| Export rendered output to PDF, SVG, PNG, HTML, or another package format | `export.pdf` |
| Provide authorized interaction behavior | `interaction.diagram` |

The same plugin may provide several roles. The same block language may have both a normal renderer plugin and a model plugin. The presence of `model=NAME` decides whether model absorption is attempted.

### 6.1. Plugin runtime

Portable md++ plugins are assumed to be JavaScript or TypeScript modules that can run in a worker-compatible context.

The core profile does not define a full plugin package format. Plugin loading, bundling, installation, sandboxing, and dependency resolution are host responsibilities.

The portable runtime model is an API contract between host and plugin. It covers document artifacts, repository access, transformations, rendering, diagnostics, source mapping, and interactions.

A plugin should not depend on direct filesystem, network, live DOM, worker, or process access. It should access document artifacts, document models, resources, diagnostics, rendering insertion points, transformation hooks, update hooks, source-location hooks, and interaction dispatch through host-provided APIs.

A plugin may also provide an optional main-thread interaction runtime for authorized UI behavior. Such a runtime is separate from the portable worker-side rendering API and is loaded only when allowed by host policy.

### 6.2. Plugin metadata

A plugin may expose metadata for discovery and capability resolution.

Recommended metadata:

```typescript
interface MdPluginMetadata {
  id: string;
  name?: string;
  version: string;
  capabilities: MdPluginCapability[];
  roles?: string[];
  documentTypes?: MdDocumentTypeMetadata[];
  workerEntryPoint?: string;
  mainThreadEntryPoint?: string;
}

interface MdPluginCapability {
  name: string;
  version: string;
}
```

Fields:

| Field | Meaning |
|---|---|
| `id` | Stable plugin identifier |
| `name` | Human-readable plugin name |
| `version` | Plugin version |
| `capabilities` | Capabilities the plugin can provide |
| `roles` | Optional descriptive provider roles such as `repository-provider`, `document-type-provider`, `transformation-provider`, `model-parser`, `block-renderer`, or `interaction-runtime` |
| `documentTypes` | Optional document types owned or produced by the plugin |
| `workerEntryPoint` | Optional host-resolved worker-compatible module entry point |
| `mainThreadEntryPoint` | Optional host-resolved main-thread interaction runtime entry point |

#### 6.2.1. Plugin manifest and host approval

A plugin package SHOULD include a manifest named `mdpp-plugin.json`.

The manifest declares identity, entry points, capabilities, roles, lifecycle hooks, and requested permissions. It does not grant permissions by itself. The host decides whether to approve, deny, restrict, prompt for, sandbox, or ignore each request.

Recommended manifest shape:

```json
{
  "schema": "https://schemas.mdpp.example/mdpp-plugin-manifest-v0.15.schema.json",
  "id": "diagram.mermaid",
  "name": "Mermaid diagram renderer",
  "version": "10.0.0",
  "capabilities": [
    { "name": "diagram.mermaid", "version": "10.0.0" }
  ],
  "roles": ["block-renderer"],
  "workerEntryPoint": "./dist/worker.js",
  "mainThreadEntryPoint": "./dist/main.js",
  "hooks": ["pre-render"],
  "permissions": {
    "resources": [{ "ref": "shared:themes/*", "access": ["read"] }],
    "network": [],
    "mainThreadActions": ["diagram.mermaid/select-node"],
    "workerActions": ["diagram.mermaid/render"],
    "rawHtml": false,
    "externalFonts": false,
    "repositoryWrites": false
  }
}
```

Permission fields are declarations for host review. The architecture does not define a universal security policy. A host implementation MUST make its own choices for plugin loading, resource access, network access, raw HTML, stylesheet handling, font loading, main-thread actions, worker actions, and repository writes.

### 6.3. Plugin API shape

The exact API is host-defined, but a portable plugin contract should include operations equivalent to:

Lifecycle event hooks allow plugins to observe broad processing phases without owning a specific fenced block. Recommended hook names are:

| Hook | Meaning |
|---|---|
| `pre-parse` | Called before Markdown parsing for approved source artifacts |
| `post-parse` | Called after Markdown parsing and directive collection |
| `pre-render` | Called before rendering begins, after includes, models, and presentation context are available |
| `post-render` | Called after render output is produced, before final export or mounting |

Hooks SHOULD return diagnostics, additional document artifacts, dependencies, or transformation requests. Hooks SHOULD NOT mutate source artifacts in place. Source-changing hooks SHOULD instead return explicit replacement artifacts or patches, and hosts SHOULD make such behavior visible in diagnostics or trace output.

```typescript
interface MdPlugin {
  metadata: MdPluginMetadata;
  resolveRepository?(request: MdRepositoryResolveRequest, host: MdPluginHost): Promise<MdRepositoryResolveResult>;
  readRepositoryResource?(request: MdRepositoryResourceRequest, host: MdPluginHost): Promise<MdResourceResponse>;
  parseDocument?(request: MdDocumentParseRequest, host: MdPluginHost): Promise<MdDocumentResult>;
  serializeDocument?(request: MdDocumentSerializeRequest, host: MdPluginHost): Promise<MdDocumentSerializeResult>;
  applyDocumentPatch?(request: MdDocumentPatchRequest, host: MdPluginHost): Promise<MdDocumentResult>;
  transform?(request: MdTransformRequest, host: MdPluginHost): Promise<MdTransformResult>;
  handleLifecycleEvent?(request: MdPluginLifecycleEventRequest, host: MdPluginHost): Promise<MdPluginLifecycleEventResult>;
  parseModel?(request: MdModelParseRequest, host: MdPluginHost): Promise<MdModelParseResult>;
  updateModel?(request: MdModelUpdateRequest, host: MdPluginHost): Promise<MdModelParseResult>;
  renderBlock?(request: MdBlockRenderRequest, host: MdPluginHost): Promise<MdRenderResult>;
  updateBlock?(request: MdBlockUpdateRequest, host: MdPluginHost): Promise<MdRenderResult>;
  locateSource?(request: MdPluginSourceLocationRequest, host: MdPluginHost): Promise<MdPluginSourceLocationResult>;
  handleInteraction?(request: MdPluginInteractionRequest, host: MdPluginHost): Promise<MdInteractionResult>;
  validate?(request: MdValidationRequest, host: MdPluginHost): Promise<MdValidationResult>;
}

interface MdPluginHost {
  getModel(name: string): Promise<MdModel | undefined>;
  listModels(): Promise<MdModelSummary[]>;
  getDocument?(idOrRef: string): Promise<MdDocument | undefined>;
  transform?(request: MdTransformRequest): Promise<MdTransformResult>;
  getResource(ref: string): Promise<MdResourceResponse>;
  diagnostic(diagnostic: MdDiagnostic): void;
}
```

The host may expose additional APIs, but plugins intended to be portable should rely only on document artifacts, resolved models, resource access, diagnostics, transformation hooks, update hooks, source-location hooks, and interaction hooks supplied by the host.

### 6.4. Plugin output, state, and source maps

A rendering plugin returns portable render output, not live host DOM nodes.

Preferred rendering plugin output is a serializable `MdNode` subtree, usually as the payload of an `mdpp.render-tree` artifact. A plugin may also return typed document artifacts, sanitized HTML when allowed by host policy, DOM patches during update, source-map entries, interaction bindings, diagnostics, resources, and plugin-owned render state.

The host is responsible for sanitizing, scoping, inserting, measuring, styling, mapping, and binding plugin output.

Plugins should return diagnostics rather than throwing host-visible failures for ordinary authoring errors.

A plugin that can update its own rendered output should return plugin-owned render state. If a plugin does not return state, the renderer may rerender that plugin output from scratch when its inputs change.

Plugin output may also include source-map entries. For simple plugin output, block-level mapping is sufficient. For complex plugin output such as SVG diagrams, charts, generated tables, timelines, or model-derived reports, a plugin should provide finer-grained source-map entries when practical.

A plugin that needs reactive UI behavior should return interaction bindings. The binding may target a host action, a main-thread plugin action, or a worker action. Plugins must not return executable JavaScript source as portable behavior.

### 6.5. Shared data types

The following TypeScript interfaces define the minimum shared shape for portable runtime, renderer, and plugin interaction. Hosts may add fields, but portable renderers and plugins should not require host-specific extensions.

Document artifact, document type provider, transformation provider, repository instance, and job concepts are introduced in the core runtime and document artifact model. Renderer lifecycle, render tree, patch, source-map, and interaction types are defined in this runtime architecture. The additional shared types below are used by processors, renderers, repository providers, document type providers, transformation providers, and plugins.

```typescript
type MdPluginLifecycleEventName =
  | "pre-parse"
  | "post-parse"
  | "pre-render"
  | "post-render"
  | string;

interface MdPluginLifecycleEventRequest {
  event: MdPluginLifecycleEventName;
  documents?: MdDocument[];
  context?: Record<string, unknown>;
  origin?: MdSourceOrigin;
}

interface MdPluginLifecycleEventResult {
  documents?: MdDocument[];
  transformRequests?: MdTransformRequest[];
  resources?: MdUsedResource[];
  diagnostics: MdDiagnostic[];
}

type MdSeverity = "info" | "warning" | "error";

interface MdContentHash {
  algorithm: string;
  value: string;
}

interface MdDocument {
  id: string;
  type: string;
  version?: string;
  mediaType?: string;
  ref?: string;
  origin?: MdSourceOrigin;
  metadata?: Record<string, unknown>;
  content?: unknown;
  semantic?: unknown;
  diagnostics?: MdDiagnostic[];
  patches?: MdDocumentPatch[];
}

type MdDocumentPatch = unknown;

interface MdDocumentTypeMetadata {
  type: string;
  version?: string;
  mediaTypes?: string[];
  fileExtensions?: string[];
}

interface MdDocumentResult {
  document?: MdDocument;
  diagnostics: MdDiagnostic[];
}

interface MdSourceOrigin {
  file?: string;
  line?: number;
  column?: number;
  endLine?: number;
  endColumn?: number;
  repository?: string;
  ref?: string;
}

interface MdDiagnostic {
  source: string;
  severity: MdSeverity;
  message: string;
  code?: string;
  origin?: MdSourceOrigin;
  file?: string;
  line?: number;
  layout?: string;
  area?: string;
  model?: string;
  capability?: string;
}

interface MdRect {
  x: number;
  y: number;
  width: number;
  height: number;
  unit?: "px" | "mm" | "pt" | "css";
}

interface MdCanvas {
  width: number;
  height: number;
  unit?: "px" | "mm" | "pt" | "css";
  orientation?: "portrait" | "landscape";
}

type MdFlowTarget =
  | { kind: "none" }
  | { kind: "same-page"; area: string }
  | { kind: "next-page"; area: string };

type MdOverflowResult =
  | { kind: "none" }
  | { kind: "continued"; target: MdFlowTarget }
  | { kind: "clipped" }
  | { kind: "diagnostic"; diagnostics: MdDiagnostic[] };

interface MdRenderOptions {
  output?: "html" | "pdf" | "print" | "slide" | "image" | string;
  incremental?: boolean;
}

interface MdHostPolicy {
  allowRemoteResources?: boolean;
  allowUnsafeHtml?: boolean;
  allowExternalFonts?: boolean;
  allowInteractions?: boolean;
  allowedHostActions?: string[];
  allowedMainThreadPluginActions?: string[];
  allowedWorkerActions?: string[];
}

interface MdDocumentParseRequest {
  type?: string;
  mediaType?: string;
  ref?: string;
  text?: string;
  content?: ArrayBuffer;
  origin?: MdSourceOrigin;
}

interface MdDocumentSerializeRequest {
  document: MdDocument;
  mediaType?: string;
}

interface MdDocumentSerializeResult {
  text?: string;
  content?: ArrayBuffer;
  mediaType?: string;
  diagnostics: MdDiagnostic[];
}

interface MdDocumentPatchRequest {
  document: MdDocument;
  patches: MdDocumentPatch[];
}

interface MdTransformCapabilityRequest {
  inputTypes: string[];
  outputType?: string;
  purpose?: string;
}

interface MdTransformCapabilityResult {
  accepted: boolean;
  outputTypes?: string[];
  diagnostics: MdDiagnostic[];
}

interface MdTransformRequest {
  inputs: MdDocument[];
  targetType?: string;
  context?: MdTransformContext;
}

interface MdTransformContext {
  presentation?: MdDocument;
  models?: MdDocument;
  options?: Record<string, unknown>;
  origin?: MdSourceOrigin;
}

interface MdTransformResult {
  documents: MdDocument[];
  diagnostics: MdDiagnostic[];
  resources?: MdUsedResource[];
  plugins?: MdUsedPlugin[];
}

interface MdPluginResolveRequest {
  capability?: string;
  versionRange?: string;
  role?: string;
  inputTypes?: string[];
  outputType?: string;
  documentType?: string;
  blockType?: string;
  repositoryRoot?: string;
  renderer?: string;
  interactionAction?: string;
}

interface MdPluginResolveResult {
  plugin?: MdPluginMetadata;
  diagnostics: MdDiagnostic[];
}

interface MdRepositoryResolveRequest {
  name: string;
  root: string;
  origin?: MdSourceOrigin;
}

type MdRepositoryCapability =
  | "read"
  | "write"
  | "create"
  | "delete"
  | "move"
  | "copy"
  | "list"
  | "metadata"
  | "watch"
  | "history"
  | "lock";

interface MdRepositoryResolveResult {
  accepted: boolean;
  canonicalRef?: string;
  providerId?: string;
  capabilities?: MdRepositoryCapability[];
  diagnostics: MdDiagnostic[];
}

interface MdRepositoryResourceRequest {
  repository: string;
  path: string;
  requestedRef: string;
  origin?: MdSourceOrigin;
}

interface MdModelSummary {
  name: string;
  language: string;
  origin?: MdSourceOrigin;
}

interface MdModel extends MdModelSummary {
  sourceText?: string;
  parsed?: unknown;
  diagnostics: MdDiagnostic[];
}

interface MdModelParseRequest {
  name: string;
  language: string;
  sourceText: string;
  attributes: Record<string, string | boolean>;
  origin?: MdSourceOrigin;
}

interface MdModelUpdateRequest {
  previousModel?: MdModel;
  name: string;
  language: string;
  sourceText: string;
  attributes: Record<string, string | boolean>;
  changes: MdResourceChange[];
  origin?: MdSourceOrigin;
}

interface MdModelParseResult {
  model?: MdModel;
  diagnostics: MdDiagnostic[];
}

interface MdBlockRenderRequest {
  blockType: string;
  sourceText: string;
  attributes: Record<string, string | boolean>;
  origin?: MdSourceOrigin;
  presentation?: unknown;
}

interface MdBlockUpdateRequest {
  previousState?: MdPluginRenderState;
  previousNodeId?: string;
  blockType: string;
  previousSourceText?: string;
  sourceText: string;
  attributes: Record<string, string | boolean>;
  changes: MdResourceChange[];
  origin?: MdSourceOrigin;
  presentation?: unknown;
}

interface MdPluginRenderState {
  pluginId: string;
  pluginVersion: string;
  opaque: unknown;
}

interface MdRenderResult {
  node?: MdNode;
  html?: string;
  patches?: MdPatch[];
  state?: MdPluginRenderState;
  resources?: MdUsedResource[];
  sourceMap?: MdSourceMapEntry[];
  interactions?: MdInteractionBinding[];
  interactionPatches?: MdInteractionPatch[];
  diagnostics: MdDiagnostic[];
}

interface MdPluginSourceLocationRequest {
  state?: MdPluginRenderState;
  nodeId: string;
  coordinate?: MdDomCoordinate;
}

interface MdPluginSourceLocationResult {
  locations: MdSourceMappedRange[];
  precision: "exact" | "nearest-block" | "generated" | "unknown";
  diagnostics: MdDiagnostic[];
}

interface MdPluginInteractionRequest {
  state?: MdPluginRenderState;
  event: MdInteractionEvent;
  action: MdPluginAction | MdWorkerAction;
}

type MdTextDiff = unknown;

interface MdValidationRequest {
  models: MdModelSummary[];
  origin?: MdSourceOrigin;
}

interface MdValidationResult {
  diagnostics: MdDiagnostic[];
}
```

A renderer calls `locateSource` on a plugin when a renderer node belongs to a plugin-owned subtree and the plugin has provided source-location support. The plugin should return the most precise mapping it can provide. If the plugin cannot identify a fine-grained source range, it should return the owning block or model source range with `precision: "nearest-block"`.

A renderer calls `handleInteraction` on a plugin or handles the interaction itself when a worker action is dispatched to plugin-owned logic. The result may include patches, interaction patches, updated state, resource and plugin lists, source-map updates, and diagnostics.

### 6.6. Plugin dispatch and conflict resolution

A host maps repository roots, fenced block types, model languages, area renderers, interaction runtimes, and capabilities to plugins through a deterministic dispatch process.

Dispatch is phase-specific:

1. A repository directive is first considered for repository provider resolution as defined in the repository provider section of this architecture.
2. A document artifact is dispatched to a document type provider when parsing, serialization, validation, patching, or semantic access is requested for its document type.
3. A transformation request is dispatched to a transformation provider when input document types and requested output type match a provider capability.
4. A fenced block with `model=NAME` is first considered for model parsing by a model plugin for the block language.
5. If model registration succeeds, the block is absorbed and is not normally rendered at its source position.
6. If no model plugin is available, the block remains available for normal rendering or fallback display.
7. A plugin-owned rendering block is dispatched by exact block type, such as `diagram.dot.render`.
8. An ordinary fenced block is dispatched by its block type or language, such as `mermaid` or `dot`.
9. An area renderer is dispatched by the declared `renderer` property of the area.
10. A main-thread plugin action is dispatched by `pluginId` to the authorized main-thread runtime declared by the selected plugin metadata.
11. A worker action is dispatched to the renderer, which may then dispatch to the worker-side plugin that owns the action or rendered subtree.

When multiple plugins can handle the same operation, portable hosts should apply the following priority order:

| Priority | Selection source | Meaning |
|---|---|---|
| 1 | explicit host configuration | A host or user-selected provider wins when configured |
| 2 | exact repository scheme, document type, transformation input/output type, block type, renderer name, or plugin action owner | `git:` beats a generic resource provider; `mdpp.render-tree` beats a generic document provider; `diagram.dot.render` beats a generic `dot` renderer; an exact `pluginId` beats generic interaction handling |
| 3 | exact required capability match | A provider satisfying an explicit `[md:require]: capability@range` is preferred |
| 4 | canonical built-in mapping | Host default mappings such as local paths to a filesystem provider or `mermaid` to `diagram.mermaid` |
| 5 | generic language renderer | Syntax highlighting or generic code rendering |
| 6 | fallback Markdown behavior | Display the fenced block as ordinary code |

Recommended default dispatch table for a reference implementation:

| Request | Preferred capability or role | Notes |
|---|---|---|
| root/local filesystem repository | `repository.file` | Host-provided default when allowed |
| `git:` repository root | `repository.git` | Repository provider plugin |
| `http:` or `https:` repository root | `repository.http` | Host policy decides whether remote reads are allowed |
| ordinary `mermaid` fenced block | `diagram.mermaid` | Block renderer |
| ordinary `dot` fenced block | `diagram.dot` | Block renderer or code fallback |
| `dot model=NAME` | `model.dot` | Model parser; absorbed on successful registration |
| `diagram.dot.render` block | `diagram.dot.render` | Exact plugin-owned block type |
| `math.latex` or math spans/blocks | `math.latex` | Math renderer |
| `renderer` property on layout area | `area-renderer` with matching renderer name | Area rendering is plugin-specific |
| page/slide mapping from Markdown sections | `layout.markdown-pages` or another `layout-interpreter` | Interprets Markdown fragments into page model |
| syntax-highlighted code block | `highlight.LANGUAGE` or generic highlighter | Fallback displays ordinary code |
| main-thread interaction action | `interaction-runtime` for exact `pluginId` | Must be authorized by host policy |
| worker action | renderer or worker-side plugin with exact owner | Returns patches or diagnostics |

If two or more providers have the same priority and satisfy the same request, the host MUST choose deterministically and SHOULD report an informational diagnostic identifying the selected provider. A host MAY report a warning or error if the ambiguity could change document meaning.

A failed required capability resolution should produce a diagnostic before dispatch. Dispatch may still use fallback behavior when the host determines that continuing is safe.

---

## 7. Reference processing pipeline

### 7.1. Processing order

A portable md++ processor should use the following conceptual processing order for an initial render:

1. create an `mdpp.source` document artifact for the root Markdown-compatible source while preserving concrete source locations and repeated `md:` directives;
2. collect root directives needed for initial resolution, especially profile, requirements, repositories, and includes;
3. resolve required capabilities needed for repository provider selection against the core processor, host, and available plugins;
4. load or select repository provider plugins required by explicit requirements or host policy;
5. register repository declarations as they are encountered, asking repository providers to resolve each repository root and recording the selected repository instance;
6. resolve includes recursively, using the global repository table and the relative base of the source file that contains each include directive;
7. build one `mdpp.resolved-tree` document artifact in source order while preserving source-file boundaries and source-origin metadata;
8. collect resolved directives according to their directive scope;
9. resolve remaining required capabilities against the core processor, host, and available plugins;
10. load or select document type providers, transformation providers, model parsers, block renderers, validators, layout processors, and presentation providers needed by the document;
11. identify fenced blocks and parse md++ info-string attributes into `mdpp.fenced-block` artifacts where applicable;
12. register model blocks into the resolved model repository as `mdpp.model` artifacts;
13. dispatch plugin-owned rendering blocks and ordinary renderable blocks as transformations over typed artifacts;
14. resolve themes, layouts, stylesheets, assets, plugin defaults, and explicit token references into an `mdpp.presentation-context` artifact;
15. build a serializable `mdpp.render-tree` artifact representing the rendered HTML document tree;
16. build an `mdpp.page-model` artifact when the selected layout or output requires pages, slides, fixed canvases, or pagination;
17. create an `mdpp.source-map` artifact that maps source ranges, model ranges, plugin output, generated page structures, and rendered node identifiers;
18. collect `mdpp.interactions` artifacts declared by the renderer and plugins;
19. record the dependency list of used resources and selected plugins;
20. create renderer state for later update, interaction, and source-location operations;
21. return the render tree, source map, interaction bindings, dependency lists, renderer state, and diagnostics;
22. paginate, scale, print, export, mount into a host DOM, or otherwise produce the selected output.

A portable md++ renderer should use the following conceptual processing order for an update:

1. receive changed resources as whole replacement content, text diffs, binary replacements, or deletion notices;
2. convert the changes into updated document artifacts or document patches where supported;
3. match changed resource references against the previous dependency graph in the renderer state;
4. invalidate affected includes, repositories, models, blocks, layouts, themes, stylesheets, assets, fonts, and plugin outputs;
5. reuse unaffected parse, model, layout, presentation, plugin, and render state where valid;
6. ask affected document type providers and transformation providers to update their own artifacts, state, and output when they support update hooks;
7. rerender affected subtrees when plugin update hooks are unavailable or fail safely;
8. produce serializable DOM patches or a replacement snapshot for the affected rendered tree;
9. rebuild source mappings, interaction bindings, and dependency lists;
10. return patches, updated renderer state, used resources, used plugins, source map, interaction binding changes, and diagnostics.

Hosts may combine phases internally, but diagnostics and observable behavior should be consistent with this order.

---

## 8. Diagnostics, tracing, and auditability

Runtime components SHOULD report diagnostics rather than throwing host-visible failures for ordinary authoring or processing errors. Stable diagnostic codes are maintained in `mdpp_diagnostic_catalog_v0_15.md`.

Diagnostics should be structured, should include source-origin information when available, and should identify the responsible component, resource, plugin, model, layout, or area when relevant.

Hosts should preserve traceability across:

- source files and includes;
- repository roots and resources;
- model parsing;
- block rendering;
- layout and pagination;
- plugin output;
- generated nodes;
- source maps;
- interactions;
- exported files.

A host may additionally keep audit records for plugin loading, denied resource requests, remote access, persistence operations, interaction dispatch, worker execution, and export jobs.

---

## 9. Non-goals

The reference runtime architecture does not define:

- a complete plugin package format beyond the recommended `mdpp-plugin.json` manifest;
- a mandatory module loader;
- a mandatory worker implementation beyond the recommended JSON-RPC exchange profile for cross-runtime boundaries;
- a mandatory job queue;
- a mandatory editor model;
- a mandatory DOM adapter implementation;
- a mandatory repository backend;
- a mandatory cache strategy;
- a complete security model or universal permission policy;
- a mandatory persistence or synchronization protocol.

These are host responsibilities or implementation choices. The architecture defines common boundaries and data shapes so independent implementations can remain compatible where practical.

---

## 10. Changes in draft 0.15

Draft 0.15 adds theme-level include composition, repeated-theme override clarifications, conformance language, a JSON-RPC worker IPC/RPC profile, plugin manifests, lifecycle event hooks, repository canonicalization rules, patch/update invariants, layout interpretation and area rendering as plugin-owned concerns, a default dispatch table, references to the separate diagnostic catalog, and references to the JSON Schema skeleton.

<!-- BEGIN mdpp-office-pipeline-update-v0-15: runtime -->

## Addendum: Office import, sidecars, theme declarations, and page furniture

This runtime addendum extends the v0.15 reference architecture with exchange responsibilities for the Office-normalization pipeline.

An Office-like importer is a lossy semantic transformation:

```text
office.docx | office.pptx -> mdpp.source + mdpp.comment-sidecar? + diagnostics
```

The importer should produce semantic md++ source first. It should not encode the full Office object model as custom inline syntax. Named source styles should become attribute-list classes when safe. Comments, review notes, speaker notes, and traceability metadata should become `mdpp.comment-sidecar` artifacts associated with the generated md++ document.

The presentation resolver should resolve theme-level includes in theme context before exposing theme tokens, class declarations, component declarations, page-furniture profiles, assets, stylesheets, and plugin defaults as a single `mdpp.presentation-context` artifact. The layout interpreter chooses active page furniture after the active layout and theme are known. The paginator resolves `{page.number}` and `{page.count}` after page generation.

Recommended additional document types:

| Type | Meaning |
|---|---|
| `office.docx` | Input DOCX-like source artifact |
| `office.pptx` | Input PPTX-like source artifact |
| `mdpp.comment-sidecar` | Imported comments, speaker notes, review notes, and traceability metadata |

Import diagnostics should use `MDPP0700`-range codes. Page-furniture and richer-theme diagnostics should use `MDPP0413`-`MDPP0418`.

<!-- END mdpp-office-pipeline-update-v0-15: runtime -->
