export type BinaryInput = Uint8Array | ArrayBuffer | Blob;

export interface MdppDocxConvertInput {
  data: BinaryInput;
  sourceName?: string;
}

export interface MdppDocxConvertOptions {
  title?: string;
  rootFileName?: string;
  includeRawStyleClasses?: boolean;
  commentAnchorMode?: "attribute" | "none";
  imageBaseName?: string;
  emitSimpleMarkdownTables?: boolean;
}

export interface MdppGeneratedFile {
  path: string;
  content: string | Uint8Array;
  mediaType?: string;
}

export interface MdppImportDiagnostic {
  code: string;
  severity: "info" | "warning" | "error";
  message: string;
  source?: string;
  wordPart?: string;
  detail?: Record<string, unknown>;
}

export interface MdppDocxConvertResult {
  files: MdppGeneratedFile[];
  diagnostics: MdppImportDiagnostic[];
}

export interface OpenXmlRelationship {
  id: string;
  type: string;
  target: string;
  targetMode?: string;
}

export interface WordStyleInfo {
  styleId: string;
  type?: string;
  name?: string;
  basedOn?: string;
  numbering?: WordNumberingReference;
}

export interface WordCommentInfo {
  id: string;
  author?: string;
  date?: string;
  text: string;
}

export interface ImportedCommentAnchor {
  id: string;
  commentId: string;
  paragraphIndex: number;
}

export interface WordNumberingReference {
  numId?: string;
  level?: number;
}
