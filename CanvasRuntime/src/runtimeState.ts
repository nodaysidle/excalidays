const PROTECTED_SCENE_KEYS = new Set(["type", "version", "elements", "appState", "files"]);

/**
 * Persistent scene fields that survive the dirty-detection signature.
 * Transient fields (scroll/zoom/selection/theme/...) are deliberately absent:
 * the project contract forbids serializing the full scene on pointer movement,
 * so dirty detection must never depend on them.
 */
export interface PersistentAppStateFields {
  viewBackgroundColor?: unknown;
  gridSize?: unknown;
}

function fieldOf(record: Record<string, unknown> | null | undefined, key: string): string {
  return String(record ? record[key] : "");
}

/**
 * Cheap O(n) persistent signature over the scene, computed directly from the
 * live elements/files/appState objects — no JSON.stringify of the scene and
 * no JSON.parse on the hot path. Works equally well on live Excalidraw
 * objects and on JSON.parse()-restored plain records, so the post-load /
 * post-snapshot clean baseline (computed from serialized JSON) always uses
 * the exact same format as the onChange hot path.
 *
 * Content rule: an element counts when its id, version, or versionNonce
 * changes (Excalidraw bumps `version`/`versionNonce` on every mutation —
 * mutateElement in v0.18.1 increments both); files count by id, version,
 * mimeType, and dataURL length; appState counts by viewBackgroundColor and
 * gridSize only.
 */
export function computePersistentSignature(
  elements: readonly unknown[] | undefined,
  files: Record<string, unknown> | undefined,
  appState: object | undefined,
): string {
  const elementList = elements ?? [];
  let signature = `elements:${elementList.length}:`;
  for (const rawElement of elementList) {
    const element = (rawElement ?? {}) as Record<string, unknown>;
    signature += `${fieldOf(element, "id")}:${fieldOf(element, "version")}:${fieldOf(element, "versionNonce")};`;
  }
  const fileEntries = files ? Object.entries(files) : [];
  signature += `files:${fileEntries.length}:`;
  for (const [id, rawFile] of fileEntries) {
    const file = (rawFile ?? {}) as Record<string, unknown>;
    const dataURL = typeof file.dataURL === "string" ? file.dataURL : "";
    signature += `${id}:${fieldOf(file, "version")}:${dataURL.length}:${fieldOf(file, "mimeType")};`;
  }
  const fields = (appState ?? {}) as Record<string, unknown>;
  signature += `viewBackgroundColor:${fieldOf(fields, "viewBackgroundColor")}`;
  signature += `gridSize:${fieldOf(fields, "gridSize")}`;
  return signature;
}

function extractPersistentSignature(sceneJSON: string): string {
  try {
    const parsed = JSON.parse(sceneJSON) as {
      elements?: unknown[];
      files?: Record<string, unknown>;
      appState?: PersistentAppStateFields;
    };
    return computePersistentSignature(parsed.elements, parsed.files, parsed.appState);
  } catch {
    return sceneJSON;
  }
}

export class RuntimeState {
  private destroyed = false;
  private dirty = false;
  private cleanScene: string | null = null;
  private cleanSignature: string | null = null;
  private originalUnknownFields: Record<string, unknown>;

  constructor(sceneJSON: string, private readonly onDirtyStateChange: (isDirty: boolean) => void) {
    const parsed = JSON.parse(sceneJSON) as Record<string, unknown>;
    this.originalUnknownFields = Object.fromEntries(
      Object.entries(parsed).filter(([key]) => !PROTECTED_SCENE_KEYS.has(key)),
    );
    this.cleanSignature = extractPersistentSignature(sceneJSON);
  }

  isDirty(): boolean {
    return this.dirty;
  }

  replaceSourceScene(sceneJSON: string): void {
    this.assertAlive();
    const parsed = JSON.parse(sceneJSON) as Record<string, unknown>;
    this.originalUnknownFields = Object.fromEntries(
      Object.entries(parsed).filter(([key]) => !PROTECTED_SCENE_KEYS.has(key)),
    );
    this.cleanSignature = extractPersistentSignature(sceneJSON);
    this.dirty = false;
  }

  markDirty(): void {
    this.assertAlive();
    if (this.dirty) {
      return;
    }
    this.dirty = true;
    this.onDirtyStateChange(true);
  }

  /**
   * Re-baselines the clean scene (post-load or post-snapshot). The heavy
   * serialization happens at the call site (only ever on load / snapshot —
   * never on the onChange hot path).
   */
  setCleanScene(serializedKnownScene: string): void {
    this.assertAlive();
    const wasDirty = this.dirty;
    this.cleanScene = serializedKnownScene;
    this.cleanSignature = extractPersistentSignature(serializedKnownScene);
    this.dirty = false;
    if (wasDirty) {
      this.onDirtyStateChange(false);
    }
  }

  /**
   * Bidirectional dirty detection against a precomputed persistent signature.
   * Dirty -> clean (undo back to the baseline) emits isDirty:false; clean ->
   * dirty emits isDirty:true. Signature-equal changes are no-ops, so
   * pan/zoom/selection frames never touch this path.
   */
  markDirtyIfChanged(persistentSignature: string): void {
    this.assertAlive();
    if (this.dirty) {
      if (persistentSignature === this.cleanSignature) {
        this.dirty = false;
        this.onDirtyStateChange(false);
      }
      return;
    }
    if (persistentSignature === this.cleanSignature) {
      return;
    }
    this.markDirty();
  }

  snapshot(serializedKnownScene: string): string {
    this.assertAlive();
    const known = JSON.parse(serializedKnownScene) as Record<string, unknown>;
    const merged = { ...known, ...this.originalUnknownFields };
    const wasDirty = this.dirty;
    this.cleanScene = serializedKnownScene;
    this.cleanSignature = extractPersistentSignature(serializedKnownScene);
    this.dirty = false;
    if (wasDirty) {
      this.onDirtyStateChange(false);
    }
    return JSON.stringify(merged);
  }

  destroy(): void {
    this.destroyed = true;
  }

  private assertAlive(): void {
    if (this.destroyed) {
      throw new Error("Canvas runtime is destroyed");
    }
  }
}
