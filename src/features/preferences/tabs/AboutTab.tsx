import { useQuery } from "@tanstack/react-query";
import { ipc } from "../../../lib/ipc";

export function AboutTab() {
  const { data: platform } = useQuery({ queryKey: ["platform"], queryFn: () => ipc.getPlatform() });
  const { data: versionCompat } = useQuery({
    queryKey: ["protocol-version"],
    queryFn: () => ipc.checkProtocolVersion(),
    retry: false,
  });

  const versionLine = (() => {
    if (!versionCompat) return "检查中…";
    switch (versionCompat.kind) {
      case "Match":
        return "协议版本与 daemon 一致";
      case "Unknown":
        return "daemon 版本较旧，无法确认协议兼容性";
      case "Mismatch":
        return `协议版本不匹配（App ${versionCompat.app} / daemon ${versionCompat.daemon}）`;
    }
  })();

  return (
    <div className="flex flex-col gap-3 text-[13px]">
      <div className="rounded-xl border px-4 py-3" style={{ borderColor: "var(--border)" }}>
        <div className="flex justify-between py-1">
          <span style={{ color: "var(--text-muted)" }}>App 版本</span>
          <span>0.1.0</span>
        </div>
        <div className="flex justify-between py-1">
          <span style={{ color: "var(--text-muted)" }}>平台</span>
          <span>{platform ?? "…"}</span>
        </div>
        <div className="flex justify-between py-1">
          <span style={{ color: "var(--text-muted)" }}>协议状态</span>
          <span>{versionLine}</span>
        </div>
      </div>
      <p style={{ color: "var(--text-muted)" }}>
        findra 是 CLI 核心引擎的图形化前端，与 CLI 共享同一个后台守护进程与索引。
      </p>
    </div>
  );
}
