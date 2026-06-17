import { unzipSync } from "fflate";
import { DOMParser } from "@xmldom/xmldom";
import type { OpenXmlRelationship, WordCommentInfo, WordStyleInfo } from "./types.js";

const decoder = new TextDecoder("utf-8");

export interface DocxPackage {
  entries: Record<string, Uint8Array>;
  text(path: string): string | undefined;
  xml(path: string): Document | undefined;
  binary(path: string): Uint8Array | undefined;
}

export async function readDocxPackage(data: Uint8Array | ArrayBuffer | Blob): Promise<DocxPackage> {
  const bytes = await toUint8Array(data);
  const entries = unzipSync(bytes);
  return {
    entries,
    text(path: string) {
      const entry = entries[normalizeZipPath(path)];
      return entry ? decoder.decode(entry) : undefined;
    },
    xml(path: string) {
      const xmlText = this.text(path);
      if (!xmlText) return undefined;
      return new DOMParser({ errorHandler: () => undefined }).parseFromString(xmlText, "application/xml");
    },
    binary(path: string) {
      return entries[normalizeZipPath(path)];
    }
  };
}

async function toUint8Array(data: Uint8Array | ArrayBuffer | Blob): Promise<Uint8Array> {
  if (data instanceof Uint8Array) return data;
  if (data instanceof ArrayBuffer) return new Uint8Array(data);
  if (typeof Blob !== "undefined" && data instanceof Blob) return new Uint8Array(await data.arrayBuffer());
  throw new Error("Unsupported DOCX input. Expected Uint8Array, ArrayBuffer, or Blob.");
}

export function normalizeZipPath(path: string): string {
  return path.replace(/^\/+/, "").replace(/\\/g, "/");
}

export function resolvePartTarget(basePartPath: string, target: string): string {
  if (target.startsWith("/")) return normalizeZipPath(target);
  const baseDir = basePartPath.includes("/") ? basePartPath.slice(0, basePartPath.lastIndexOf("/")) : "";
  const raw = `${baseDir}/${target}`;
  const out: string[] = [];
  for (const part of raw.split("/")) {
    if (!part || part === ".") continue;
    if (part === "..") out.pop();
    else out.push(part);
  }
  return out.join("/");
}

export function localName(node: Node | null | undefined): string {
  if (!node) return "";
  const name = (node as Element).localName || node.nodeName || "";
  const colon = name.indexOf(":");
  return colon >= 0 ? name.slice(colon + 1) : name;
}

export function isElement(node: Node | null | undefined, wanted?: string): node is Element {
  if (!node || node.nodeType !== 1) return false;
  return wanted ? localName(node) === wanted : true;
}

export function children(el: Element | Document, wanted?: string): Element[] {
  const result: Element[] = [];
  const list = el.childNodes;
  for (let i = 0; i < list.length; i++) {
    const child = list.item(i);
    if (isElement(child, wanted)) result.push(child);
  }
  return result;
}

export function firstChild(el: Element | Document, wanted: string): Element | undefined {
  return children(el, wanted)[0];
}

export function descendants(el: Element | Document, wanted: string): Element[] {
  const result: Element[] = [];
  function walk(n: Node) {
    if (isElement(n, wanted)) result.push(n);
    const list = n.childNodes;
    for (let i = 0; i < list.length; i++) walk(list.item(i));
  }
  walk(el);
  return result;
}

export function firstDescendant(el: Element | Document, wanted: string): Element | undefined {
  return descendants(el, wanted)[0];
}

export function attr(el: Element | undefined, name: string): string | undefined {
  if (!el) return undefined;
  const exact = el.getAttribute(name);
  if (exact !== null) return exact;
  const wantedLocal = name.includes(":") ? name.slice(name.indexOf(":") + 1) : name;
  for (let i = 0; i < el.attributes.length; i++) {
    const a = el.attributes.item(i)!;
    const aLocal = a.localName || a.name.split(":").pop() || a.name;
    if (aLocal === wantedLocal) return a.value;
  }
  return undefined;
}

export function textOf(el: Element | Document | undefined): string {
  return el?.textContent ?? "";
}

export function parseRelationships(doc: Document | undefined): Map<string, OpenXmlRelationship> {
  const map = new Map<string, OpenXmlRelationship>();
  if (!doc) return map;
  for (const rel of descendants(doc, "Relationship")) {
    const id = attr(rel, "Id");
    const target = attr(rel, "Target");
    const type = attr(rel, "Type") || "";
    if (id && target) {
      map.set(id, { id, type, target, targetMode: attr(rel, "TargetMode") });
    }
  }
  return map;
}

export function parseStyles(doc: Document | undefined): Map<string, WordStyleInfo> {
  const map = new Map<string, WordStyleInfo>();
  if (!doc) return map;
  for (const style of descendants(doc, "style")) {
    const styleId = attr(style, "styleId");
    if (!styleId) continue;
    const name = attr(firstChild(style, "name"), "val");
    const basedOn = attr(firstChild(style, "basedOn"), "val");
    map.set(styleId, {
      styleId,
      type: attr(style, "type"),
      name,
      basedOn
    });
  }
  return map;
}

export function parseComments(doc: Document | undefined): Map<string, WordCommentInfo> {
  const map = new Map<string, WordCommentInfo>();
  if (!doc) return map;
  for (const c of descendants(doc, "comment")) {
    const id = attr(c, "id");
    if (!id) continue;
    map.set(id, {
      id,
      author: attr(c, "author"),
      date: attr(c, "date"),
      text: textOf(c).trim()
    });
  }
  return map;
}

export function paragraphStyleId(p: Element): string | undefined {
  const pPr = firstChild(p, "pPr");
  return attr(firstChild(pPr!, "pStyle"), "val");
}

export function runHasProperty(r: Element, propName: string): boolean {
  const rPr = firstChild(r, "rPr");
  return !!rPr && !!firstChild(rPr, propName);
}

export function numPr(p: Element): { numId?: string; level?: number } | undefined {
  const pPr = firstChild(p, "pPr");
  const np = pPr ? firstChild(pPr, "numPr") : undefined;
  if (!np) return undefined;
  const numId = attr(firstChild(np, "numId"), "val");
  const levelRaw = attr(firstChild(np, "ilvl"), "val");
  return { numId, level: levelRaw == null ? undefined : Number(levelRaw) };
}

export function sectionProperties(document: Document): Element | undefined {
  const body = firstDescendant(document, "body");
  if (!body) return undefined;
  const direct = children(body, "sectPr");
  if (direct.length) return direct[direct.length - 1];
  const paras = children(body, "p");
  for (let i = paras.length - 1; i >= 0; i--) {
    const pPr = firstChild(paras[i], "pPr");
    const sp = pPr ? firstChild(pPr, "sectPr") : undefined;
    if (sp) return sp;
  }
  return undefined;
}
