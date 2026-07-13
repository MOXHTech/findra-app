import type { IndexStats } from "../../lib/bindings";
import { formatRelativeSeconds } from "../../lib/format";

export function StatusBar({
  matchCount,
  stats,
  daemonReachable,
}: {
  matchCount: number;
  stats: IndexStats | undefined;
  daemonReachable: boolean;
}) {
  const secondsAgo = stats ? Math.max(0, Math.floor(Date.now() / 1000) - stats.last_sync) : 0;

  return (
    <div
      className="flex shrink-0 items-center justify-between border-t px-3 py-1.5 text-[11px]"
      style={{ borderColor: "var(--border)", background: "var(--surface-1)", color: "var(--text-muted)" }}
    >
      <span>
        {matchCount.toLocaleString()} 项匹配
        {stats && <> · 索引 {stats.total_files.toLocaleString()} 个文件</>}
        {stats && <> · {formatRelativeSeconds(secondsAgo)}更新</>}
      </span>
      <span className="flex items-center gap-1.5" style={{ color: daemonReachable ? "var(--text-success)" : "var(--text-muted)" }}>
        <span
          className="inline-block h-1.5 w-1.5 rounded-full"
          style={{ background: daemonReachable ? "var(--fill-success)" : "var(--text-muted)" }}
        />
        {daemonReachable ? "daemon 运行中" : "daemon 未连接"}
      </span>
    </div>
  );
}
