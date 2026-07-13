import { IconRefresh, IconSearch, IconSettings } from "@tabler/icons-react";

export function Toolbar({
  query,
  onQueryChange,
  onOpenPreferences,
  onRebuildIndex,
}: {
  query: string;
  onQueryChange: (value: string) => void;
  onOpenPreferences: () => void;
  onRebuildIndex: () => void;
}) {
  return (
    <div
      className="flex shrink-0 items-center gap-2.5 border-b px-3.5 py-2.5"
      style={{ borderColor: "var(--border)", background: "var(--surface-2)" }}
    >
      <IconSearch size={18} style={{ color: "var(--text-muted)" }} />
      <input
        autoFocus
        value={query}
        onChange={(e) => onQueryChange(e.target.value)}
        placeholder="输入文件名 / 路径 / 拼音首字母…"
        className="flex-1 bg-transparent text-[15px] outline-none"
        style={{ color: "var(--text-primary)" }}
      />
      <button
        onClick={onRebuildIndex}
        title="重建索引"
        className="rounded-md p-1.5 transition-colors hover:opacity-80"
        style={{ color: "var(--text-muted)" }}
      >
        <IconRefresh size={17} />
      </button>
      <button
        onClick={onOpenPreferences}
        title="偏好设置"
        className="rounded-md p-1.5 transition-colors hover:opacity-80"
        style={{ color: "var(--text-muted)" }}
      >
        <IconSettings size={17} />
      </button>
    </div>
  );
}
