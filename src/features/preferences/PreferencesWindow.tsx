import { useState } from "react";
import { AboutTab } from "./tabs/AboutTab";
import { ExcludedTab } from "./tabs/ExcludedTab";
import { GeneralTab } from "./tabs/GeneralTab";
import { SearchTab } from "./tabs/SearchTab";
import { ShortcutsTab } from "./tabs/ShortcutsTab";

const TABS = [
  { id: "general", label: "通用", Component: GeneralTab },
  { id: "search", label: "搜索", Component: SearchTab },
  { id: "excluded", label: "排除目录", Component: ExcludedTab },
  { id: "shortcuts", label: "快捷键", Component: ShortcutsTab },
  { id: "about", label: "关于", Component: AboutTab },
] as const;

export function PreferencesWindow() {
  const [activeTab, setActiveTab] = useState<(typeof TABS)[number]["id"]>("excluded");
  const Active = TABS.find((t) => t.id === activeTab)?.Component ?? GeneralTab;

  return (
    <div className="flex h-screen w-screen flex-col" style={{ background: "var(--surface-2)" }}>
      <div className="flex justify-center gap-1 border-b px-3 py-2.5" style={{ borderColor: "var(--border)" }}>
        {TABS.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className="rounded-lg px-3.5 py-1.5 text-[13px] transition-colors"
            style={{
              background: activeTab === tab.id ? "var(--surface-1)" : "transparent",
              color: activeTab === tab.id ? "var(--text-accent)" : "var(--text-secondary)",
              fontWeight: activeTab === tab.id ? 500 : 400,
            }}
          >
            {tab.label}
          </button>
        ))}
      </div>
      <div className="flex-1 overflow-y-auto px-6 py-5">
        <Active />
      </div>
    </div>
  );
}
