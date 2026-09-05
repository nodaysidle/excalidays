import { useEffect, useRef, useState } from "react";
import {
  Excalidraw,
  MainMenu,
  loadFromBlob,
  serializeAsJSON,
} from "@excalidraw/excalidraw";
import "@excalidraw/excalidraw/index.css";
import type { ExcalidrawImperativeAPI } from "@excalidraw/excalidraw/types";
import { decodeNativeRequest, type BridgeResponse } from "./bridge";
import { EMPTY_SCENE, createNativeRequestHandler, type NativeRequestHandlerDeps } from "./handler";
import { RuntimeState } from "./runtimeState";

declare global {
  interface Window {
    EXCALIDRAW_ASSET_PATH: string;
    excalidaysReceive: (value: unknown) => Promise<BridgeResponse>;
    webkit?: {
      messageHandlers?: {
        excalidays?: { postMessage: (value: unknown) => void };
      };
    };
  }
}

function postNativeEvent(operation: string, payload: unknown): void {
  window.webkit?.messageHandlers?.excalidays?.postMessage({
    protocolVersion: 1,
    id: crypto.randomUUID(),
    kind: "event",
    operation,
    payload,
  });
}

export function CanvasRuntime(): JSX.Element {
  const [api, setAPI] = useState<ExcalidrawImperativeAPI | null>(null);
  const [theme, setTheme] = useState<"light" | "dark">(() =>
    typeof window !== "undefined" && window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light"
  );
  const initialized = useRef(false);
  const runtimeState = useRef<RuntimeState | null>(null);
  const handlerRef = useRef<ReturnType<typeof createNativeRequestHandler> | null>(null);
  // Live theme for the handler closures (the effect only re-runs on api changes).
  const themeRef = useRef(theme);
  themeRef.current = theme;

  if (!runtimeState.current) {
    runtimeState.current = new RuntimeState(EMPTY_SCENE, (isDirty) => {
      postNativeEvent("dirtyStateChanged", { isDirty });
    });
  }

  useEffect(() => {
    if (!api) {
      return;
    }

    if (!runtimeState.current) {
      runtimeState.current = new RuntimeState(EMPTY_SCENE, (isDirty) => {
        postNativeEvent("dirtyStateChanged", { isDirty });
      });
    }
    const state = runtimeState.current;
    const deps: NativeRequestHandlerDeps = {
      // ExcalidrawImperativeAPI satisfies CanvasApiLike at runtime; the cast
      // is needed because App.updateScene is generic (Pick<AppState, K>).
      api: api as unknown as NativeRequestHandlerDeps["api"],
      state,
      getTheme: () => themeRef.current,
      setTheme,
      postNativeEvent,
      setInitialized: (value: boolean) => {
        initialized.current = value;
      },
      isInitialized: () => initialized.current,
      serializeCurrentScene: () =>
        serializeAsJSON(
          api.getSceneElementsIncludingDeleted(),
          api.getAppState(),
          api.getFiles(),
          "local",
        ),
      loadSceneFromJson: (sceneJSON: string) =>
        loadFromBlob(new Blob([sceneJSON], { type: "application/json" }), null, null),
      nextFrame: () =>
        new Promise<void>((resolve) => requestAnimationFrame(() => resolve())),
    };
    const handler = createNativeRequestHandler(deps);
    handlerRef.current = handler;

    window.excalidaysReceive = async (value: unknown): Promise<BridgeResponse> => {
      const request = decodeNativeRequest(value);
      return handler.handle(request);
    };

    postNativeEvent("ready", { runtime: "excalidraw", protocolVersion: 1 });
    return () => {
      handler.dispose();
      handlerRef.current = null;
      runtimeState.current?.destroy();
      runtimeState.current = null;
      delete (window as Partial<Window>).excalidaysReceive;
    };
  }, [api]);

  return (
    <main className="canvas-host" aria-label="Drawing canvas">
      <Excalidraw
        autoFocus
        theme={theme}
        excalidrawAPI={setAPI}
        handleKeyboardGlobally={false}
        onChange={(elements, appState, files) => {
          handlerRef.current?.onSceneChange({ elements, files, appState });
        }}
        UIOptions={{
          canvasActions: {
            loadScene: false,
            saveToActiveFile: false,
            saveAsImage: false,
            export: false,
            toggleTheme: true,
          },
        }}
      >
        <MainMenu>
          <MainMenu.DefaultItems.SearchMenu />
          <MainMenu.DefaultItems.Help />
          <MainMenu.DefaultItems.ClearCanvas />
          <MainMenu.Separator />
          <MainMenu.DefaultItems.ToggleTheme />
          <MainMenu.DefaultItems.ChangeCanvasBackground />
        </MainMenu>
      </Excalidraw>
    </main>
  );
}
