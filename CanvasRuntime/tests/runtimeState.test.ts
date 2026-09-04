import { describe, expect, it, vi } from "vitest";
import { RuntimeState } from "../src/runtimeState";

const originalScene = JSON.stringify({
  type: "excalidraw",
  version: 2,
  source: "fixture",
  elements: [],
  appState: { viewBackgroundColor: "#ffffff" },
  files: { image1: { id: "image1", dataURL: "data:image/png;base64,AA==" } },
  futureTopLevelField: { preserve: true },
});

describe("runtime state", () => {
  it("emits one dirty event until a snapshot establishes a clean baseline", () => {
    const notify = vi.fn();
    const state = new RuntimeState(originalScene, notify);
    state.markDirty();
    state.markDirty();
    expect(notify).toHaveBeenCalledTimes(1);

    state.snapshot(JSON.stringify({ type: "excalidraw", elements: [], appState: {}, files: {} }));
    state.markDirty();
    expect(notify).toHaveBeenCalledTimes(2);
  });

  it("preserves compatible unknown top-level fields and current attachments", () => {
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
    expect(result.files).toEqual({ current: { id: "current", dataURL: "data:image/png;base64,AQ==" } });
  });

  it("ignores transient-equivalent serialized scenes before reporting a persistent change", () => {
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

    state.markDirtyIfChanged(cleanScene);
    expect(notify).not.toHaveBeenCalled();

    // Transient UI changes (scroll, zoom, selection) must NOT trigger dirty
    state.markDirtyIfChanged(JSON.stringify({
      type: "excalidraw",
      version: 2,
      source: "local",
      elements: [],
      appState: {
        viewBackgroundColor: "#ffffff",
        scrollX: 120,
        scrollY: -45,
        zoom: { value: 1.5 },
        selectedElementIds: { "rect-1": true },
      },
      files: {},
    }));
    expect(notify).not.toHaveBeenCalled();

    state.markDirtyIfChanged(JSON.stringify({
      type: "excalidraw",
      version: 2,
      source: "local",
      elements: [{ id: "rectangle-1", type: "rectangle" }],
      appState: { viewBackgroundColor: "#ffffff" },
      files: {},
    }));
    expect(notify).toHaveBeenCalledTimes(1);
  });

  it("rejects calls after destruction", () => {
    const state = new RuntimeState(originalScene, () => undefined);
    state.destroy();
    expect(() => state.markDirty()).toThrow("Canvas runtime is destroyed");
    expect(() => state.snapshot("{}")).toThrow("Canvas runtime is destroyed");
  });
});
