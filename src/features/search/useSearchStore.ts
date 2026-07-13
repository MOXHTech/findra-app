import { create } from "zustand";
import type { FileCategory } from "../../lib/fileType";

export type SortColumn = "name" | "path" | "size" | "ctime" | "mtime";

interface SearchState {
  query: string;
  category: FileCategory | "all";
  sortColumn: SortColumn;
  descending: boolean;
  setQuery: (query: string) => void;
  setCategory: (category: FileCategory | "all") => void;
  toggleSort: (column: SortColumn) => void;
}

export const useSearchStore = create<SearchState>((set, get) => ({
  query: "",
  category: "all",
  sortColumn: "mtime",
  descending: true,
  setQuery: (query) => set({ query }),
  setCategory: (category) => set({ category }),
  toggleSort: (column) => {
    const { sortColumn, descending } = get();
    if (sortColumn === column) {
      set({ descending: !descending });
    } else {
      set({ sortColumn: column, descending: true });
    }
  },
}));
