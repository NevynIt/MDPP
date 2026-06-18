export function escapeMarkdownText(text: string): string {
  return text
    .replace(/\\/g, "\\\\")
    .replace(/([*_`\[\]])/g, "\\$1");
}

export function escapeMarkdownCell(text: string): string {
  return text.replace(/\|/g, "\\|").replace(/\s*\r?\n\s*/g, " / ");
}

export function slugClassName(input: string | undefined, prefix = "word-style"): string | undefined {
  if (!input) return undefined;
  const slug = input
    .trim()
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug ? `${prefix}-${slug}` : undefined;
}

export function mdAttributes(attrs: Record<string, string | number | boolean | undefined>): string {
  const parts: string[] = [];
  for (const [key, value] of Object.entries(attrs)) {
    if (value === undefined || value === false || value === "") continue;
    if (value === true) parts.push(key.startsWith(".") || key.startsWith("#") ? key : key);
    else parts.push(`${key}="${String(value).replace(/"/g, "&quot;")}"`);
  }
  return parts.length ? `{${parts.join(" ")}}` : "";
}

export function mdClassAttr(className: string | undefined): string {
  return className ? `{.${className}}` : "";
}

export function ensureBlank(lines: string[]): void {
  if (lines.length && lines[lines.length - 1] !== "") lines.push("");
}
