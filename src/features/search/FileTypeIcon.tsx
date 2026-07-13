import { IconFile, IconFileText, IconFolder, IconPhoto, IconPlayerPlay } from "@tabler/icons-react";
import type { FileEntry } from "../../lib/bindings";
import { categoryOf } from "../../lib/fileType";

const VIDEO_EXTS = new Set(["mp4", "mov", "avi", "mkv", "webm", "key"]);

export function FileTypeIcon({ entry, className }: { entry: FileEntry; className?: string }) {
  if (entry.kind === "Directory") {
    return <IconFolder size={20} className={className} />;
  }
  const dot = entry.name.lastIndexOf(".");
  const ext = dot > 0 ? entry.name.slice(dot + 1).toLowerCase() : "";
  const category = categoryOf(entry);

  if (VIDEO_EXTS.has(ext)) return <IconPlayerPlay size={20} className={className} />;
  if (category === "document") return <IconFileText size={20} className={className} />;
  if (category === "image") return <IconPhoto size={20} className={className} />;
  return <IconFile size={20} className={className} />;
}
