import type { FileEntry } from "./bindings";

export type FileCategory = "document" | "image" | "application" | "folder" | "other";

const DOCUMENT_EXTS = new Set([
  "doc", "docx", "pdf", "txt", "md", "rtf", "xls", "xlsx", "ppt", "pptx", "csv", "key", "pages", "numbers",
]);
const IMAGE_EXTS = new Set(["jpg", "jpeg", "png", "gif", "svg", "webp", "heic", "bmp", "tiff"]);
const APPLICATION_EXTS = new Set(["app", "exe", "dmg", "pkg", "msi", "deb", "rpm", "appimage"]);

function extensionOf(name: string): string {
  const dot = name.lastIndexOf(".");
  return dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
}

export function categoryOf(entry: FileEntry): FileCategory {
  if (entry.kind === "Directory") return "folder";
  const ext = extensionOf(entry.name);
  if (DOCUMENT_EXTS.has(ext)) return "document";
  if (IMAGE_EXTS.has(ext)) return "image";
  if (APPLICATION_EXTS.has(ext)) return "application";
  return "other";
}

export const CATEGORY_LABELS: Record<FileCategory, string> = {
  document: "文档",
  image: "图片",
  application: "应用程序",
  folder: "文件夹",
  other: "其他",
};
