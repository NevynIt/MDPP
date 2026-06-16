# md++ Diagnostic Catalog

[md:profile]: md++
[md:profile-version]: 0.14
[md:title]: <md++ Diagnostic Catalog>
[md:status]: draft

Status: draft 0.14  
Document type: Diagnostic code catalog  
Related language spec: `mdpp_language_spec_v0_14.md`  
Related runtime architecture: `mdpp_reference_runtime_architecture_v0_14.md`

This document assigns stable diagnostic codes for md++ language processors, runtime hosts, plugins, editors, reports, and tests.

The catalog is maintained separately from the language and runtime specifications so codes can remain stable while the specifications evolve.

## 1. Code format

Diagnostic codes use this form:

```text
MDPPNNNN
```

Ranges:

| Range | Area |
|---|---|
| `MDPP0001` - `MDPP0099` | Core document/profile/directive parsing |
| `MDPP0100` - `MDPP0199` | Requirements and capability resolution |
| `MDPP0200` - `MDPP0299` | Includes, repositories, and resources |
| `MDPP0300` - `MDPP0399` | Fenced blocks, models, and plugin-owned blocks |
| `MDPP0400` - `MDPP0499` | Themes, stylesheets, layouts, pages, and areas |
| `MDPP0500` - `MDPP0599` | Rendering, source maps, patches, and interactions |
| `MDPP0600` - `MDPP0699` | Runtime, plugins, manifests, IPC/RPC, and jobs |
| `MDPP9000` - `MDPP9999` | Host-defined or experimental diagnostics |

## 2. Initial code list

| Code | Default severity | Area | Meaning |
|---|---:|---|---|
| `MDPP0001` | error | profile | Invalid or unsupported `[md:profile]` value |
| `MDPP0002` | warning | profile | Missing `[md:profile-version]` |
| `MDPP0003` | warning | markdown | Base Markdown input is not valid GFM |
| `MDPP0004` | error | directive | Invalid `md:` directive syntax |
| `MDPP0005` | warning | directive | Repeated directive ignored by a non-conforming parser |
| `MDPP0006` | error | anchor | Duplicate explicit anchor |
| `MDPP0100` | error | requirement | Invalid requirement syntax |
| `MDPP0101` | error | requirement | Invalid capability version range |
| `MDPP0102` | warning | requirement | Missing required capability |
| `MDPP0103` | error | requirement | Requirement contains both `@` range and title range |
| `MDPP0104` | error | requirement | Unknown repository in repository-scoped requirement |
| `MDPP0105` | warning | requirement | Multiple providers satisfy requirement; deterministic provider selected |
| `MDPP0200` | warning | include | Missing include file |
| `MDPP0201` | error | include | Circular include |
| `MDPP0202` | error | repository | Invalid repository name |
| `MDPP0203` | warning | repository | Repeated repository name with same canonical target |
| `MDPP0204` | error | repository | Duplicate repository name with different target |
| `MDPP0205` | error | repository | Unavailable repository provider |
| `MDPP0206` | error | repository | Repository path escapes above root |
| `MDPP0207` | warning | resource | Resource fetch failure |
| `MDPP0208` | warning | resource | Resource request denied by host policy |
| `MDPP0209` | error | resource | Invalid repository-qualified reference |
| `MDPP0300` | error | fenced-block | Invalid fenced block info string |
| `MDPP0301` | error | model | Duplicate model name |
| `MDPP0302` | error | model | Model parser failed |
| `MDPP0303` | warning | block | Unsupported fenced block required by selected output |
| `MDPP0304` | warning | plugin | Plugin render failure |
| `MDPP0400` | error | theme | Invalid theme resource |
| `MDPP0401` | error | stylesheet | Invalid stylesheet resource |
| `MDPP0402` | error | layout | Invalid layout resource |
| `MDPP0403` | error | layout | Unknown layout |
| `MDPP0404` | warning | area | Unknown area class in page or slide source |
| `MDPP0405` | error | area | Area declaration references missing grid area |
| `MDPP0406` | error | layout | Non-rectangular repeated grid area |
| `MDPP0407` | error | layout | Invalid track size |
| `MDPP0408` | warning | area | Area overflow with `flow: none` |
| `MDPP0409` | error | area | Invalid flow target |
| `MDPP0410` | error | area | Unresolvable flow cycle |
| `MDPP0411` | warning | area | Unsupported area renderer |
| `MDPP0412` | error | token | Theme token reference cannot be resolved |
| `MDPP0500` | warning | source-map | Source mapping unavailable or ambiguous |
| `MDPP0501` | error | patch | Invalid DOM patch target |
| `MDPP0502` | error | renderer-state | Renderer state incompatible with update request |
| `MDPP0503` | warning | interaction | Unsupported or denied interaction action |
| `MDPP0504` | error | interaction | Invalid interaction binding target |
| `MDPP0505` | warning | interaction | Plugin interaction failure |
| `MDPP0600` | error | manifest | Invalid `mdpp-plugin.json` manifest |
| `MDPP0601` | warning | manifest | Plugin requested permission denied by host |
| `MDPP0602` | error | rpc | Invalid JSON-RPC message |
| `MDPP0603` | error | rpc | Unknown runtime RPC method |
| `MDPP0604` | warning | job | Runtime job failed |

## 3. Diagnostic object

Diagnostics SHOULD use the common runtime shape defined in the runtime architecture and represented in the JSON Schema skeleton:

```yaml
source: md.processor
severity: warning
code: MDPP0408
message: "Area 'right' overflows slide."
file: deck.md
line: 42
layout: layout-two-columns
area: right
```

## 4. Catalog maintenance rules

- A published code MUST NOT be reused for a different meaning.
- A code MAY be deprecated, but deprecated codes SHOULD remain documented.
- Default severities MAY be elevated or reduced by host policy when appropriate.
- Host-defined diagnostics SHOULD use the `MDPP9xxx` range or a host-specific prefix.
