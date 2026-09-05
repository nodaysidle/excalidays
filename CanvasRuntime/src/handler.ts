import type { BridgeResponse, NativeRequest } from "./bridge";
import { makeResponse } from "./bridge";
import { computePersistentSignature, RuntimeState } from "./runtimeState";

/**
 * Canonical empty scene used when a request arrives without sceneJSON and as
 * the initial runtime-state baseline.
 */
export const EMPTY_SCENE = JSON.stringify({
  type: "excalidraw",
  version: 2,
  source: "excalidays",
  elements: [],
  appState: { viewBackgroundColor: "#ffffff" },
  files: {},
});

export type Theme = "light" | "dark";

/** Structural subset of ExcalidrawImperativeAPI used by native requests. */
export interface CanvasApiLike {
  updateScene(options: {
    elements?: readonly unknown[];
    appState?: object | null;
    captureUpdate?: string;
  }): void;
  addFiles(files: unknown[]): void;
  history: { clear(): void };
  getSceneElements(): readonly unknown[];
  scrollToContent(elements: readonly unknown[], options: { fitToViewport?: boolean; animate?: boolean }): void;
}

export interface SceneRestoreResult {
  elements: unknown[];
  appState: object;
  files?: Record<string, unknown>;
}

export interface NativeRequestHandlerDeps {
  /** Live Excalidraw imperative API (set after the editor mounts). */
  api: CanvasApiLike;
  /** RuntimeState owning the dirty flag / clean baseline / unknown-field preservation. */
  state: RuntimeState;
  /** Serializes the CURRENT editor scene (elements incl. deleted, appState, files). Heavy — sanctioned on load/snapshot only. */
  serializeCurrentScene(): string;
  /** Restores a scene JSON blob into elements/appState/files (loadFromBlob). */
  loadSceneFromJson(sceneJSON: string): Promise<SceneRestoreResult>;
  /** Resolves after the editor has applied a loadScene updateScene (requestAnimationFrame bridge). */
  nextFrame(): Promise<void>;
  getTheme(): Theme;
  setTheme(theme: Theme): void;
  setInitialized(initialized: boolean): void;
  isInitialized(): boolean;
  /** Emits a native bridge event (dirtyStateChanged / commandStateChanged). */
  postNativeEvent(operation: string, payload: unknown): void;
}

export interface SceneChangeInput {
  elements: readonly unknown[];
  files: Record<string, unknown>;
  appState: object;
}

export interface NativeRequestHandler {
  handle(request: NativeRequest): Promise<BridgeResponse>;
  /** Wired to the Excalidraw onChange prop. */
  onSceneChange(input: SceneChangeInput): void;
  dispose(): void;
}

function isTheme(value: unknown): value is Theme {
  return value === "light" || value === "dark";
}

/**
 * Bridge event payload contract (cross-lane, mirrors the Swift consumer):
 *   dirtyStateChanged   -> { isDirty: boolean }
 *   commandStateChanged -> { canUndo: boolean, canRedo: boolean }
 * dirtyStateChanged emissions happen inside RuntimeState transitions
 * (constructor callback) — this handler only emits commandStateChanged.
 */

/**
 * canUndo/canRedo signal selection (Excalidraw 0.18.1):
 * api.history only exposes { clear } — History.isUndoStackEmpty/isRedoStackEmpty
 * and onHistoryChangedEmitter are internal, and history.getCurrentEntry() does
 * not exist in 0.18.1. Therefore:
 *   - canUndo is derived from the bidirectional dirty state: the history stack
 *     is empty exactly at the clean baseline, so "not clean" == "undoable".
 *     Documented limitations: a snapshot re-baselines the scene while the
 *     editor's undo stack still holds pre-snapshot entries (canUndo reads
 *     false until the next edit), and a net-zero edit sequence (add + delete
 *     back to baseline) is reported as not undoable even though the editor
 *     could still pop those entries.
 *   - canRedo is a tracked flag: true only after a bridge-dispatched undo
 *     actually moved the scene; cleared on the next moved edit or a
 *     successful redo. In-app cmd+z/cmd+shift+z (editor-local, not routed
 *     through the bridge) do not set/clear it — native undo/redo is driven
 *     through performCommand by design. No public canRedo peek exists.
 */
export function createNativeRequestHandler(deps: NativeRequestHandlerDeps): NativeRequestHandler {
  let lastCommandState: { canUndo: boolean; canRedo: boolean } | null = null;
  let lastSceneSignature: string | null = null;
  let canRedo = false;
  let pendingUndo = false;
  let pendingRedo = false;
  let clearFlagsTimer: ReturnType<typeof setTimeout> | null = null;
  let disposed = false;

  function emitCommandState(): void {
    if (disposed) {
      return;
    }
    const next = { canUndo: deps.state.isDirty(), canRedo };
    if (
      lastCommandState === null ||
      lastCommandState.canUndo !== next.canUndo ||
      lastCommandState.canRedo !== next.canRedo
    ) {
      lastCommandState = next;
      deps.postNativeEvent("commandStateChanged", next);
    }
  }

  function clearPendingFlags(): void {
    pendingUndo = false;
    pendingRedo = false;
  }

  function dispatchHistoryShortcut(redo: boolean): void {
    if (redo) {
      pendingRedo = true;
    } else {
      pendingUndo = true;
    }
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
    // The editor processes discrete keydowns synchronously (undo/redo action
    // + store commit), so onSceneChange below normally consumes the pending
    // flag within this call stack. If nothing moved (empty stack no-op), drop
    // the flag on the next tick so a later unrelated edit cannot inherit it.
    if (clearFlagsTimer !== null) {
      clearTimeout(clearFlagsTimer);
    }
    clearFlagsTimer = setTimeout(() => {
      clearFlagsTimer = null;
      if (disposed) {
        return;
      }
      if (pendingUndo || pendingRedo) {
        clearPendingFlags();
      }
    }, 0);
  }

  function loadScene(request: NativeRequest, sceneJSON: string, activeTheme: Theme): Promise<BridgeResponse> {
    deps.setInitialized(false);
    let payloadScene = sceneJSON;
    try {
      const parsed = JSON.parse(sceneJSON) as {
        elements?: unknown[];
        appState?: { viewBackgroundColor?: string } & Record<string, unknown>;
      };
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
        payloadScene = JSON.stringify(parsed);
      }
    } catch {
      // retain original
    }
    return deps
      .loadSceneFromJson(payloadScene)
      .then(async (restored) => {
        // Baseline from the SAME (possibly harmonized) JSON the editor was
        // given, so the clean signature matches the editor's actual scene.
        deps.state.replaceSourceScene(payloadScene);
        deps.api.updateScene({
          elements: restored.elements,
          appState: { ...(restored.appState as object), theme: activeTheme },
          captureUpdate: "NEVER",
        });
        if (restored.files) {
          deps.api.addFiles(Object.values(restored.files));
        }
        deps.api.history.clear();
        await deps.nextFrame();
        deps.state.setCleanScene(deps.serializeCurrentScene());
        deps.setInitialized(true);
        // Publish the initial (canUndo:false, canRedo:false) reading.
        emitCommandState();
        return makeResponse(request.id, request.operation, { loaded: true });
      })
      .catch((error: unknown) => {
        deps.setInitialized(false);
        throw error;
      });
  }

  async function handle(request: NativeRequest): Promise<BridgeResponse> {
    switch (request.operation) {
      case "initialize":
      case "loadScene": {
        const payload = (request.payload ?? {}) as { sceneJSON?: unknown; theme?: unknown };
        const requestedTheme = payload.theme;
        const activeTheme: Theme = isTheme(requestedTheme) ? requestedTheme : deps.getTheme();
        if (isTheme(requestedTheme) && requestedTheme !== deps.getTheme()) {
          deps.setTheme(requestedTheme);
        }
        const sceneJSON = payload.sceneJSON ?? EMPTY_SCENE;
        if (typeof sceneJSON !== "string") {
          throw new Error(
            `Malformed ${request.operation} payload: sceneJSON must be a string when provided`,
          );
        }
        return loadScene(request, sceneJSON, activeTheme);
      }
      case "requestSnapshot": {
        const serialized = deps.serializeCurrentScene();
        // state.snapshot re-baselines; if we were dirty it emits
        // dirtyStateChanged { isDirty:false } through its own callback.
        const sceneJSON = deps.state.snapshot(serialized);
        // canUndo follows the clean baseline, so publish the flip.
        emitCommandState();
        return makeResponse(request.id, request.operation, { sceneJSON });
      }
      case "updateTheme": {
        // Single handler: syncs BOTH the Excalidraw scene theme and the React
        // theme state (previously split across two case labels; the second was
        // unreachable duplicate — caught by the no-duplicate-case lint rule).
        const payload = (request.payload ?? {}) as { theme?: unknown };
        const nextTheme: Theme = payload.theme === "dark" ? "dark" : "light";
        deps.setTheme(nextTheme);
        deps.api.updateScene({ appState: { theme: nextTheme } });
        return makeResponse(request.id, request.operation, { updated: true });
      }
      case "performCommand": {
        const payload = (request.payload ?? {}) as { command?: unknown };
        const command = payload.command;
        if (command !== "undo" && command !== "redo") {
          throw new Error(
            `Malformed performCommand payload: expected command "undo" or "redo", got ${JSON.stringify(command)}`,
          );
        }
        dispatchHistoryShortcut(command === "redo");
        return makeResponse(request.id, request.operation, { performed: command });
      }
      case "zoomToFit":
        deps.api.scrollToContent(deps.api.getSceneElements(), { fitToViewport: true, animate: false });
        return makeResponse(request.id, request.operation, { performed: true });
      case "focusCanvas":
        document.querySelector<HTMLElement>(".excalidraw")?.focus();
        return makeResponse(request.id, request.operation, { performed: true });
      case "setReadOnly": {
        const payload = (request.payload ?? {}) as { readOnly?: unknown };
        deps.api.updateScene({ appState: { viewModeEnabled: payload.readOnly === true } });
        return makeResponse(request.id, request.operation, { performed: true });
      }
      default:
        throw new Error(`Operation ${request.operation} is not implemented in Phase 1`);
    }
  }

  function onSceneChange(input: SceneChangeInput): void {
    if (disposed) {
      return;
    }
    const { elements, files, appState } = input;
    const editorTheme = (appState as { theme?: unknown }).theme;
    if (isTheme(editorTheme) && editorTheme !== deps.getTheme()) {
      deps.setTheme(editorTheme);
    }
    if (!deps.isInitialized()) {
      return;
    }
    const signature = computePersistentSignature(elements, files, appState);
    const moved = signature !== lastSceneSignature;
    lastSceneSignature = signature;
    // May emit dirtyStateChanged { isDirty:true } on edit or { isDirty:false }
    // on undo back to the clean baseline.
    deps.state.markDirtyIfChanged(signature);
    if (!moved) {
      return;
    }
    if (pendingUndo) {
      // An undo actually moved the scene: redo is available until the next edit.
      canRedo = true;
      clearPendingFlags();
    } else if (pendingRedo) {
      canRedo = false;
      clearPendingFlags();
    } else {
      // A fresh edit clears the redo stack (mirrors History.record).
      canRedo = false;
    }
    emitCommandState();
  }

  function dispose(): void {
    disposed = true;
    if (clearFlagsTimer !== null) {
      clearTimeout(clearFlagsTimer);
      clearFlagsTimer = null;
    }
  }

  return { handle, onSceneChange, dispose };
}
