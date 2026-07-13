// Thin ergonomic wrapper over `./bindings.ts` (generated straight from the
// Rust command signatures - see src-tauri/src/commands.rs's doc comment).
// Tauri-specta's generated `commands.*` return a `Result<T, string>`
// discriminated union rather than throwing, which is the right default for
// a codegen'd file but awkward to consume from React Query (which wants a
// promise that rejects on failure). This unwraps that union into a plain
// throwing async function per command - the *only* hand-written layer
// between the UI and the daemon, and it does no data shaping of its own.
import { commands } from "./bindings";
import type { FileEntry, IndexStats, PermissionStatus, SearchQuery, VersionCompat } from "./bindings";

function unwrap<T>(result: { status: "ok"; data: T } | { status: "error"; error: string }): T {
  if (result.status === "error") {
    throw new Error(result.error);
  }
  return result.data;
}

export const ipc = {
  search: async (query: SearchQuery): Promise<FileEntry[]> => unwrap(await commands.search(query)),
  status: async (): Promise<IndexStats> => unwrap(await commands.status()),
  rebuildIndex: async (path: string): Promise<void> => {
    unwrap(await commands.rebuildIndex(path));
  },
  checkPermission: async (): Promise<PermissionStatus> => commands.checkPermission(),
  ensureDaemon: async (): Promise<void> => {
    unwrap(await commands.ensureDaemon());
  },
  getPlatform: async (): Promise<string> => commands.getPlatform(),
  checkProtocolVersion: async (): Promise<VersionCompat> => unwrap(await commands.checkProtocolVersion()),
};

export type { FileEntry, IndexStats, PermissionStatus, SearchQuery, VersionCompat } from "./bindings";

/** Matches the Rust side's own `Default for SearchQuery` (findra-protocol/src/types.rs). */
export function defaultSearchQuery(pattern: string): SearchQuery {
  return {
    pattern,
    regex: false,
    case_sensitive: false,
    pinyin: false,
    extensions: [],
    min_size: null,
    max_size: null,
    path_filter: null,
    sort_by: "Name",
    descending: false,
    limit: 200,
  };
}
