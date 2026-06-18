import {
  attr,
  children,
  descendants,
  firstChild,
  firstDescendant,
  localName,
  numPr,
  paragraphStyleId,
  parseComments,
  parseNumbering,
  parseXml,
  parseRelationships,
  parseStyles,
  readDocxPackage,
  resolvePartTarget,
  runHasProperty,
  sectionProperties,
  textOf
} from "./openxml.js";
import { escapeMarkdownCell, escapeMarkdownText, mdAttributes, slugClassName } from "./markdown.js";
import type { WordNumberingDefinition, WordNumberingLevel } from "./openxml.js";
import type {
  ImportedCommentAnchor,
  MdppDocxConvertInput,
  MdppDocxConvertOptions,
  MdppDocxConvertResult,
  MdppGeneratedFile,
  MdppImportDiagnostic,
  WordCommentInfo,
  WordNumberingReference,
  WordStyleInfo
} from "./types.js";

const EMU_PER_PT = 12700;

interface ParagraphInfo {
  styleId?: string;
  style?: WordStyleInfo;
  styleName?: string;
  className?: string;
  semantic: ParagraphSemantic;
}

type ParagraphSemantic =
  | { kind: "normal" }
  | { kind: "heading"; level: number }
  | { kind: "unordered-list"; level: number }
  | { kind: "ordered-list"; level: number }
  | { kind: "quote" }
  | { kind: "code" }
  | { kind: "callout"; className: string };

interface ConversionState {
  files: MdppGeneratedFile[];
  diagnostics: MdppImportDiagnostic[];
  styles: Map<string, WordStyleInfo>;
  numbering: Map<string, WordNumberingDefinition>;
  comments: Map<string, WordCommentInfo>;
  rels: Map<string, { id: string; type: string; target: string; targetMode?: string }>;
  packageEntries: Record<string, Uint8Array>;
  imageCounter: number;
  usedStyleClasses: Set<string>;
  commentAnchors: ImportedCommentAnchor[];
  options: Required<Pick<MdppDocxConvertOptions, "rootFileName" | "includeRawStyleClasses" | "commentAnchorMode" | "imageBaseName" | "emitSimpleMarkdownTables">> & MdppDocxConvertOptions;
}

export async function convertDocxToMdpp(input: MdppDocxConvertInput, options: MdppDocxConvertOptions = {}): Promise<MdppDocxConvertResult> {
  const pkg = await readDocxPackage(input.data);
  const documentXml = pkg.xml("word/document.xml");
  if (!documentXml) throw new Error("Not a valid DOCX package: missing word/document.xml");

  const state: ConversionState = {
    files: [],
    diagnostics: [],
    styles: parseStyles(pkg.xml("word/styles.xml")),
    numbering: parseNumbering(pkg.xml("word/numbering.xml")),
    comments: parseComments(pkg.xml("word/comments.xml")),
    rels: parseRelationships(pkg.xml("word/_rels/document.xml.rels")),
    packageEntries: pkg.entries,
    imageCounter: 1,
    usedStyleClasses: new Set(),
    commentAnchors: [],
    options: {
      rootFileName: options.rootFileName ?? "root.md",
      includeRawStyleClasses: options.includeRawStyleClasses ?? true,
      commentAnchorMode: options.commentAnchorMode ?? "attribute",
      imageBaseName: options.imageBaseName ?? "image",
      emitSimpleMarkdownTables: options.emitSimpleMarkdownTables ?? true,
      ...options
    }
  };

  const body = firstDescendant(documentXml, "body");
  if (!body) throw new Error("Invalid DOCX: document body not found");

  const lines: string[] = [];
  lines.push("[md:profile]: md++");
  lines.push("[md:profile-version]: 0.14");
  lines.push(`[md:title]: <${escapeDirectiveValue(options.title ?? input.sourceName ?? "Word import")}>`);
  lines.push("[md:theme]: themes/word-import.theme.md");
  lines.push("[md:layout]: layouts/word-report.layout.md");
  lines.push("[md:stylesheet]: styles/word-import.css");
  lines.push("");

  let paragraphIndex = 0;
  const bodyChildren = children(body);
  for (let i = 0; i < bodyChildren.length; i++) {
    const node = bodyChildren[i];
    if (localName(node) === "sectPr") continue;
    if (localName(node) === "p") {
      const info = paragraphInfo(node, state);
      if (info.semantic.kind === "code") {
        const codeParagraphs: Element[] = [];
        let j = i;
        while (j < bodyChildren.length && localName(bodyChildren[j]) === "p" && paragraphInfo(bodyChildren[j], state).semantic.kind === "code") {
          codeParagraphs.push(bodyChildren[j]);
          j++;
        }
        const block = codeBlockToMarkdown(codeParagraphs, state, paragraphIndex);
        paragraphIndex += codeParagraphs.length;
        i = j - 1;
        if (block.trim()) {
          lines.push(block);
          lines.push("");
        }
        continue;
      }
      const block = paragraphToMarkdown(node, state, paragraphIndex++);
      if (block.trim()) {
        lines.push(block);
        lines.push("");
      }
    } else if (localName(node) === "tbl") {
      lines.push(tableToMarkdown(node, state));
      lines.push("");
    } else {
      state.diagnostics.push({
        code: "MDPP0420",
        severity: "warning",
        message: `Unsupported top-level Word element '${localName(node)}' was skipped.`,
        wordPart: "word/document.xml"
      });
    }
  }

  state.files.push({ path: state.options.rootFileName, content: lines.join("\n").replace(/\n{3,}/g, "\n\n"), mediaType: "text/markdown" });
  state.files.push({ path: "themes/word-import.theme.md", content: buildTheme(state, documentXml), mediaType: "text/markdown" });
  state.files.push({ path: "layouts/word-report.layout.md", content: buildLayout(documentXml), mediaType: "text/markdown" });
  state.files.push({ path: "styles/word-import.css", content: buildCss(state), mediaType: "text/css" });
  state.files.push({ path: "comments/comments.sidecar.json", content: JSON.stringify(buildCommentsSidecar(state), null, 2) + "\n", mediaType: "application/json" });
  state.files.push({ path: "comments/import-diagnostics.json", content: JSON.stringify(state.diagnostics, null, 2) + "\n", mediaType: "application/json" });

  return { files: state.files, diagnostics: state.diagnostics };
}

function paragraphToMarkdown(p: Element, state: ConversionState, paragraphIndex: number): string {
  const info = paragraphInfo(p, state);
  const anchorIds = commentAnchorIdsForParagraph(p, state, paragraphIndex);
  const text = inlineContent(p, state).trim();
  if (!text && !anchorIds.length) return "";

  const attrs = blockAttributes(info, anchorIds, state);
  switch (info.semantic.kind) {
    case "heading":
      return `${"#".repeat(info.semantic.level)} ${text}${attrs ? " " + attrs : ""}`.trim();
    case "unordered-list":
      return `${"  ".repeat(info.semantic.level)}- ${text}${attrs ? " " + attrs : ""}`.trimEnd();
    case "ordered-list":
      return `${"  ".repeat(info.semantic.level)}1. ${text}${attrs ? " " + attrs : ""}`.trimEnd();
    case "quote":
      return `> ${text}${attrs ? " " + attrs : ""}`.trimEnd();
    case "callout":
      return `${text}${attrs ? " " + attrs : ""}`.trim();
    default:
      return `${text}${attrs ? " " + attrs : ""}`.trim();
  }
}

function paragraphInfo(p: Element, state: ConversionState): ParagraphInfo {
  const styleId = paragraphStyleId(p);
  const style = styleId ? state.styles.get(styleId) : undefined;
  const styleName = style?.name ?? styleId;
  const className = slugClassName(styleName);

  const headingLevel = headingLevelFromStyle(styleName ?? styleId);
  if (headingLevel) return { styleId, style, styleName, className, semantic: { kind: "heading", level: headingLevel } };

  const numbering = resolveParagraphNumbering(p, state, styleId);
  if (numbering?.level?.format) {
    const kind = numbering.level.format === "bullet" ? "unordered-list" : "ordered-list";
    return { styleId, style, styleName, className, semantic: { kind, level: numbering.markdownLevel } };
  }

  const styleKey = `${styleId ?? ""} ${styleName ?? ""} ${className ?? ""}`;
  if (/\bquote\b/i.test(styleKey)) return { styleId, style, styleName, className, semantic: { kind: "quote" } };
  if (/\bcode\b/i.test(styleKey)) return { styleId, style, styleName, className, semantic: { kind: "code" } };
  if (/\bcallout-warning\b/i.test(styleKey)) return { styleId, style, styleName, className, semantic: { kind: "callout", className: "callout-warning" } };

  return { styleId, style, styleName, className, semantic: { kind: "normal" } };
}

function commentAnchorIdsForParagraph(p: Element, state: ConversionState, paragraphIndex: number): string[] {
  const ids = new Set<string>();
  for (const el of descendants(p, "commentRangeStart")) {
    const id = attr(el, "id");
    if (id) ids.add(id);
  }
  for (const el of descendants(p, "commentReference")) {
    const id = attr(el, "id");
    if (id) ids.add(id);
  }
  const anchorIds: string[] = [];
  for (const id of ids) {
    const anchorId = `word-comment-${id}`;
    state.commentAnchors.push({ id: anchorId, commentId: id, paragraphIndex });
    if (state.options.commentAnchorMode === "attribute") anchorIds.push(anchorId);
  }
  return anchorIds;
}

function blockAttributes(info: ParagraphInfo, anchorIds: string[], state: ConversionState): string {
  const attrs: Record<string, string | number | boolean | undefined> = {};
  for (const anchorId of anchorIds) attrs[`#${anchorId}`] = true;
  if (info.semantic.kind === "callout") attrs[`.${info.semantic.className}`] = true;
  if (info.semantic.kind === "callout") state.usedStyleClasses.add(info.semantic.className);
  if (shouldEmitRawStyleClass(info) && info.className) {
    attrs[`.${info.className}`] = true;
    state.usedStyleClasses.add(info.className);
  }
  return mdAttributes(attrs);
}

function shouldEmitRawStyleClass(info: ParagraphInfo): boolean {
  return info.semantic.kind === "normal" || info.semantic.kind === "callout";
}

function resolveParagraphNumbering(p: Element, state: ConversionState, styleId?: string): { ref: WordNumberingReference; definition?: WordNumberingDefinition; level?: WordNumberingLevel; markdownLevel: number } | undefined {
  const ref = numPr(p) ?? inheritedStyleNumbering(styleId, state);
  if (!ref?.numId) return undefined;
  const definition = state.numbering.get(ref.numId);
  const levelIndex = ref.level ?? 0;
  const level = definition?.levels.get(levelIndex) ?? firstNumberingLevel(definition);
  return { ref, definition, level, markdownLevel: markdownListLevel(ref, level) };
}

function inheritedStyleNumbering(styleId: string | undefined, state: ConversionState, seen = new Set<string>()): WordNumberingReference | undefined {
  if (!styleId || seen.has(styleId)) return undefined;
  seen.add(styleId);
  const style = state.styles.get(styleId);
  return style?.numbering ?? inheritedStyleNumbering(style?.basedOn, state, seen);
}

function firstNumberingLevel(definition: WordNumberingDefinition | undefined): WordNumberingLevel | undefined {
  return definition ? [...definition.levels.values()].sort((a, b) => a.level - b.level)[0] : undefined;
}

function markdownListLevel(ref: WordNumberingReference, level: WordNumberingLevel | undefined): number {
  if (ref.level != null && ref.level > 0) return ref.level;
  if (level?.leftTwips && level.leftTwips > 360) return Math.max(0, Math.round(level.leftTwips / 360) - 1);
  return 0;
}

function codeBlockToMarkdown(paragraphs: Element[], state: ConversionState, firstParagraphIndex: number): string {
  const lines = paragraphs.map(p => textOf(p).trim());
  for (let i = 0; i < paragraphs.length; i++) commentAnchorIdsForParagraph(paragraphs[i], state, firstParagraphIndex + i);
  const first = lines[0] ?? "";
  const last = lines[lines.length - 1] ?? "";
  if (first.startsWith("```") && last === "```") return [first, ...lines.slice(1, -1), last].join("\n");
  return ["```", ...lines, "```"].join("\n");
}

function inlineContent(parent: Element, state: ConversionState): string {
  let out = "";
  for (const node of children(parent)) {
    switch (localName(node)) {
      case "r":
        out += runToMarkdown(node, state);
        break;
      case "hyperlink":
        out += hyperlinkToMarkdown(node, state);
        break;
      case "bookmarkStart":
      case "bookmarkEnd":
      case "commentRangeStart":
      case "commentRangeEnd":
      case "proofErr":
      case "permStart":
      case "permEnd":
      case "pPr":
        break;
      default:
        if (localName(node).startsWith("custom")) break;
        out += textOf(node);
    }
  }
  return normalizeInlineSpacing(out);
}

function runToMarkdown(r: Element, state: ConversionState): string {
  let out = "";
  for (const node of children(r)) {
    switch (localName(node)) {
      case "t":
        out += escapeMarkdownText(textOf(node));
        break;
      case "tab":
        out += "\t";
        break;
      case "br":
        out += attr(node, "type") === "page" ? "\n\n---\n\n" : "  \n";
        break;
      case "drawing":
      case "pict":
        out += drawingToMarkdown(node, state);
        break;
      case "commentReference":
        break;
      default:
        break;
    }
  }
  const bold = runHasProperty(r, "b");
  const italic = runHasProperty(r, "i");
  if (out.trim()) {
    if (bold && italic) out = `***${out}***`;
    else if (bold) out = `**${out}**`;
    else if (italic) out = `*${out}*`;
  }
  return out;
}

function hyperlinkToMarkdown(h: Element, state: ConversionState): string {
  const text = inlineContent(h, state) || textOf(h);
  const relId = attr(h, "id");
  const anchor = attr(h, "anchor");
  if (relId && state.rels.has(relId)) {
    const rel = state.rels.get(relId)!;
    return `[${text}](${rel.target})`;
  }
  if (anchor) return `[${text}](#${anchor})`;
  return text;
}

function drawingToMarkdown(drawing: Element, state: ConversionState): string {
  const blip = firstDescendant(drawing, "blip");
  const relId = attr(blip, "embed") ?? attr(blip, "link");
  if (!relId) {
    state.diagnostics.push({ code: "MDPP0420", severity: "warning", message: "Drawing without image relationship was skipped.", wordPart: "word/document.xml" });
    return "";
  }

  const rel = state.rels.get(relId);
  if (!rel) {
    state.diagnostics.push({ code: "MDPP0420", severity: "warning", message: `Image relationship '${relId}' was not found.`, wordPart: "word/_rels/document.xml.rels" });
    return "";
  }

  if (rel.targetMode === "External") {
    state.diagnostics.push({ code: "MDPP0419", severity: "warning", message: `External linked image '${rel.target}' was referenced, not embedded.`, wordPart: "word/document.xml" });
    return `![linked image](${rel.target})`;
  }

  const sourcePath = resolvePartTarget("word/document.xml", rel.target);
  const imageBytes = state.packageEntries[sourcePath];
  if (!imageBytes) {
    state.diagnostics.push({ code: "MDPP0420", severity: "warning", message: `Image part '${sourcePath}' was not found.`, wordPart: sourcePath });
    return "";
  }

  const ext = extensionFromPath(sourcePath) || extensionFromContentType(rel.type) || "bin";
  const fileName = `${state.options.imageBaseName}-${String(state.imageCounter++).padStart(3, "0")}.${ext}`;
  const outPath = `assets/${fileName}`;
  state.files.push({ path: outPath, content: imageBytes, mediaType: mediaTypeForExt(ext) });

  const docPr = firstDescendant(drawing, "docPr");
  const alt = attr(docPr, "descr") || attr(docPr, "title") || "image";
  const extent = firstDescendant(drawing, "extent");
  const cx = Number(attr(extent, "cx"));
  const cy = Number(attr(extent, "cy"));
  const isFloating = !!firstDescendant(drawing, "anchor");
  if (isFloating) {
    state.diagnostics.push({ code: "MDPP0418", severity: "warning", message: "Floating image was converted to an anchored Markdown image; exact Word wrapping/z-order may be lost.", wordPart: "word/document.xml" });
  }

  const attrs = mdAttributes({
    ".word-image": true,
    width: Number.isFinite(cx) && cx > 0 ? `${Math.round(cx / EMU_PER_PT)}pt` : undefined,
    height: Number.isFinite(cy) && cy > 0 ? `${Math.round(cy / EMU_PER_PT)}pt` : undefined,
    "data-word-layout": isFloating ? "floating" : "inline"
  });
  return `![${escapeMarkdownText(alt)}](${outPath})${attrs}`;
}

function tableToMarkdown(tbl: Element, state: ConversionState): string {
  const rows = children(tbl, "tr");
  const matrix = rows.map(row => children(row, "tc").map(cell => cellText(cell, state)));
  const maxCols = Math.max(0, ...matrix.map(r => r.length));
  if (!state.options.emitSimpleMarkdownTables || maxCols === 0) {
    state.diagnostics.push({ code: "MDPP0417", severity: "warning", message: "Table could not be represented as a Markdown table and was emitted as plain text rows.", wordPart: "word/document.xml" });
    return matrix.map(row => row.filter(Boolean).join(" | ")).filter(Boolean).join("\n");
  }
  const padded = matrix.map(r => [...r, ...Array(Math.max(0, maxCols - r.length)).fill("")]);
  const header = padded[0] || Array(maxCols).fill("");
  const lines = [
    `| ${header.map(escapeMarkdownCell).join(" | ")} |`,
    `| ${Array(maxCols).fill("---").join(" | ")} |`
  ];
  for (const row of padded.slice(1)) lines.push(`| ${row.map(escapeMarkdownCell).join(" | ")} |`);
  return lines.join("\n");
}

function cellText(cell: Element, state: ConversionState): string {
  return children(cell)
    .filter(c => localName(c) === "p")
    .map((p, i) => paragraphToMarkdown(p, state, -1 - i).replace(/\s*\{\.word-style-[^}]+\}\s*$/, ""))
    .filter(Boolean)
    .join("\n");
}

function buildTheme(state: ConversionState, documentXml: Document): string {
  const furniture = extractPageFurniture(state, documentXml);
  const lines: string[] = [];
  lines.push("[md:profile]: md++");
  lines.push("[md:profile-version]: 0.14");
  lines.push("[md:title]: <Word import theme>");
  lines.push("[md:stylesheet]: ../styles/word-import.css");
  lines.push("[md:layout]: ../layouts/word-report.layout.md");
  lines.push("");
  lines.push("## colors");
  lines.push("");
  lines.push("text: #111111");
  lines.push("background: #ffffff");
  lines.push("accent: #2f5597");
  lines.push("");
  lines.push("## typography");
  lines.push("");
  lines.push("body-font: Calibri, Arial, sans-serif");
  lines.push("heading-font: Calibri, Arial, sans-serif");
  lines.push("");
  for (const className of [...state.usedStyleClasses].sort()) {
    lines.push(`## class ${className}`);
    lines.push("");
    lines.push("css-class: ." + className);
    lines.push("");
  }
  lines.push("## class word-image");
  lines.push("");
  lines.push("css-class: .word-image");
  lines.push("");
  lines.push("## page-furniture word-report");
  lines.push("");
  lines.push(`header-left: ${yamlText(furniture.headerLeft || "")}`);
  lines.push(`header-center: ${yamlText(furniture.headerCenter || "")}`);
  lines.push(`header-right: ${yamlText(furniture.headerRight || "")}`);
  lines.push(`footer-left: ${yamlText(furniture.footerLeft || "")}`);
  lines.push(`footer-center: ${yamlText(furniture.footerCenter || "Page {page.number} of {page.count}")}`);
  lines.push(`footer-right: ${yamlText(furniture.footerRight || "")}`);
  lines.push("");
  return lines.join("\n");
}

function buildLayout(documentXml: Document): string {
  const sect = sectionProperties(documentXml);
  const pgSz = sect ? firstChild(sect, "pgSz") : undefined;
  const w = Number(attr(pgSz, "w"));
  const h = Number(attr(pgSz, "h"));
  const orientation = attr(pgSz, "orient") || (Number.isFinite(w) && Number.isFinite(h) && w > h ? "landscape" : "portrait");
  return [
    "[md:profile]: md++",
    "[md:profile-version]: 0.14",
    "[md:title]: <Word report layout>",
    "",
    "canvas:",
    "  size: A4",
    `  orientation: ${orientation}`,
    "  padding: 72pt 72pt 72pt 72pt",
    "  gap: 18pt",
    "  page-furniture: word-report",
    "",
    "grid:",
    "  - \"body\"",
    "",
    "area body:",
    "  flow: >body",
    "  renderer: flow",
    ""
  ].join("\n");
}

function buildCss(state: ConversionState): string {
  const classRules = [...state.usedStyleClasses].sort().map(c => `\n.mdpp-document .${c} {\n  /* Word style class imported from DOCX. Refine in the theme/CSS layer. */\n}`).join("\n");
  return `:root {
  --mdpp-color-text: #111111;
  --mdpp-color-background: #ffffff;
  --mdpp-color-accent: #2f5597;
  --mdpp-font-body: Calibri, Arial, sans-serif;
  --mdpp-font-heading: Calibri, Arial, sans-serif;
}

.mdpp-document {
  color: var(--mdpp-color-text);
  background: var(--mdpp-color-background);
  font-family: var(--mdpp-font-body);
  line-height: 1.45;
}

.mdpp-document h1,
.mdpp-document h2,
.mdpp-document h3,
.mdpp-document h4,
.mdpp-document h5,
.mdpp-document h6 {
  font-family: var(--mdpp-font-heading);
}

.mdpp-document .word-image {
  max-width: 100%;
  height: auto;
}

.mdpp-document .word-comment-anchor {
  display: inline;
}${classRules}
`;
}

function buildCommentsSidecar(state: ConversionState) {
  return {
    type: "mdpp.comments.sidecar",
    version: "0.1",
    comments: [...state.comments.values()].map(c => ({
      id: c.id,
      author: c.author,
      date: c.date,
      text: c.text,
      anchors: state.commentAnchors.filter(a => a.commentId === c.id).map(a => ({ id: a.id, paragraphIndex: a.paragraphIndex }))
    }))
  };
}

function extractPageFurniture(state: ConversionState, documentXml: Document): Record<string, string> {
  const sect = sectionProperties(documentXml);
  if (!sect) return {};
  const result: Record<string, string> = {};
  const refs = children(sect).filter(e => localName(e) === "headerReference" || localName(e) === "footerReference");
  for (const ref of refs) {
    const id = attr(ref, "id");
    if (!id) continue;
    const rel = state.rels.get(id);
    if (!rel) continue;
    const part = resolvePartTarget("word/document.xml", rel.target);
    const xmlText = state.packageEntries[part] ? new TextDecoder().decode(state.packageEntries[part]) : undefined;
    const doc = parseXml(xmlText);
    if (!doc) continue;
    const text = descendants(doc, "p").map(p => textOf(p).trim()).filter(Boolean).join(" / ");
    if (!text) continue;
    if (localName(ref) === "headerReference") result.headerCenter = text;
    else result.footerCenter = text;
  }
  return result;
}

function headingLevelFromStyle(styleName?: string): number | undefined {
  if (!styleName) return undefined;
  const m = styleName.match(/^heading\s*([1-9])$/i) || styleName.match(/^Heading([1-9])$/);
  return m ? Number(m[1]) : undefined;
}

function extensionFromPath(path: string): string | undefined {
  const m = path.match(/\.([a-zA-Z0-9]+)$/);
  return m ? m[1].toLowerCase().replace("jpeg", "jpg") : undefined;
}

function extensionFromContentType(type: string): string | undefined {
  if (type.includes("png")) return "png";
  if (type.includes("jpeg") || type.includes("jpg")) return "jpg";
  if (type.includes("gif")) return "gif";
  if (type.includes("svg")) return "svg";
  return undefined;
}

function mediaTypeForExt(ext: string): string {
  switch (ext) {
    case "png": return "image/png";
    case "jpg":
    case "jpeg": return "image/jpeg";
    case "gif": return "image/gif";
    case "svg": return "image/svg+xml";
    default: return "application/octet-stream";
  }
}

function escapeDirectiveValue(text: string): string {
  return text.replace(/[<>]/g, "").trim();
}

function normalizeInlineSpacing(text: string): string {
  return text.replace(/\u00a0/g, " ").replace(/[ \t]+\n/g, "\n");
}

function yamlText(text: string): string {
  return JSON.stringify(text);
}
