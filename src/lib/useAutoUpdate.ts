import { relaunch } from "@tauri-apps/plugin-process";
import { check, type Update } from "@tauri-apps/plugin-updater";
import { useEffect, useState } from "react";

/**
 * Checks for an update once per app launch, downloads it in the background
 * if found, and reports back once it's ready - the actual relaunch is left
 * to the caller (a banner button) rather than done automatically, since
 * silently restarting a search tool out from under someone mid-use would
 * be the opposite of "smooth". Errors (no network, endpoint unreachable)
 * are swallowed: update-checking is best-effort background maintenance,
 * never something that should surface as an error to a user who didn't
 * ask for it.
 */
export function useAutoUpdate() {
  const [pendingUpdate, setPendingUpdate] = useState<Update | null>(null);

  useEffect(() => {
    let cancelled = false;

    check()
      .then(async (update) => {
        if (!update || cancelled) return;
        await update.download();
        if (!cancelled) setPendingUpdate(update);
      })
      .catch(() => {
        // No update server reachable, or this build has no valid pubkey
        // configured yet - not actionable by the user, nothing to show.
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return {
    updateVersion: pendingUpdate?.version,
    applyUpdate: async () => {
      if (!pendingUpdate) return;
      await pendingUpdate.install();
      await relaunch();
    },
  };
}
