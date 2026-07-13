import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { defaultSearchQuery, ipc } from "../../lib/ipc";
import { categoryOf, type FileCategory } from "../../lib/fileType";
import { Sidebar } from "./Sidebar";
import { ResultsTable } from "./ResultsTable";
import { StatusBar } from "./StatusBar";
import { Toolbar } from "./Toolbar";
import { useSearchStore, type SortColumn } from "./useSearchStore";
import { useAutoUpdate } from "../../lib/useAutoUpdate";
import type { SearchQuery, SortField } from "../../lib/bindings";

const SORT_FIELD_MAP: Record<SortColumn, SortField> = {
  name: "Name",
  path: "Path",
  size: "Size",
  ctime: "CTime",
  mtime: "ModTime",
};

/** Debounces `value` by `delayMs` - the PRD calls for "输入即搜（无需回车）"
 * (search-as-you-type), but firing an IPC round trip on every keystroke
 * would queue up stale requests behind fast typing. */
function useDebounced<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);
  return debounced;
}

export function SearchWindow({ onOpenPreferences }: { onOpenPreferences: () => void }) {
  const { query, setQuery, category, setCategory, sortColumn, descending, toggleSort } = useSearchStore();
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const debouncedQuery = useDebounced(query, 150);
  const queryClient = useQueryClient();

  const searchParams: SearchQuery = useMemo(
    () => ({
      ...defaultSearchQuery(debouncedQuery),
      pinyin: true,
      sort_by: SORT_FIELD_MAP[sortColumn],
      descending,
      limit: 300,
    }),
    [debouncedQuery, sortColumn, descending],
  );

  const { data: allEntries = [] } = useQuery({
    queryKey: ["search", searchParams],
    queryFn: () => ipc.search(searchParams),
  });

  const { data: stats, isError: statusErrored } = useQuery({
    queryKey: ["status"],
    queryFn: () => ipc.status(),
    refetchInterval: 3000,
    retry: false,
  });

  const counts = useMemo(() => {
    const byCategory: Record<FileCategory, number> = {
      document: 0,
      image: 0,
      application: 0,
      folder: 0,
      other: 0,
    };
    for (const entry of allEntries) {
      byCategory[categoryOf(entry)] += 1;
    }
    return [
      { category: "all" as const, count: allEntries.length },
      { category: "document" as const, count: byCategory.document },
      { category: "image" as const, count: byCategory.image },
      { category: "application" as const, count: byCategory.application },
      { category: "folder" as const, count: byCategory.folder },
    ];
  }, [allEntries]);

  const visibleEntries = useMemo(
    () => (category === "all" ? allEntries : allEntries.filter((e) => categoryOf(e) === category)),
    [allEntries, category],
  );

  const handleSort = (column: SortColumn) => toggleSort(column);
  const { updateVersion, applyUpdate } = useAutoUpdate();

  const handleRebuildIndex = async () => {
    // Rescans whichever path the daemon is already configured to watch -
    // `IndexStats.watch_status` is the only place a client can currently
    // learn the daemon's configured paths (there's no dedicated "get
    // config" IPC method yet). Nothing to do if the daemon hasn't reported
    // any yet (e.g. still starting up).
    const firstWatchedPath = stats?.watch_status?.[0]?.[0];
    if (!firstWatchedPath) return;
    await ipc.rebuildIndex(firstWatchedPath);
    void queryClient.invalidateQueries({ queryKey: ["status"] });
  };

  return (
    <div className="flex h-screen w-screen flex-col" style={{ background: "var(--surface-2)" }}>
      {updateVersion && (
        <div
          className="flex items-center justify-between px-3.5 py-1.5 text-[12px]"
          style={{ background: "var(--bg-accent)", color: "var(--text-accent)" }}
        >
          <span>已下载新版本 {updateVersion} · 重启后生效</span>
          <button onClick={applyUpdate} className="font-medium underline">
            立即重启
          </button>
        </div>
      )}
      <Toolbar
        query={query}
        onQueryChange={setQuery}
        onOpenPreferences={onOpenPreferences}
        onRebuildIndex={handleRebuildIndex}
      />
      <div className="flex min-h-0 flex-1">
        <Sidebar counts={counts} active={category} onSelect={setCategory} />
        <ResultsTable
          entries={visibleEntries}
          selectedId={selectedId}
          onSelect={setSelectedId}
          sortColumn={sortColumn}
          descending={descending}
          onSort={handleSort}
        />
      </div>
      <StatusBar matchCount={visibleEntries.length} stats={stats} daemonReachable={!statusErrored} />
    </div>
  );
}
