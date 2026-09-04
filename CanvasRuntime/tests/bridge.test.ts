import { describe, expect, it } from "vitest";
import {
  BRIDGE_PROTOCOL_VERSION,
  BridgeError,
  decodeNativeRequest,
  makeResponse,
} from "../src/bridge";

describe("bridge protocol", () => {
  it("decodes an allowlisted request", () => {
    const request = decodeNativeRequest({
      protocolVersion: 1,
      id: "request-1",
      kind: "request",
      operation: "requestSnapshot",
      payload: {},
    });
    expect(request.operation).toBe("requestSnapshot");
    expect(BRIDGE_PROTOCOL_VERSION).toBe(1);
  });

  it("rejects protocol mismatches", () => {
    expect(() => decodeNativeRequest({
      protocolVersion: 2,
      id: "request-1",
      kind: "request",
      operation: "requestSnapshot",
      payload: {},
    })).toThrowError(new BridgeError("protocolMismatch", "Unsupported protocol version"));
  });

  it("rejects arbitrary operations", () => {
    expect(() => decodeNativeRequest({
      protocolVersion: 1,
      id: "request-2",
      kind: "request",
      operation: "readFileAtPath",
      payload: { path: "/private/example" },
    })).toThrowError(new BridgeError("unknownOperation", "Unknown bridge operation"));
  });

  it("preserves the request identifier in replies", () => {
    expect(makeResponse("request-3", "requestSnapshot", { scene: "{}" })).toMatchObject({
      protocolVersion: 1,
      id: "request-3",
      kind: "response",
      operation: "requestSnapshot",
    });
  });

  it("rejects request payloads over the configured byte limit", () => {
    expect(() => decodeNativeRequest({
      protocolVersion: 1,
      id: "request-large",
      kind: "request",
      operation: "loadScene",
      payload: { sceneJSON: "x".repeat(64) },
    }, 32)).toThrowError(new BridgeError("payloadTooLarge", "Bridge payload exceeds 32 bytes"));
  });
});
