# md++ Word Exporter VBA Module

This folder contains a first-pass Word VBA exporter for normal `.docx` documents.

## Files

- `MdppWordExporter.bas` — standard VBA module to import into Word.
- `mdpp-word-base.template.css` — readable copy of the standard CSS approach embedded in the macro.

## Use

1. Open Word.
2. Press `Alt+F11` to open the VBA editor.
3. Use `File > Import File...` and select `MdppWordExporter.bas`.
4. Return to Word.
5. Run macro `ExportActiveDocumentToMdpp`.
6. Choose an output folder.

The macro writes:

```text
root.md
root.md.comments.json
root.md.import.json
themes/word-import.theme.md
layouts/word-report.layout.md
styles/mdpp-word-base.css
assets/
```

## Conversion scope

The exporter is semantic and intentionally lossy. It handles normal Word content:

- headings using outline levels / Heading styles;
- paragraphs;
- simple numbered and bullet lists;
- basic inline bold, italic, and hyperlinks;
- simple Word tables as GFM tables;
- inline pictures, extracted through a temporary filtered-HTML export;
- paragraph styles as md++ `{.word-style-*}` classes;
- document theme, layout, and CSS files;
- Word comments as a JSON sidecar.

Known limitations:

- floating shapes are reported but not placed reliably in source order;
- SmartArt, charts, embedded objects, tracked changes, and complex fields are not preserved as editable structures;
- exact pagination is not preserved;
- table merges are simplified;
- image order depends on Word's filtered-HTML export order and should be reviewed.

## Recommended workflow

Use this macro as an import normalizer:

```text
DOCX -> md++ files -> text editing -> md++ renderer -> HTML/PDF
```

Review the generated `root.md.import.json` after export.
