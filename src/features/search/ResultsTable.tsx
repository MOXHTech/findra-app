import { IconChevronDown, IconChevronUp } from "@tabler/icons-react";
import { openPath, revealItemInDir } from "@tauri-apps/plugin-opener";
import type { FileEntry } from "../../lib/bindings";
import { formatBytes, formatTimestamp } from "../../lib/format";
import { FileTypeIcon } from "./FileTypeIcon";
import type { SortColumn } from "./useSearchStore";

interface Column {
  key: SortColumn | "icon";
  label: string;
  sortable: boolean;
  width: string;
}

const COLUMNS: Column[] = [
  { key: "name", label: "名称", sortable: true, width: "34%" },
  { key: "path", label: "路径", sortable: true, width: "28%" },
  { key: "size", label: "大小", sortable: true, width: "12%" },
  { key: "ctime", label: "创建时间", sortable: true, width: "13%" },
  { key: "mtime", label: "修改时间", sortable: true, width: "13%" },
];

export function ResultsTable({
  entries,
  selectedId,
  onSelect,
  sortColumn,
  descending,
  onSort,
}: {
  entries: FileEntry[];
  selectedId: number | null;
  onSelect: (id: number) => void;
  sortColumn: SortColumn;
  descending: boolean;
  onSort: (column: SortColumn) => void;
}) {
  return (
    <div className="flex-1 overflow-auto">
      <table className="w-full border-collapse text-[13px]">
        <thead className="sticky top-0 z-10" style={{ background: "var(--surface-1)" }}>
          <tr className="border-b" style={{ borderColor: "var(--border)" }}>
            {COLUMNS.map((col) => (
              <th
                key={col.key}
                style={{ width: col.width, color: "var(--text-secondary)" }}
                className="cursor-pointer select-none px-3 py-2 text-left text-[12px] font-medium"
                onClick={() => col.sortable && onSort(col.key as SortColumn)}
              >
                <span className="inline-flex items-center gap-1">
                  {col.label}
                  {sortColumn === col.key &&
                    (descending ? <IconChevronDown size={13} /> : <IconChevronUp size={13} />)}
                </span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {entries.map((entry) => {
            const isSelected = entry.id === selectedId;
            return (
              <tr
                key={entry.id}
                onClick={() => onSelect(entry.id)}
                onDoubleClick={() => entry.path && openPath(entry.path)}
                onContextMenu={(e) => {
                  e.preventDefault();
                  if (entry.path) void revealItemInDir(entry.path);
                }}
                className="cursor-default border-b"
                style={{
                  borderColor: "var(--border)",
                  background: isSelected ? "var(--bg-accent)" : "transparent",
                }}
              >
                <td className="px-3 py-2">
                  <div className="flex items-center gap-2">
                    <FileTypeIcon entry={entry} className={isSelected ? "" : "opacity-70"} />

                    <span className="truncate font-medium" style={{ color: "var(--text-primary)" }}>
                      {entry.name}
                    </span>
                  </div>
                </td>
                <td className="truncate px-3 py-2" style={{ color: "var(--text-secondary)" }}>
                  {entry.path ?? ""}
                </td>
                <td className="px-3 py-2 tabular-nums" style={{ color: "var(--text-secondary)" }}>
                  {entry.kind === "Directory" ? "—" : formatBytes(entry.size)}
                </td>
                <td className="px-3 py-2 tabular-nums" style={{ color: "var(--text-secondary)" }}>
                  {formatTimestamp(entry.ctime)}
                </td>
                <td className="px-3 py-2 tabular-nums" style={{ color: "var(--text-secondary)" }}>
                  {formatTimestamp(entry.mtime)}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
      {entries.length === 0 && (
        <div className="py-16 text-center text-[13px]" style={{ color: "var(--text-muted)" }}>
          没有匹配的文件
        </div>
      )}
    </div>
  );
}
