import { describe, expect, it, vi } from "vitest";
import { computePersistentSignature, RuntimeState } from "../src/runtimeState";

const originalScene = JSON.stringify({
  type: "excalidraw",
  version: 2,
  source: "fixture",
  elements: [],
  appState: { viewBackgroundColor: "#ffffff" },
  files: { image1: { id: "image1", dataURL: "data:image/png;base64,AA==" } },
  futureTopLevelField: { preserve: true },
});

const emptyElements: unknown[] = [];
const emptyFiles = {};
const whiteAppState = { viewBackgroundColor: "#ffffff" };

describe("computePersistentSignature", () => {
  it("ignores transient UI fields (scroll, zoom, selection, theme)", () => {
    const transient = computePersistentSignature(emptyElements, emptyFiles, {
      viewBackgroundColor: "#ffffff",
      scrollX: 120,
      scrollY: -45,
      zoom: { value: 1.5 },
      selectedElementIds: { "rect-1": true },
      theme: "dark",
    });
    const plain = computePersistentSignature(emptyElements, emptyFiles, whiteAppState);
    expect(transient).toBe(plain);
  });

  it("changes when elements are added, deleted, or version-bumped", () => {
    const plain = computePersistentSignature(emptyElements, emptyFiles, whiteAppState);
    const added = computePersistentSignature(
      [{ id: "rectangle-1", type: "rectangle", version: 1, versionNonce: 7 }],
      emptyFiles,
      whiteAppState,
    );
    expect(added).not.toBe(plain);

    const mutated = computePersistentSignature(
      [{ id: "rectangle-1", type: "rectangle", version: 2, versionNonce: 9 }],
      emptyFiles,
      whiteAppState,
    );
    expect(mutated).not.toBe(added);

    const restored = computePersistentSignature([], emptyFiles, whiteAppState);
    expect(restored).toBe(plain);
  });

  it("changes when viewBackgroundColor or gridSize change", () => {
    const plain = computePersistentSignature(emptyElements, emptyFiles, whiteAppState);
    expect(computePersistentSignature(emptyElements, emptyFiles, { viewBackgroundColor: "#121212" })).not.toBe(plain);
    expect(computePersistentSignature(emptyElements, emptyFiles, { viewBackgroundColor: "#ffffff", gridSize: 20 })).not.toBe(plain);
  });

  it("changes when files change", () => {
    const plain = computePersistentSignature(emptyElements, emptyFiles, whiteAppState);
    const withFile = computePersistentSignature(emptyElements, { image1: { id: "image1", dataURL: "data:image/png;base64,AA==" } }, whiteAppState);
    expect(withFile).not.toBe(plain);
  });
});

describe("runtime state", () => {
  it("emits dirtyStateChange(true) once per dirty period and (false) when a snapshot re-baselines", () => {
    const notify = vi.fn();
    const state = new RuntimeState(originalScene, notify);
    state.markDirty();
    state.markDirty();
    expect(notify).toHaveBeenCalledTimes(1);
    expect(notify).toHaveBeenLastCalledWith(true);

    state.snapshot(JSON.stringify({ type: "excalidraw", elements: [], appState: {}, files: {} }));
    expect(notify).toHaveBeenLastCalledWith(false);

    state.markDirty();
    expect(notify).toHaveBeenLastCalledWith(true);
    expect(notify).toHaveBeenCalledTimes(3);
  });

  it("does not dirty on a signature-equal change and dirties on a signature-different change", () => {
    const notify = vi.fn();
    const state = new RuntimeState(originalScene, notify);
    const cleanScene = JSON.stringify({
      type: "excalidraw",
      version: 2,
      source: "local",
      elements: [],
      appState: { viewBackgroundColor: "#ffffff" },
      files: {},
    });
    state.setCleanScene(cleanScene);

    state.markDirtyIfChanged(computePersistentSignature(emptyElements, emptyFiles, whiteAppState));
    expect(notify).not.toHaveBeenCalled();

    // Transient UI-only change must NOT dirty
    state.markDirtyIfChanged(computePersistentSignature(emptyElements, emptyFiles, {
      viewBackgroundColor: "#ffffff",
      scrollX: 120,
      scrollY: -45,
      zoom: { value: 1.5 },
      selectedElementIds: { "rect-1": true },
    }));
    expect(notify).not.toHaveBeenCalled();

    // Element added -> dirty
    state.markDirtyIfChanged(computePersistentSignature(
      [{ id: "rectangle-1", type: "rectangle", version: 1, versionNonce: 7 }],
      emptyFiles,
      whiteAppState,
    ));
    expect(notify).toHaveBeenCalledTimes(1);
    expect(notify).toHaveBeenLastCalledWith(true);
  });

  it("clears dirty when the scene reverts to the clean baseline (undo-to-clean)", () => {
    const notify = vi.fn();
    const state = new RuntimeState(originalScene, notify);
    const cleanSignature = computePersistentSignature(emptyElements, emptyFiles, whiteAppState);
    state.setCleanScene(JSON.stringify({
      type: "excalidraw",
      version: 2,
      source: "local",
      elements: [],
      appState: { viewBackgroundColor: "#ffffff" },
      files: {},
    }));

    state.markDirtyIfChanged(computePersistentSignature(
      [{ id: "rectangle-1", type: "rectangle", version: 1, versionNonce: 7 }],
      emptyFiles,
      whiteAppState,
    ));
    expect(notify).toHaveBeenLastCalledWith(true);

    state.markDirtyIfChanged(cleanSignature);
    expect(notify).toHaveBeenCalledTimes(2);
    expect(notify).toHaveBeenLastCalledWith(false);
    expect(state.isDirty()).toBe(false);
  });

  it("preserves compatible unknown top-level fields and merges source + current files", () => {
    const state = new RuntimeState(originalScene, () => undefined);
    const result = JSON.parse(state.snapshot(JSON.stringify({
      type: "excalidraw",
      version: 2,
      source: "excalidays",
      elements: [{ id: "rectangle-1", type: "rectangle" }],
      appState: { viewBackgroundColor: "#eeeeee" },
      files: { current: { id: "current", dataURL: "data:image/png;base64,AQ==" } },
    })));

    expect(result.futureTopLevelField).toEqual({ preserve: true });
    expect(result.source).toBe("fixture");
    expect(result.elements).toHaveLength(1);
    expect(result.files).toEqual({
      image1: { id: "image1", dataURL: "data:image/png;base64,AA==" },
      current: { id: "current", dataURL: "data:image/png;base64,AQ==" },
    });
  });

  it("preserves source-scene files when the serializer drops them (files={})", () => {
    const state = new RuntimeState(originalScene, () => undefined);
    // serializeAsJSON(getFiles()) returns an empty files map after loadFromBlob,
    // so the snapshot must restore the source scene's files.
    const result = JSON.parse(state.snapshot(JSON.stringify({
      type: "excalidraw",
      version: 2,
      source: "local",
      elements: [],
      appState: { viewBackgroundColor: "#ffffff" },
      files: {},
    })));
    expect(result.files).toEqual({ image1: { id: "image1", dataURL: "data:image/png;base64,AA==" } });
  });

  it("rejects calls after destruction", () => {
    const state = new RuntimeState(originalScene, () => undefined);
    state.destroy();
    expect(() => state.markDirty()).toThrow("Canvas runtime is destroyed");
    expect(() => state.snapshot("{}")).toThrow("Canvas runtime is destroyed");
  });
});
