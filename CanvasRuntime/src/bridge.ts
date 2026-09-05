export const BRIDGE_PROTOCOL_VERSION = 1 as const;
export const MAX_SCENE_PAYLOAD_BYTES = 64 * 1024 * 1024;

export const nativeOperations = [
  "initialize",
  "loadScene",
  "requestSnapshot",
  "updateTheme",
  "performCommand",
  "zoomToFit",
  "setReadOnly",
  "focusCanvas",
] as const;

export type NativeOperation = (typeof nativeOperations)[number];
export type BridgeKind = "request" | "response" | "event";

export interface NativeRequest {
  protocolVersion: typeof BRIDGE_PROTOCOL_VERSION;
  id: string;
  kind: "request";
  operation: NativeOperation;
  payload: unknown;
}

export interface BridgeResponse {
  protocolVersion: typeof BRIDGE_PROTOCOL_VERSION;
  id: string;
  kind: "response";
  operation: NativeOperation;
  payload: unknown;
}

export class BridgeError extends Error {
  constructor(
    public readonly code: "invalidEnvelope" | "protocolMismatch" | "unknownOperation" | "payloadTooLarge",
    message: string,
  ) {
    super(message);
    this.name = "BridgeError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function decodeNativeRequest(
  value: unknown,
  maximumPayloadBytes = MAX_SCENE_PAYLOAD_BYTES,
): NativeRequest {
  if (!isRecord(value) || typeof value.id !== "string" || value.kind !== "request") {
    throw new BridgeError("invalidEnvelope", "Invalid bridge request envelope");
  }
  if (value.protocolVersion !== BRIDGE_PROTOCOL_VERSION) {
    throw new BridgeError("protocolMismatch", "Unsupported protocol version");
  }
  if (typeof value.operation !== "string" || !nativeOperations.includes(value.operation as NativeOperation)) {
    throw new BridgeError("unknownOperation", "Unknown bridge operation");
  }
  const payloadBytes = new TextEncoder().encode(JSON.stringify(value.payload ?? null)).byteLength;
  if (payloadBytes > maximumPayloadBytes) {
    throw new BridgeError("payloadTooLarge", `Bridge payload exceeds ${maximumPayloadBytes} bytes`);
  }
  return {
    protocolVersion: BRIDGE_PROTOCOL_VERSION,
    id: value.id,
    kind: "request",
    operation: value.operation as NativeOperation,
    payload: value.payload,
  };
}

export function makeResponse(id: string, operation: NativeOperation, payload: unknown): BridgeResponse {
  return {
    protocolVersion: BRIDGE_PROTOCOL_VERSION,
    id,
    kind: "response",
    operation,
    payload,
  };
}
