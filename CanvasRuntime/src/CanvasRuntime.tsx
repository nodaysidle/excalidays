import { useEffect, useRef, useState } from "react";
import {
  CaptureUpdateAction,
  Excalidraw,
  MainMenu,
  loadFromBlob,
  serializeAsJSON,
} from "@excalidraw/excalidraw";
import "@excalidraw/excalidraw/index.css";
import type { ExcalidrawImperativeAPI } from "@excalidraw/excalidraw/types";
import { decodeNativeRequest, makeResponse, type BridgeResponse } from "./bridge";
import { RuntimeState } from "./runtimeState";

const EMPTY_SCENE = JSON.stringify({
  type: "excalidraw",
  version: 2,
  source: "excalidays",
  elements: [],
  appState: { viewBackgroundColor: "#ffffff" },
  files: {},
});

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


  if (!runtimeState.current) {
    runtimeState.current = new RuntimeState(EMPTY_SCENE, () => {
      postNativeEvent("dirtyStateChanged", { isDirty: true });
    });
  }

  useEffect(() => {
    if (!api) {
      return;
    }

    if (!runtimeState.current) {
      runtimeState.current = new RuntimeState(EMPTY_SCENE, () => {
        postNativeEvent("dirtyStateChanged", { isDirty: true });
      });
    }
    const state = runtimeState.current;

    window.excalidaysReceive = async (value: unknown): Promise<BridgeResponse> => {
      const request = decodeNativeRequest(value);
      switch (request.operation) {
        case "initialize":
        case "loadScene": {
          initialized.current = false;
          const payload = request.payload as { sceneJSON?: string; theme?: "light" | "dark" };
          const activeTheme = payload.theme ?? theme;
          if (payload.theme && payload.theme !== theme) {
            setTheme(payload.theme);
          }
          let sceneJSON = payload.sceneJSON ?? EMPTY_SCENE;
          try {
            const parsed = JSON.parse(sceneJSON);
            const isDark = activeTheme === "dark";
            // For a brand new empty canvas, harmonize with system appearance
            if (
              Array.isArray(parsed.elements) &&
              parsed.elements.length === 0 &&
              isDark &&
              (!parsed.appState?.viewBackgroundColor || parsed.appState?.viewBackgroundColor === "#ffffff")
            ) {
              parsed.appState = {
                ...parsed.appState,
                viewBackgroundColor: "#121212",
                currentItemStrokeColor: "#ffffff",
              };
              sceneJSON = JSON.stringify(parsed);
            }
          } catch {
            // retain original
          }
          const restored = await loadFromBlob(new Blob([sceneJSON], { type: "application/json" }), null, null);
          state.replaceSourceScene(sceneJSON);
          api.updateScene({
            elements: restored.elements,
            appState: {
              ...restored.appState,
              theme: activeTheme,
            },
            captureUpdate: CaptureUpdateAction.NEVER,
          });
          if (restored.files) {
            api.addFiles(Object.values(restored.files));
          }
          api.history.clear();
          await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
          state.setCleanScene(serializeAsJSON(
            api.getSceneElementsIncludingDeleted(),
            api.getAppState(),
            api.getFiles(),
            "local",
          ));
          initialized.current = true;
          return makeResponse(request.id, request.operation, { loaded: true });
        }
        case "requestSnapshot": {
          const serialized = serializeAsJSON(
            api.getSceneElementsIncludingDeleted(),
            api.getAppState(),
            api.getFiles(),
            "local",
          );
          return makeResponse(request.id, request.operation, {
            sceneJSON: state.snapshot(serialized),
          });
        }
        case "updateTheme": {
          const payload = request.payload as { theme?: "light" | "dark" };
          api.updateScene({ appState: { theme: payload.theme ?? "light" } });
          return makeResponse(request.id, request.operation, { updated: true });
        }
        case "performCommand": {
          const payload = request.payload as { command?: string };
          const redo = payload.command === "redo";
          const event = new KeyboardEvent("keydown", {
            key: "z",
            code: "KeyZ",
            metaKey: true,
            shiftKey: redo,
            bubbles: true,
            cancelable: true,
          });
          const target = document.querySelector<HTMLElement>(".excalidraw") ?? document.body;
          target.dispatchEvent(event);
          window.dispatchEvent(event);
          return makeResponse(request.id, request.operation, { performed: payload.command });
        }
        case "zoomToFit":
          api.scrollToContent(api.getSceneElements(), { fitToViewport: true, animate: false });
          return makeResponse(request.id, request.operation, { performed: true });
        case "focusCanvas":
          document.querySelector<HTMLElement>(".excalidraw")?.focus();
          return makeResponse(request.id, request.operation, { performed: true });
        case "updateTheme": {
          const payload = request.payload as { theme?: "light" | "dark" };
          if (payload.theme === "light" || payload.theme === "dark") {
            setTheme(payload.theme);
          }
          return makeResponse(request.id, request.operation, { theme: payload.theme ?? theme });
        }
        case "setReadOnly": {
          const payload = request.payload as { readOnly?: boolean };
          api.updateScene({ appState: { viewModeEnabled: payload.readOnly === true } });
          return makeResponse(request.id, request.operation, { performed: true });
        }
        default:
          throw new Error(`Operation ${request.operation} is not implemented in Phase 1`);
      }
    };

    postNativeEvent("ready", { runtime: "excalidraw", protocolVersion: 1 });
    return () => {
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
          if (appState.theme && appState.theme !== theme) {
            setTheme(appState.theme);
          }
          if (initialized.current && runtimeState.current) {
            runtimeState.current.markDirtyIfChanged(serializeAsJSON(elements, appState, files, "local"));
          }
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
