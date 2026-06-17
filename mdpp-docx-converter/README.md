# md++ DOCX importer prototype

A small Node.js / browser-embeddable prototype that converts a `.docx` package into an md++ bundle:

```text
root.md
themes/word-import.theme.md
layouts/word-report.layout.md
styles/word-import.css
assets/*
comments/comments.sidecar.json
comments/import-diagnostics.json
```

## Install and build

```bash
npm install
npm run build
```

## CLI usage

```bash
node dist/node/cli.js ./input.docx --out ./out --title "Imported report"
```

## Embeddable browser/core API

The conversion core has no filesystem dependency. It accepts `Uint8Array`, `ArrayBuffer`, or browser `Blob` input and returns an in-memory file list.

```ts
import { convertDocxToMdpp } from "@mdpp/docx-importer";

const arrayBuffer = await file.arrayBuffer();
const result = await convertDocxToMdpp({ data: arrayBuffer, sourceName: file.name });

for (const file of result.files) {
  console.log(file.path, file.mediaType);
}
```

A web app can write the returned files into an in-memory repository, a bundle, IndexedDB, or a download ZIP.

## Why this uses OpenXML directly

The converter reads the `.docx` ZIP package and parses the WordprocessingML parts instead of driving Word through VBA. This is more deterministic and exposes data that md++ needs: styles, relationships, media, comments, section properties, headers, and footers.

## Library choices

Runtime dependencies are intentionally small and browser-friendly:

- `fflate`: ZIP extraction/compression in pure JavaScript.
- `@xmldom/xmldom`: DOMParser/XMLSerializer ponyfill for Node. Browser builds can use native DOMParser through bundling or an adapter later.

Mammoth and docx-preview are useful reference/fallback libraries, but this prototype does not use them as the main path. Mammoth is optimized for clean semantic HTML, while this importer needs lower-level access to DOCX package parts and sidecars. docx-preview is useful for visual preview/fallback rendering, not as the canonical semantic importer.

## Current conversion coverage

Implemented:

- Word paragraphs and headings to Markdown/md++.
- Word paragraph style names to md++ classes, for example `{.word-style-heading-1}`.
- Basic lists to Markdown bullets.
- Simple tables to Markdown tables.
- Runs with bold and italic.
- Hyperlinks.
- Embedded images copied from `word/media/*` to `assets/*`.
- Image width/height from DrawingML extent when available.
- Floating images converted to anchored Markdown images with diagnostics.
- Comments sidecar from `word/comments.xml`.
- Basic header/footer text mapped into theme page furniture.
- Import diagnostics JSON.

Not yet implemented or deliberately lossy:

- Exact Word pagination.
- Exact floating layout, wrapping, cropping, z-order, grouped shapes.
- Numbering style detection from `word/numbering.xml`.
- Footnotes/endnotes.
- Tracked changes.
- Fields, TOC, cross references.
- Complex tables with spans/nested tables.
- SmartArt, charts, OLE objects, and arbitrary DrawingML beyond picture extraction.

## Recommended next steps

1. Add a proper OpenXML numbering resolver.
2. Add footnotes/endnotes sidecars.
3. Add tracked-change sidecars.
4. Improve image metadata: crop, wrap, anchor position, original relationship id.
5. Add a browser demo that accepts a `.docx` file and shows the generated md++ files.
6. Add fixtures from real Word documents and compare outputs with expected md++ bundles.
