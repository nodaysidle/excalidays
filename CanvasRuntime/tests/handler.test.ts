// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi, type Mock } from "vitest";
import type { NativeOperation } from "../src/bridge";
import { createNativeRequestHandler, EMPTY_SCENE, type NativeRequestHandlerDeps } from "../src/handler";
import { RuntimeState } from "../src/runtimeState";

afterEach(() => {
  document.body.innerHTML = "";
});

const rectV1 = { id: "rectangle-1", type: "rectangle", version: 1, versionNonce: 7, x: 0, y: 0 };
const emptyFiles = {};
const whiteAppState = { viewBackgroundColor: "#ffffff" };

interface Harness {
  deps: NativeRequestHandlerDeps;
  handler: ReturnType<typeof createNativeRequestHandler>;
  api: {
    updateScene: Mock;
    addFiles: Mock;
    history: { clear: Mock };
    getSceneElements: Mock;
    scrollToContent: Mock;
  };
  postNativeEvent: Mock;
  setTheme: Mock;
  state: RuntimeState;
  theme: "light" | "dark";
  loadSceneFromJson: Mock;
  serializeCurrentScene: Mock;
  notify: Mock;
}

function makeHarness(sceneJSON = EMPTY_SCENE, theme: "light" | "dark" = "light"): Harness {
  const notify = vi.fn();
  const postNativeEvent = vi.fn();
  let initialized = false;
  const state = new RuntimeState(sceneJSON, (isDirty) => {
    postNativeEvent("dirtyStateChanged", { isDirty });
  });
  const api = {
    updateScene: vi.fn(),
    addFiles: vi.fn(),
    history: { clear: vi.fn() },
    getSceneElements: vi.fn(() => []),
    scrollToContent: vi.fn(),
  };
  let currentTheme = theme;
  const setTheme = vi.fn((next: "light" | "dark") => {
    currentTheme = next;
  });
  const loadSceneFromJson = vi.fn(async (json: string) => {
    const parsed = JSON.parse(json) as { elements: unknown[]; appState: object; files?: Record<string, unknown> };
    return { elements: parsed.elements, appState: parsed.appState, files: parsed.files };
  });
  const serializeCurrentScene = vi.fn(() =>
    JSON.stringify({ type: "excalidraw", version: 2, source: "local", elements: [], appState: {}, files: {} }),
  );
  const deps: NativeRequestHandlerDeps = {
    api,
    state,
    getTheme: () => currentTheme,
    setTheme,
    postNativeEvent,
    setInitialized: (value: boolean) => {
      initialized = value;
    },
    isInitialized: () => initialized,
    serializeCurrentScene,
    loadSceneFromJson,
    nextFrame: async () => undefined,
  };
  return { deps, handler: createNativeRequestHandler(deps), api, postNativeEvent, setTheme, state, theme, loadSceneFromJson, serializeCurrentScene, notify };
}

function request(operation: NativeOperation, payload: unknown, id = "request-1") {
  return { protocolVersion: 1 as const, id, kind: "request" as const, operation, payload };
}

describe("native request handler", () => {
  describe("loadScene / initialize", () => {
    it("harmonizes a dark empty canvas to the dark background + light stroke", async () => {
      const h = makeHarness(undefined, "light");
      const response = await h.handler.handle(request("loadScene", { sceneJSON: EMPTY_SCENE, theme: "dark" }));

      expect(response).toMatchObject({ kind: "response", operation: "loadScene", payload: { loaded: true } });
      expect(h.setTheme).toHaveBeenCalledWith("dark");
      const restoredScene = JSON.parse(h.loadSceneFromJson.mock.calls[0][0] as string);
      expect(restoredScene.appState.viewBackgroundColor).toBe("#121212");
      expect(restoredScene.appState.currentItemStrokeColor).toBe("#ffffff");
      expect(h.api.updateScene).toHaveBeenCalledWith(
        expect.objectContaining({
          appState: expect.objectContaining({ theme: "dark", viewBackgroundColor: "#121212" }),
          captureUpdate: "NEVER",
        }),
      );
      // Clean baseline published: initial (false, false) command state
      expect(h.postNativeEvent).toHaveBeenCalledWith("commandStateChanged", { canUndo: false, canRedo: false });
      expect(h.deps.isInitialized()).toBe(true);
    });

    it("does NOT harmonize a light or a non-empty dark canvas", async () => {
      const h = makeHarness(undefined, "dark");
      await h.handler.handle(request("loadScene", { sceneJSON: EMPTY_SCENE, theme: "light" }));
      let scene = JSON.parse(h.loadSceneFromJson.mock.calls[0][0] as string);
      expect(scene.appState.viewBackgroundColor).toBe("#ffffff");

      const nonEmpty = JSON.stringify({
        type: "excalidraw",
        version: 2,
        elements: [rectV1],
        appState: { viewBackgroundColor: "#ffffff" },
        files: {},
      });
      await h.handler.handle(request("loadScene", { sceneJSON: nonEmpty, theme: "dark" }));
      scene = JSON.parse(h.loadSceneFromJson.mock.calls[1][0] as string);
      expect(scene.appState.viewBackgroundColor).toBe("#ffffff");
    });

    it("loads files, clears history, and re-baselines the clean scene", async () => {
      const h = makeHarness();
      const sceneJSON = JSON.stringify({
        type: "excalidraw",
        version: 2,
        elements: [rectV1],
        appState: { viewBackgroundColor: "#ffffff" },
        files: { image1: { id: "image1", dataURL: "data:image/png;base64,AA==" } },
      });
      await h.handler.handle(request("initialize", { sceneJSON }));

      expect(h.api.history.clear).toHaveBeenCalledTimes(1);
      expect(h.api.addFiles).toHaveBeenCalledWith([expect.objectContaining({ id: "image1" })]);
      expect(h.serializeCurrentScene).toHaveBeenCalledTimes(1);
      expect(h.state.isDirty()).toBe(false);
    });

    it("rejects a malformed sceneJSON payload", async () => {
      const h = makeHarness();
      await expect(h.handler.handle(request("loadScene", { sceneJSON: 42 }))).rejects.toThrow(
        "Malformed loadScene payload: sceneJSON must be a string",
      );
    });
  });

  describe("requestSnapshot", () => {
    it("preserves unknown top-level fields through the snapshot", async () => {
      const originalScene = JSON.stringify({
        type: "excalidraw",
        version: 2,
        source: "fixture",
        elements: [],
        appState: { viewBackgroundColor: "#ffffff" },
        files: {},
        futureTopLevelField: { preserve: true },
      });
      const h = makeHarness(originalScene);
      h.serializeCurrentScene.mockReturnValue(JSON.stringify({
        type: "excalidraw",
        version: 2,
        source: "excalidays",
        elements: [rectV1],
        appState: { viewBackgroundColor: "#eeeeee" },
        files: {},
      }));
      const response = await h.handler.handle(request("requestSnapshot", {}));
      const scene = JSON.parse((response.payload as { sceneJSON: string }).sceneJSON);
      expect(scene.futureTopLevelField).toEqual({ preserve: true });
      expect(scene.source).toBe("fixture");
      expect(scene.elements).toHaveLength(1);
    });

    it("emits isDirty:false and canUndo:false when a dirty scene is snapshotted", async () => {
      const h = makeHarness();
      // edit dirties the scene
      h.deps.setInitialized(true);
      h.handler.onSceneChange({
        elements: [rectV1],
        files: emptyFiles,
        appState: whiteAppState,
      });
      expect(h.postNativeEvent).toHaveBeenCalledWith("dirtyStateChanged", { isDirty: true });
      expect(h.postNativeEvent).toHaveBeenCalledWith("commandStateChanged", { canUndo: true, canRedo: false });

      h.serializeCurrentScene.mockReturnValue(JSON.stringify({
        type: "excalidraw",
        version: 2,
        elements: [rectV1],
        appState: { viewBackgroundColor: "#ffffff" },
        files: {},
      }));
      await h.handler.handle(request("requestSnapshot", {}));
      expect(h.postNativeEvent).toHaveBeenCalledWith("dirtyStateChanged", { isDirty: false });
      expect(h.postNativeEvent).toHaveBeenCalledWith("commandStateChanged", { canUndo: false, canRedo: false });
    });
  });

  describe("onSceneChange (dirty + command tracking)", () => {
    it("syncs the React theme from the editor theme without dirtying", () => {
      const h = makeHarness(undefined, "light");
      h.deps.setInitialized(true);
      h.handler.onSceneChange({ elements: [], files: emptyFiles, appState: { ...whiteAppState, theme: "dark" } });
      expect(h.setTheme).toHaveBeenCalledWith("dark");
      expect(h.postNativeEvent).not.toHaveBeenCalledWith("dirtyStateChanged", expect.anything());
      expect(h.state.isDirty()).toBe(false);
    });

    it("ignores pre-initialization scene churn", () => {
      const h = makeHarness();
      h.handler.onSceneChange({ elements: [rectV1], files: emptyFiles, appState: whiteAppState });
      expect(h.state.isDirty()).toBe(false);
      expect(h.postNativeEvent).not.toHaveBeenCalled();
    });
  });

  describe("performCommand undo / redo", () => {
    function installKeyListener(_h: Harness) {
      const elementEvents: KeyboardEvent[] = [];
      const windowEvents: KeyboardEvent[] = [];
      const element = document.createElement("div");
      element.className = "excalidraw";
      document.body.appendChild(element);
      element.addEventListener("keydown", (event) => elementEvents.push(event as KeyboardEvent));
      window.addEventListener("keydown", (event) => windowEvents.push(event as KeyboardEvent));
      return { elementEvents, windowEvents, element };
    }

    it("dispatches a meta+z keydown for undo and tracks canRedo after the undo lands", async () => {
      const h = makeHarness();
      const { elementEvents, windowEvents, element } = installKeyListener(h);

      const response = await h.handler.handle(request("performCommand", { command: "undo" }));
      expect(response).toMatchObject({ payload: { performed: "undo" } });
      expect(elementEvents).toHaveLength(1);
      expect(windowEvents.length).toBeGreaterThanOrEqual(1);
      const key = elementEvents[0];
      expect(key.key).toBe("z");
      expect(key.metaKey).toBe(true);
      expect(key.shiftKey).toBe(false);
      expect(key.cancelable).toBe(true);
      element.remove();

      // dirty edit first, then undo back to the clean baseline
      h.deps.setInitialized(true);
      h.handler.onSceneChange({ elements: [rectV1], files: emptyFiles, appState: whiteAppState });
      expect(h.state.isDirty()).toBe(true);

      await h.handler.handle(request("performCommand", { command: "undo" }));
      // the undo "lands": scene reverts to the clean signature
      h.handler.onSceneChange({ elements: [], files: emptyFiles, appState: whiteAppState });

      expect(h.state.isDirty()).toBe(false);
      expect(h.postNativeEvent).toHaveBeenCalledWith("dirtyStateChanged", { isDirty: false });
      expect(h.postNativeEvent).toHaveBeenCalledWith("commandStateChanged", { canUndo: false, canRedo: true });

      // a fresh edit clears canRedo
      h.handler.onSceneChange({ elements: [rectV1], files: emptyFiles, appState: whiteAppState });
      expect(h.postNativeEvent).toHaveBeenCalledWith("commandStateChanged", { canUndo: true, canRedo: false });
    });

    it("dispatches a meta+shift+z keydown for redo and clears canRedo when it lands", async () => {
      const h = makeHarness();
      const { elementEvents, element } = installKeyListener(h);
      h.deps.setInitialized(true);

      h.handler.onSceneChange({ elements: [rectV1], files: emptyFiles, appState: whiteAppState });
      await h.handler.handle(request("performCommand", { command: "undo" }));
      h.handler.onSceneChange({ elements: [], files: emptyFiles, appState: whiteAppState });

      const response = await h.handler.handle(request("performCommand", { command: "redo" }));
      expect(response).toMatchObject({ payload: { performed: "redo" } });
      const redoKey = elementEvents[1];
      expect(redoKey.shiftKey).toBe(true);

      h.handler.onSceneChange({ elements: [rectV1], files: emptyFiles, appState: whiteAppState });
      expect(h.state.isDirty()).toBe(true);
      expect(h.postNativeEvent).toHaveBeenCalledWith("commandStateChanged", { canUndo: true, canRedo: false });
      element.remove();
    });

    it("does not arm canRedo when the undo is a no-op (nothing moved)", async () => {
      const h = makeHarness();
      h.deps.setInitialized(true);
      await h.handler.handle(request("performCommand", { command: "undo" }));
      // let the flag-clearing timeout run: no onChange ever arrived
      await new Promise<void>((resolve) => setTimeout(resolve, 0));
      h.handler.onSceneChange({ elements: [rectV1], files: emptyFiles, appState: whiteAppState });
      expect(h.postNativeEvent).toHaveBeenCalledWith("commandStateChanged", { canUndo: true, canRedo: false });
      expect(h.postNativeEvent).not.toHaveBeenCalledWith("commandStateChanged", expect.objectContaining({ canRedo: true }));
    });

    it("rejects a malformed command payload", async () => {
      const h = makeHarness();
      await expect(h.handler.handle(request("performCommand", { command: "zoom" }))).rejects.toThrow(
        "Malformed performCommand payload",
      );
      await expect(h.handler.handle(request("performCommand", {}))).rejects.toThrow(
        "Malformed performCommand payload",
      );
    });
  });

  describe("updateTheme", () => {
    it("syncs BOTH the scene theme and the React theme in one handler", async () => {
      const h = makeHarness();
      const response = await h.handler.handle(request("updateTheme", { theme: "dark" }));
      expect(h.api.updateScene).toHaveBeenCalledWith({ appState: { theme: "dark" } });
      expect(h.setTheme).toHaveBeenCalledWith("dark");
      expect(response).toMatchObject({ payload: { updated: true } });
      // theme-only change must not dirty or move command state
      expect(h.postNativeEvent).not.toHaveBeenCalled();
    });
  });

  describe("misc operations and error paths", () => {
    it("runs zoomToFit, focusCanvas, setReadOnly", async () => {
      const h = makeHarness();
      const element = document.createElement("div");
      element.className = "excalidraw";
      const focus = vi.fn();
      element.focus = focus;
      document.body.appendChild(element);

      await h.handler.handle(request("zoomToFit", {}));
      expect(h.api.scrollToContent).toHaveBeenCalledWith([], { fitToViewport: true, animate: false });

      await h.handler.handle(request("focusCanvas", {}));
      expect(focus).toHaveBeenCalled();

      await h.handler.handle(request("setReadOnly", { readOnly: true }));
      expect(h.api.updateScene).toHaveBeenCalledWith({ appState: { viewModeEnabled: true } });
      element.remove();
    });

    it("throws on allowlisted-but-unimplemented operations", async () => {
      const h = makeHarness();
      await expect(h.handler.handle(request("exportScene", {}))).rejects.toThrow(
        "Operation exportScene is not implemented in Phase 1",
      );
      await expect(h.handler.handle(request("importBinaryFile", {}))).rejects.toThrow(
        "Operation importBinaryFile is not implemented in Phase 1",
      );
    });
  });

  it("silently ignores scene changes after dispose", () => {
    const h = makeHarness();
    h.deps.setInitialized(true);
    h.handler.dispose();
    expect(() => h.handler.onSceneChange({ elements: [rectV1], files: emptyFiles, appState: whiteAppState })).not.toThrow();
    expect(h.postNativeEvent).not.toHaveBeenCalled();
  });
});
