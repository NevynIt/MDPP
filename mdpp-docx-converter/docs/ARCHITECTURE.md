# Architecture

The package is split into a pure conversion core and thin platform adapters.

```text
src/core/
  convert.ts      DOCX package -> md++ generated files
  openxml.ts      ZIP and XML helpers
  markdown.ts     Markdown escaping and class-name helpers
  types.ts        public API types

src/node/
  cli.ts          Node CLI argument parsing
  writeFiles.ts   filesystem output adapter
```

The core is intended to be embedded in a future web application. It returns files as memory objects instead of writing them directly:

```ts
interface MdppDocxConvertResult {
  files: MdppGeneratedFile[];
  diagnostics: MdppImportDiagnostic[];
}
```

This makes it possible to use the same converter in:

- a Node CLI;
- a browser file-picker workflow;
- a React md++ viewer/import wizard;
- a future md++ visual editor;
- a batch conversion service.

## Conversion pipeline

```text
DOCX bytes
  -> unzip package
  -> parse OpenXML parts
  -> resolve relationships, styles, comments, headers/footers, media
  -> traverse document body
  -> emit root.md + theme + layout + CSS + sidecars + assets
```

## Diagnostic approach

Lossy or unsupported features are not silently dropped when detectable. The converter writes diagnostics to both the returned result and `comments/import-diagnostics.json`.

The diagnostic codes are aligned with the proposed md++ Office-import diagnostics:

- `MDPP0417`: imported table degraded.
- `MDPP0418`: floating/freeform layout degraded.
- `MDPP0419`: linked/unsupported embedded object degraded.
- `MDPP0420`: unsupported imported object skipped or flattened.
