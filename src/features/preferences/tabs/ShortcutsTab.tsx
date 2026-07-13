const SHORTCUTS = [
  { action: "打开搜索窗", keys: "⌥ Space" },
  { action: "偏好设置…", keys: "⌘ ," },
  { action: "退出 findra", keys: "⌘ Q" },
];

export function ShortcutsTab() {
  return (
    <div className="flex flex-col gap-3">
      <p className="text-[13px]" style={{ color: "var(--text-secondary)" }}>
        当前快捷键（自定义键位暂未开放）：
      </p>
      <div className="overflow-hidden rounded-xl border" style={{ borderColor: "var(--border)" }}>
        {SHORTCUTS.map(({ action, keys }) => (
          <div
            key={action}
            className="flex items-center justify-between border-b px-4 py-3 text-[13px] last:border-b-0"
            style={{ borderColor: "var(--border)" }}
          >
            <span>{action}</span>
            <span className="font-mono" style={{ color: "var(--text-muted)" }}>
              {keys}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
