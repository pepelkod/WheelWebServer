// Web Worker: runs OpenSCAD (WebAssembly) off the main thread so the page
// never freezes during a render.
//
// Message in:  { type: "render", id, parts: ["hub","rim","spokes"], defines: ["-D","k=v",...] }
// Messages out: { type: "status", id, text }
//               { type: "part", id, part, stl (ArrayBuffer), log, ms }
//               { type: "done", id, log }
//               { type: "error", id, message, log }

// Self-hosting tip: copy openscad.js next to this file and change this URL.
import { createOpenSCAD } from "https://cdn.jsdelivr.net/npm/openscad-wasm-prebuilt@1.2.0/dist/openscad.js";

const SCAD_FILE = "Wheel.scad";

// Files Wheel.scad may import/use. Put the ones you have in ./assets/.
// Missing files are skipped; OpenSCAD only complains if a missing file
// is actually used by the chosen parameters.
const ASSET_FILES = [
  "thread.scad",
  "nipple.stl",
  "elbow.stl",
  "rim.svg",
  "HopePro4Rear.svg",
  "front_hub.svg",
  "six_bolt.svg",
  "centerlock.svg",
];

let filesPromise = null;

async function loadFiles() {
  const files = {};
  const scad = await fetch(SCAD_FILE, { cache: "no-cache" });
  if (!scad.ok) throw new Error(`Could not load ${SCAD_FILE} (${scad.status})`);
  files[SCAD_FILE] = new Uint8Array(await scad.arrayBuffer());

  await Promise.all(ASSET_FILES.map(async (name) => {
    try {
      const r = await fetch(`assets/${name}`);
      if (r.ok) files[name] = new Uint8Array(await r.arrayBuffer());
    } catch (_) { /* missing asset: fine unless used */ }
  }));
  return files;
}

// The WASM build keeps global C++ state, so a second callMain() on the
// same instance can throw. A fresh instance per render avoids that.
async function renderPart(files, part, defines) {
  const log = [];
  const openscad = await createOpenSCAD({
    print: (t) => log.push(t),
    printErr: (t) => log.push(t),
  });
  const inst = openscad.getInstance();
  for (const [name, data] of Object.entries(files)) inst.FS.writeFile("/" + name, data);

  const args = [
    "/" + SCAD_FILE,
    "--backend=manifold",
    "--export-format=binstl",
    ...defines,
    "-D", `part="${part}"`,
    "-o", "/out.stl",
  ];

  const t0 = performance.now();
  let rc;
  try {
    rc = inst.callMain(args);
  } catch (e) {
    throw Object.assign(new Error(`OpenSCAD crashed rendering ${part}`), { log });
  }
  const ms = performance.now() - t0;

  if (rc !== 0) {
    const err = log.find((l) => l.startsWith("ERROR")) || `OpenSCAD exited with code ${rc}`;
    throw Object.assign(new Error(err.replace(/ in file .*$/, "")), { log });
  }
  const stl = inst.FS.readFile("/out.stl");
  return { stl: stl.slice().buffer, log, ms };
}

self.onmessage = async (ev) => {
  const msg = ev.data;
  if (msg.type !== "render") return;
  const { id, parts, defines } = msg;
  let lastLog = [];
  try {
    if (!filesPromise) {
      self.postMessage({ type: "status", id, text: "Loading OpenSCAD and model files…" });
      filesPromise = loadFiles();
    }
    let files;
    try { files = await filesPromise; } catch (e) { filesPromise = null; throw e; }

    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      self.postMessage({ type: "status", id, text: `Rendering ${part} (${i + 1}/${parts.length})…` });
      const r = await renderPart(files, part, defines);
      lastLog = r.log;
      self.postMessage({ type: "part", id, part, stl: r.stl, log: r.log, ms: r.ms }, [r.stl]);
    }
    self.postMessage({ type: "done", id, log: lastLog });
  } catch (e) {
    self.postMessage({ type: "error", id, message: e.message || String(e), log: e.log || lastLog });
  }
};
