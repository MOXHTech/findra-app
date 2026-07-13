import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { PermissionOnboarding } from "./features/onboarding/PermissionOnboarding";
import { SearchWindow } from "./features/search/SearchWindow";
import { ipc } from "./lib/ipc";
import { commands } from "./lib/bindings";

export default function App() {
  const [skippedOnboarding, setSkippedOnboarding] = useState(false);
  const { data: permission } = useQuery({
    queryKey: ["permission"],
    queryFn: () => ipc.checkPermission(),
    refetchInterval: 5000,
  });

  const needsOnboarding = permission && !permission.granted && !skippedOnboarding;

  if (needsOnboarding && permission) {
    return <PermissionOnboarding status={permission} onSkip={() => setSkippedOnboarding(true)} />;
  }

  return <SearchWindow onOpenPreferences={() => commands.openPreferences()} />;
}
