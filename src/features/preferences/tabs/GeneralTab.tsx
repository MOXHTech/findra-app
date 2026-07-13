import { disable, enable, isEnabled } from "@tauri-apps/plugin-autostart";
import { useEffect, useState } from "react";

export function GeneralTab() {
  const [autostart, setAutostart] = useState<boolean | null>(null);

  useEffect(() => {
    isEnabled().then(setAutostart).catch(() => setAutostart(false));
  }, []);

  const toggleAutostart = async () => {
    if (autostart) {
      await disable();
      setAutostart(false);
    } else {
      await enable();
      setAutostart(true);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <label className="flex items-center justify-between rounded-xl border px-4 py-3" style={{ borderColor: "var(--border)" }}>
        <div>
          <div className="text-[13px] font-medium">开机自动启动</div>
          <div className="text-[12px]" style={{ color: "var(--text-muted)" }}>
            登录后自动在菜单栏/系统托盘启动 findra
          </div>
        </div>
        <input
          type="checkbox"
          checked={autostart ?? false}
          onChange={toggleAutostart}
          disabled={autostart === null}
          className="h-4 w-4"
        />
      </label>
    </div>
  );
}
