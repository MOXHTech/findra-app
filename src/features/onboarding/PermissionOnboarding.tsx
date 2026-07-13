import { IconBulb } from "@tabler/icons-react";
import { openUrl } from "@tauri-apps/plugin-opener";
import type { PermissionStatus } from "../../lib/bindings";

interface PlatformCopy {
  title: string;
  body: string;
  steps: string[];
  openSettings?: () => Promise<void>;
}

const COPY: Record<PermissionStatus["platform"], PlatformCopy> = {
  macos: {
    title: "findra 需要完全磁盘访问权限",
    body: "否则无法索引「用户目录」以外的文件位置，搜索结果会不完整。此权限授予的是后台索引组件，不是 App 图标本身。",
    steps: [
      "打开系统设置 → 隐私与安全性",
      "选择「完全磁盘访问权限」",
      "勾选「findra-daemon」并输入密码确认",
    ],
    openSettings: () => openUrl("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"),
  },
  windows: {
    title: "findra 需要管理员权限",
    body: "后台索引组件需要以管理员身份启动才能开启实时文件变更监听（ETW）。这个权限授予的是索引服务，不是 App 图标本身。",
    steps: ["右键点击 findra-daemon 或 findra.exe", "选择「以管理员身份运行」", "在用户账户控制对话框中确认"],
  },
  linux: {
    title: "findra 需要额外权限",
    body: "后台索引组件需要 CAP_BPF/CAP_PERFMON 权限（或 root）才能开启实时文件变更监听。未授权时会降级为周期性扫描。",
    steps: [
      "在终端中为 findra-daemon 授予能力：",
      "sudo setcap cap_bpf,cap_perfmon+ep $(which findra-daemon)",
      "重新启动 findra 守护进程",
    ],
  },
};

export function PermissionOnboarding({
  status,
  onSkip,
}: {
  status: PermissionStatus;
  onSkip: () => void;
}) {
  const copy = COPY[status.platform];

  return (
    <div
      className="flex h-screen w-screen items-center justify-center"
      style={{ background: "var(--surface-1)" }}
    >
      <div
        className="mx-6 flex w-full max-w-md flex-col items-center gap-5 rounded-2xl border p-8"
        style={{ background: "var(--surface-2)", borderColor: "var(--border)" }}
      >
        <div
          className="flex h-14 w-14 items-center justify-center rounded-2xl"
          style={{ background: "var(--bg-accent)" }}
        >
          <IconBulb size={26} style={{ color: "var(--text-accent)" }} />
        </div>

        <div className="text-center">
          <h1 className="text-[17px] font-semibold" style={{ color: "var(--text-primary)" }}>
            {copy.title}
          </h1>
          <p className="mt-2 text-[13px] leading-relaxed" style={{ color: "var(--text-secondary)" }}>
            {copy.body}
          </p>
        </div>

        <ol
          className="flex w-full flex-col gap-3 rounded-xl px-4 py-3.5"
          style={{ background: "var(--surface-1)" }}
        >
          {copy.steps.map((step, i) => (
            <li key={i} className="flex items-start gap-3 text-[13px]" style={{ color: "var(--text-primary)" }}>
              <span
                className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-[11px] font-medium"
                style={{ background: "var(--border)", color: "var(--text-secondary)" }}
              >
                {i + 1}
              </span>
              <span className={step.includes("setcap") ? "font-mono text-[12px]" : ""}>{step}</span>
            </li>
          ))}
        </ol>

        {copy.openSettings && (
          <button
            onClick={() => copy.openSettings?.()}
            className="w-full rounded-lg py-2.5 text-[13px] font-medium text-white transition-opacity hover:opacity-90"
            style={{ background: "var(--text-primary)" }}
          >
            打开系统设置
          </button>
        )}

        <button onClick={onSkip} className="text-[12px]" style={{ color: "var(--text-muted)" }}>
          稍后设置 · 部分搜索结果可能不完整
        </button>
      </div>
    </div>
  );
}
