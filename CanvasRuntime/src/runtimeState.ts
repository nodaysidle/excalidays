const PROTECTED_SCENE_KEYS = new Set(["type", "version", "elements", "appState", "files"]);

function extractPersistentSignature(sceneJSON: string): string {
  try {
    const parsed = JSON.parse(sceneJSON) as {
      elements?: unknown[];
      files?: Record<string, unknown>;
      appState?: {
        viewBackgroundColor?: string;
        gridSize?: number;
      };
    };
    return JSON.stringify({
      elements: parsed.elements ?? [],
      files: parsed.files ?? {},
      viewBackgroundColor: parsed.appState?.viewBackgroundColor,
      gridSize: parsed.appState?.gridSize,
    });
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

  constructor(sceneJSON: string, private readonly onDirty: () => void) {
    const parsed = JSON.parse(sceneJSON) as Record<string, unknown>;
    this.originalUnknownFields = Object.fromEntries(
      Object.entries(parsed).filter(([key]) => !PROTECTED_SCENE_KEYS.has(key)),
    );
    this.cleanSignature = extractPersistentSignature(sceneJSON);
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
    this.onDirty();
  }

  setCleanScene(serializedKnownScene: string): void {
    this.assertAlive();
    this.cleanScene = serializedKnownScene;
    this.cleanSignature = extractPersistentSignature(serializedKnownScene);
    this.dirty = false;
  }

  markDirtyIfChanged(serializedKnownScene: string): void {
    this.assertAlive();
    if (this.dirty) {
      return;
    }
    const currentSignature = extractPersistentSignature(serializedKnownScene);
    if (currentSignature === this.cleanSignature) {
      return;
    }
    this.markDirty();
  }

  snapshot(serializedKnownScene: string): string {
    this.assertAlive();
    const known = JSON.parse(serializedKnownScene) as Record<string, unknown>;
    const merged = { ...known, ...this.originalUnknownFields };
    this.cleanScene = serializedKnownScene;
    this.cleanSignature = extractPersistentSignature(serializedKnownScene);
    this.dirty = false;
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
