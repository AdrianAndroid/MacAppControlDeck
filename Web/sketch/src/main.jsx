import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  Excalidraw,
  exportToCanvas,
  restoreElements,
  restoreAppState,
  serializeAsJSON
} from "@excalidraw/excalidraw";
import "@excalidraw/excalidraw/index.css";
import "./sketch.css";

const MESSAGE_HANDLER = "deckSketch";

function post(type, payload = {}) {
  try {
    window.webkit?.messageHandlers?.[MESSAGE_HANDLER]?.postMessage({ type, ...payload });
  } catch (error) {
    console.warn("native bridge unavailable", error);
  }
}

let toastSetter = null;
function showToast(text, kind = "ok") {
  toastSetter?.({ id: Date.now(), text, kind });
}

let excalidrawAPI = null;
let hydrated = false;
let pendingScene = null;
let saveTimer = null;

function getNonDeletedElements(elements) {
  return elements.filter((element) => !element.isDeleted);
}

function selectedElementsWithBindings(elements, selectedIDs) {
  const selected = new Set(Object.keys(selectedIDs || {}).filter((id) => selectedIDs[id]));
  if (selected.size === 0) return [];
  const byID = new Map(elements.map((element) => [element.id, element]));
  for (const id of Array.from(selected)) {
    const element = byID.get(id);
    if (!element) continue;
    if (element.containerId) selected.add(element.containerId);
    for (const bound of element.boundElements || []) selected.add(bound.id);
  }
  return elements.filter((element) => selected.has(element.id) && !element.isDeleted);
}

function sceneJSON() {
  if (!excalidrawAPI) return "";
  return serializeAsJSON(
    getNonDeletedElements(excalidrawAPI.getSceneElements()),
    excalidrawAPI.getAppState(),
    excalidrawAPI.getFiles(),
    "local"
  );
}

function loadScene(json) {
  pendingScene = json;
  if (!excalidrawAPI || !json) {
    hydrated = true;
    return;
  }
  try {
    const scene = JSON.parse(json);
    const elements = restoreElements(scene.elements || [], null, {
      refreshDimensions: true,
      repairBindings: true
    });
    const restoredAppState = restoreAppState(scene.appState || null, null);
    excalidrawAPI.updateScene({
      elements,
      appState: {
        ...restoredAppState,
        viewBackgroundColor: "#ffffff",
        theme: "light",
        selectedElementIds: {},
        editingElement: null,
        openDialog: null,
        openSidebar: null
      }
    });
    if (scene.files && Object.keys(scene.files).length > 0) {
      excalidrawAPI.addFiles(Object.values(scene.files));
    }
    if (elements.length > 0) {
      setTimeout(() => excalidrawAPI?.scrollToContent(elements, { fitToContent: true }), 60);
    }
  } catch (error) {
    console.error("load scene failed", error);
    showToast("草稿读取失败，已打开空白画板", "error");
  }
  pendingScene = null;
  hydrated = true;
}

async function exportPNG(scale = 2, padding = 24, background = "white") {
  if (!excalidrawAPI) throw new Error("画板还没有准备好");
  const all = getNonDeletedElements(excalidrawAPI.getSceneElements());
  if (all.length === 0) throw new Error("画板还是空的，先画点内容");

  const appState = excalidrawAPI.getAppState();
  const selected = selectedElementsWithBindings(all, appState.selectedElementIds);
  const elements = selected.length > 0 ? selected : all;

  const canvas = await exportToCanvas({
    elements,
    appState: {
      ...appState,
      exportBackground: background !== "transparent",
      viewBackgroundColor: background === "transparent" ? "transparent" : "#ffffff",
      exportWithDarkMode: false,
      exportScale: Number(scale) || 2,
      exportEmbedScene: false
    },
    files: excalidrawAPI.getFiles(),
    exportPadding: Number(padding) || 24,
    maxWidthOrHeight: 3000
  });

  const dataURL = canvas.toDataURL("image/png");
  return {
    base64: dataURL.slice(dataURL.indexOf(",") + 1),
    width: canvas.width,
    height: canvas.height,
    selected: selected.length > 0
  };
}

window.deckSketch = {
  exportPNG,
  getScene: sceneJSON,
  loadScene,
  clear: () => {
    excalidrawAPI?.updateScene({
      elements: [],
      appState: { selectedElementIds: {}, editingElement: null }
    });
    excalidrawAPI?.history.clear();
    showToast("已新建空白画板");
  },
  hasContent: () =>
    !!excalidrawAPI && getNonDeletedElements(excalidrawAPI.getSceneElements()).length > 0,
  showToast
};

function Toast() {
  const [toast, setToast] = useState(null);
  useEffect(() => {
    toastSetter = setToast;
    return () => {
      toastSetter = null;
    };
  }, []);
  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 2200);
    return () => clearTimeout(timer);
  }, [toast]);
  if (!toast) return null;
  return <div className={`deck-toast ${toast.kind === "error" ? "is-error" : ""}`}>{toast.text}</div>;
}

function isEditingText() {
  const active = document.activeElement;
  return (
    active &&
    (active.tagName === "TEXTAREA" ||
      active.tagName === "INPUT" ||
      active.getAttribute("contenteditable") === "true")
  );
}

function App() {
  useEffect(() => {
    const onKeyDown = (event) => {
      if (!event.metaKey || event.altKey) return;
      const key = event.key.toLowerCase();
      if (key === "s") {
        event.preventDefault();
        post("saveRequested");
      } else if (key === "c" && event.shiftKey) {
        event.preventDefault();
        post("copyRequested");
      } else if (key === "n" && !event.shiftKey && !isEditingText()) {
        event.preventDefault();
        post("newRequested");
      }
    };
    window.addEventListener("keydown", onKeyDown, true);
    return () => window.removeEventListener("keydown", onKeyDown, true);
  }, []);

  return (
    <div className="deck-shell">
      <Excalidraw
        langCode="zh-CN"
        theme="light"
        name="UI 草图"
        aiEnabled={false}
        showDeprecatedFonts={false}
        validateEmbeddable={() => false}
        renderEmbeddable={() => null}
        handleKeyboardGlobally={false}
        UIOptions={{
          canvasActions: {
            changeViewBackgroundColor: false,
            export: false,
            loadScene: false,
            saveToActiveFile: false,
            toggleTheme: false,
            saveAsImage: false
          },
          tools: { image: true }
        }}
        initialData={{
          elements: [],
          appState: { viewBackgroundColor: "#ffffff", currentItemFontFamily: 1 }
        }}
        excalidrawAPI={(api) => {
          excalidrawAPI = api;
          if (pendingScene) loadScene(pendingScene);
          setTimeout(() => post("ready"), 80);
        }}
        onChange={(elements, appState) => {
          if (!hydrated) return;
          if (saveTimer) clearTimeout(saveTimer);
          saveTimer = setTimeout(() => {
            post("change", { scene: sceneJSON() });
          }, 1000);
        }}
        renderTopRightUI={() => (
          <div className="deck-actions">
            <button
              type="button"
              className="deck-action"
              title="复制画板或选中内容为 PNG（⌘⇧C）"
              onClick={() => post("copyRequested")}
            >
              复制图片
            </button>
            <button
              type="button"
              className="deck-action is-primary"
              title="保存 PNG 与 .excalidraw（⌘S）"
              onClick={() => post("saveRequested")}
            >
              保存
            </button>
          </div>
        )}
      />
      <Toast />
    </div>
  );
}

createRoot(document.getElementById("root")).render(<App />);
