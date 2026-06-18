#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import path from "node:path";
import { convertDocxToMdpp } from "../core/convert.js";
import { writeGeneratedFiles } from "./writeFiles.js";

interface Args {
  input?: string;
  outDir: string;
  title?: string;
}

function parseArgs(argv: string[]): Args {
  const args: Args = { outDir: "mdpp-out" };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--out" || a === "-o") args.outDir = argv[++i];
    else if (a === "--title") args.title = argv[++i];
    else if (a === "--help" || a === "-h") usageAndExit(0);
    else if (!args.input) args.input = a;
    else throw new Error(`Unexpected argument: ${a}`);
  }
  if (!args.input) usageAndExit(1);
  return args;
}

function usageAndExit(code: number): never {
  console.log(`mdpp-docx-import <file.docx> --out <folder> [--title "Title"]\n\nConverts a DOCX/OpenXML package to an md++ file bundle.`);
  process.exit(code);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const data = await readFile(args.input!);
  const result = await convertDocxToMdpp({ data, sourceName: path.basename(args.input!) }, { title: args.title });
  await writeGeneratedFiles(args.outDir, result.files);
  const warnings = result.diagnostics.filter(d => d.severity !== "info");
  console.error(`Wrote ${result.files.length} files to ${args.outDir}`);
  if (warnings.length) console.error(`Diagnostics: ${warnings.length} warning/error entries written to root.md.import.json`);
}

main().catch(err => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(1);
});
