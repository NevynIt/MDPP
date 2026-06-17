import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import type { MdppGeneratedFile } from "../core/types.js";

export async function writeGeneratedFiles(outDir: string, files: MdppGeneratedFile[]): Promise<void> {
  await mkdir(outDir, { recursive: true });
  for (const file of files) {
    const target = path.join(outDir, file.path);
    const normalizedTarget = path.resolve(target);
    const normalizedOut = path.resolve(outDir);
    if (!normalizedTarget.startsWith(normalizedOut)) {
      throw new Error(`Refusing to write outside output directory: ${file.path}`);
    }
    await mkdir(path.dirname(normalizedTarget), { recursive: true });
    await writeFile(normalizedTarget, file.content as any);
  }
}
