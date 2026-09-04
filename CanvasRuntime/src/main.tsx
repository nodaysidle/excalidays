import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { CanvasRuntime } from "./CanvasRuntime";
import "./runtime.css";

window.EXCALIDRAW_ASSET_PATH = "./fonts/";

const root = document.getElementById("root");
if (!root) {
  throw new Error("Missing canvas runtime root");
}

createRoot(root).render(
  <StrictMode>
    <CanvasRuntime />
  </StrictMode>,
);
