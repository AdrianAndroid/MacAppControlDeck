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

function aiJSON() {
  if (!excalidrawAPI) throw new Error("画板还没有准备好");
  const all = getNonDeletedElements(excalidrawAPI.getSceneElements());
  if (all.length === 0) throw new Error("画板还是空的，先画点内容");

  const appState = excalidrawAPI.getAppState();
  const selected = selectedElementsWithBindings(all, appState.selectedElementIds);
  const elements = selected.length > 0 ? selected : all;
  const selectedOnly = selected.length > 0;

  const scene = JSON.parse(
    serializeAsJSON(
      elements,
      { ...appState, selectedElementIds: {} },
      {},
      "local"
    )
  );

  const typeCounts = elements.reduce((counts, element) => {
    const type = element.type || "unknown";
    counts[type] = (counts[type] || 0) + 1;
    return counts;
  }, {});

  const textElements = elements.filter(
    (element) => element.type === "text" && typeof element.text === "string"
  );
  const texts = textElements
    .map((element) => element.text.trim())
    .filter(Boolean)
    .slice(0, 100);

  const bounds = elements.reduce(
    (box, element) => {
      const x = Number(element.x) || 0;
      const y = Number(element.y) || 0;
      const width = Number(element.width) || 0;
      const height = Number(element.height) || 0;
      box.minX = Math.min(box.minX, x);
      box.minY = Math.min(box.minY, y);
      box.maxX = Math.max(box.maxX, x + width);
      box.maxY = Math.max(box.maxY, y + height);
      return box;
    },
    { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity }
  );

  const hasImages = elements.some((element) => element.type === "image");

  return JSON.stringify(
    {
      format: "macapp-controldeck/ui-sketch",
      schemaVersion: 1,
      contentType: "application/vnd.macappcontroldeck.ui-sketch+json",
      isDiagram: true,
      diagramType: "ui-sketch",
      ai: {
        kind: "diagram",
        isDiagram: true,
        title: "UI 草图",
        message:
          "这是一个图形/示意图（UI 草图），不是普通文本。请把 scene.elements 当作画布上的图形元素来理解，而不是把坐标、颜色、尺寸当作文本内容。",
        howToRead: [
          "scene.elements 是 Excalidraw 图形元素数组；type 表示 rectangle / ellipse / diamond / arrow / line / freedraw / text / image 等。",
          "x、y 是元素左上角坐标，width、height 是尺寸；arrow、line、freedraw 的 points 是相对路径点。",
          "text 元素的 text 字段是画面上的文字；containerId 表示文字绑定在某个形状内。",
          "backgroundColor 为 transparent 表示无填充；strokeColor 是描边颜色。",
          "groupIds 相同的元素属于同一组；boundElements 表示箭头或文字与该元素的绑定关系。"
        ],
        selectedOnly
      },
      summary: {
        elementCount: elements.length,
        typeCounts,
        textCount: textElements.length,
        texts,
        bounds: {
          x: Number.isFinite(bounds.minX) ? bounds.minX : 0,
          y: Number.isFinite(bounds.minY) ? bounds.minY : 0,
          width: Number.isFinite(bounds.maxX - bounds.minX) ? bounds.maxX - bounds.minX : 0,
          height: Number.isFinite(bounds.maxY - bounds.minY) ? bounds.maxY - bounds.minY : 0
        },
        hasImages
      },
      notes: hasImages
        ? ["JSON 不包含图片二进制；image 元素只保留 fileId，纯文本无法还原位图。"]
        : [],
      scene
    },
    null,
    2
  );
}

window.deckSketch = {
  exportPNG,
  getAIJSON: aiJSON,
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
              className="deck-action"
              title="复制带图形说明的 JSON，直接粘贴给 AI"
              onClick={() => post("jsonCopyRequested")}
            >
              复制 JSON
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
