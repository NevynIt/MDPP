# md++ Office Import Profile

[md:profile]: md++
[md:profile-version]: 0.15
[md:title]: <md++ Office Import Profile>
[md:status]: draft

Status: draft 0.15  
File type: Markdown-compatible import profile  
Canonical extension: `.md`

This document defines optional lossy import conventions for DOCX, PPTX, and similar visual office formats into md++ source documents.

---

## 1. Scope

md++ may be used as a semantic normalization target for DOCX, PPTX, or similar visual office formats. Import is intentionally lossy.

The md++ language specification remains the source-language definition. This profile defines importer behavior, source-feature mapping, sidecar metadata, and diagnostics for office-like inputs.

---

## 2. Import mapping

Recommended mapping:

| Office-like source feature | md++ target |
|---|---|
| Body paragraphs | Markdown paragraphs with style classes when useful |
| Heading styles | Markdown headings |
| Named paragraph styles | Attribute-list classes |
| Named character styles | Attribute-list classes when they can be represented safely |
| Tables | Markdown tables when simple; plugin/component blocks when complex |
| Images | Asset files referenced by Markdown images |
| Headers, footers, page numbers | Theme/layout page furniture |
| Comments, review notes, speaker notes | Sidecar metadata |
| Unrepresentable freeform layout, SmartArt, charts, embedded objects, macros | Static asset, placeholder, omission, or diagnostic |

---

## 3. Style classes

Attribute-list classes such as `{.lead}` or `{.callout-warning}` are portable author-facing style classes. An importer should map safe named source styles to classes rather than embedding source application style objects in the body.

Example:

```markdown
# Imported report {.word-style-title}

This paragraph came from a Word style named "Executive Summary". {.word-style-executive-summary}
```

Theme and stylesheet resources define what these classes mean visually. Unknown classes should remain in the Markdown and may produce diagnostics only when a selected profile requires class declarations.

---

## 4. Sidecar metadata

Comments, review notes, speaker notes, tracked-change metadata, and source application identifiers should normally be stored outside the md++ body in sidecar files.

Recommended sidecar naming:

```text
root.md.comments.json
root.md.comments.yaml
root.md.import.json
```

Targets should prefer explicit anchors when available and may fall back to source-origin ranges or generated block identifiers.

---

## 5. Diagnostics

Importers should emit diagnostics from an implementation-defined import range for unsupported or degraded source features.

Recommended diagnostic situations include:

| Case | Severity |
|---|---|
| Unsupported source feature omitted | warning |
| Unsupported source feature converted to static asset | warning |
| Source style converted to md++ class | info |
| Source style name could not be normalized safely | warning |
| Comment or speaker note moved to sidecar metadata | info |
| Macro, script, or active object omitted | warning or error |
| Freeform layout degraded to linear Markdown | warning |
| Table could not be represented as a portable Markdown table | warning |
| Embedded chart converted to image | warning |
