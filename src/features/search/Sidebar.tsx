import { IconApps, IconFileText, IconFolder, IconGridDots, IconPhoto } from "@tabler/icons-react";
import type { FileCategory } from "../../lib/fileType";

interface CategoryCount {
  category: FileCategory | "all";
  count: number;
}

const ICONS: Record<FileCategory | "all", React.ComponentType<{ size?: number; className?: string }>> = {
  all: IconGridDots,
  document: IconFileText,
  image: IconPhoto,
  application: IconApps,
  folder: IconFolder,
  other: IconFileText,
};

const LABELS: Record<FileCategory | "all", string> = {
  all: "全部",
  document: "文档",
  image: "图片",
  application: "应用程序",
  folder: "文件夹",
  other: "其他",
};

export function Sidebar({
  counts,
  active,
  onSelect,
}: {
  counts: CategoryCount[];
  active: FileCategory | "all";
  onSelect: (category: FileCategory | "all") => void;
}) {
  return (
    <aside
      className="flex w-44 shrink-0 flex-col gap-3 overflow-y-auto border-r px-2 py-3"
      style={{ borderColor: "var(--border)", background: "var(--surface-1)" }}
    >
      <div>
        <div className="px-2 pb-1.5 text-[11px] font-medium" style={{ color: "var(--text-muted)" }}>
          筛选
        </div>
        <div className="flex flex-col gap-0.5">
          {counts.map(({ category, count }) => {
            const Icon = ICONS[category];
            const isActive = active === category;
            return (
              <button
                key={category}
                onClick={() => onSelect(category)}
                className="flex items-center gap-2.5 rounded-md px-2 py-1.5 text-left text-[13px] transition-colors"
                style={{
                  background: isActive ? "var(--bg-accent)" : "transparent",
                  color: isActive ? "var(--text-accent)" : "var(--text-primary)",
                }}
              >
                <Icon size={17} className={isActive ? "" : "opacity-70"} />
                <span className="flex-1 truncate">{LABELS[category]}</span>
                <span className="text-[11px] tabular-nums" style={{ color: "var(--text-muted)" }}>
                  {count}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    </aside>
  );
}
