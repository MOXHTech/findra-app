export function formatBytes(bytes: number): string {
  if (bytes === 0) return "—";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let size = bytes;
  let unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  return `${size.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
}

/**
 * `mtime`/`ctime`/`last_sync` are unix seconds (see findra-protocol's
 * FileEntry/IndexStats). `ctime` is `#[serde(default)]` on the Rust side
 * (older/foreign daemon builds may omit it), which specta reflects as an
 * optional TS field - treated the same as 0/missing here.
 */
export function formatTimestamp(unixSeconds: number | undefined): string {
  if (!unixSeconds) return "—";
  const d = new Date(unixSeconds * 1000);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function formatRelativeSeconds(secondsAgo: number): string {
  if (secondsAgo < 2) return "刚刚";
  if (secondsAgo < 60) return `${Math.floor(secondsAgo)} 秒前`;
  if (secondsAgo < 3600) return `${Math.floor(secondsAgo / 60)} 分钟前`;
  return `${Math.floor(secondsAgo / 3600)} 小时前`;
}
