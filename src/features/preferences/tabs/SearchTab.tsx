export function SearchTab() {
  return (
    <div className="flex flex-col gap-3 text-[13px]" style={{ color: "var(--text-secondary)" }}>
      <p>搜索框支持以下匹配方式，无需额外设置：</p>
      <ul className="flex flex-col gap-2 rounded-xl border px-4 py-3" style={{ borderColor: "var(--border)" }}>
        <li>
          <span className="font-medium" style={{ color: "var(--text-primary)" }}>子串匹配</span> —
          默认方式，不区分大小写
        </li>
        <li>
          <span className="font-medium" style={{ color: "var(--text-primary)" }}>拼音首字母</span> —
          输入「bg」即可匹配「报告.docx」
        </li>
        <li>
          <span className="font-medium" style={{ color: "var(--text-primary)" }}>正则表达式</span> —
          与 CLI 的 <code>--regex</code> 一致
        </li>
      </ul>
    </div>
  );
}
