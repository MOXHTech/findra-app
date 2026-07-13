import { IconFolder, IconPlus, IconX } from "@tabler/icons-react";
import { open } from "@tauri-apps/plugin-dialog";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { commands } from "../../../lib/bindings";

function unwrap<T>(result: { status: "ok"; data: T } | { status: "error"; error: string }): T {
  if (result.status === "error") throw new Error(result.error);
  return result.data;
}

export function ExcludedTab() {
  const queryClient = useQueryClient();
  const { data: paths = [] } = useQuery({
    queryKey: ["excluded-paths"],
    queryFn: async () => unwrap(await commands.getExcludedPaths()),
  });

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ["excluded-paths"] });

  const addMutation = useMutation({
    mutationFn: async (path: string) => unwrap(await commands.addExcludedPath(path)),
    onSuccess: invalidate,
  });
  const removeMutation = useMutation({
    mutationFn: async (path: string) => unwrap(await commands.removeExcludedPath(path)),
    onSuccess: invalidate,
  });
  const restartMutation = useMutation({
    mutationFn: async () => unwrap(await commands.restartDaemon()),
  });

  const handleAddDirectory = async () => {
    const selected = await open({ directory: true, multiple: false });
    if (typeof selected === "string") {
      addMutation.mutate(selected);
    }
  };

  return (
    <div className="flex flex-col gap-3">
      <p className="text-[13px]" style={{ color: "var(--text-secondary)" }}>
        以下目录不会被索引，也不会出现在搜索结果中。
      </p>

      <div className="overflow-hidden rounded-xl border" style={{ borderColor: "var(--border)" }}>
        {paths.map((path) => (
          <div
            key={path}
            className="flex items-center gap-3 border-b px-4 py-3 text-[13px] last:border-b-0"
            style={{ borderColor: "var(--border)" }}
          >
            <IconFolder size={17} style={{ color: "var(--text-muted)" }} />
            <span className="flex-1 truncate">{path}</span>
            <button
              onClick={() => removeMutation.mutate(path)}
              style={{ color: "var(--text-muted)" }}
              aria-label={`移除 ${path}`}
            >
              <IconX size={15} />
            </button>
          </div>
        ))}
        <button
          onClick={handleAddDirectory}
          className="flex w-full items-center gap-2 px-4 py-3 text-[13px]"
          style={{ color: "var(--text-accent)" }}
        >
          <IconPlus size={16} />
          添加目录…
        </button>
      </div>

      <div className="flex items-center justify-between pt-1">
        <span className="text-[12px]" style={{ color: "var(--text-muted)" }}>
          更改需要重启 daemon 才能生效
        </span>
        <button
          onClick={() => restartMutation.mutate()}
          disabled={restartMutation.isPending}
          className="rounded-md border px-3 py-1.5 text-[12px]"
          style={{ borderColor: "var(--border)", color: "var(--text-primary)" }}
        >
          {restartMutation.isPending ? "重启中…" : "重启 daemon"}
        </button>
      </div>
    </div>
  );
}
