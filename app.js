import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { STLLoader } from "three/addons/loaders/STLLoader.js";
import { parseScadParams, cleanValue, toDefines } from "./params.js";

const $ = (id) => document.getElementById(id);
const PART_COLORS = { hub: 0x5a4a78, rim: 0x708090, spokes: 0x2a2a2a };
const PART_NAMES = { hub: "Hub", rim: "Rim", spokes: "Spokes" };

let params = [];
let values = {};
let worker = null;
let renderId = 0;
let results = {};          // part -> ArrayBuffer (binary STL)
let renderedKey = "";

// ---------------------------------------------------------------- form
async function init() {
  const src = await (await fetch("Wheel.scad", { cache: "no-cache" })).text();
  params = parseScadParams(src);
  const q = new URLSearchParams(location.search);
  for (const p of params) values[p.name] = q.has(p.name) ? cleanValue(p, q.get(p.name)) : p.default;
  buildForm();
  setupViewer();
}

function buildForm() {
  const form = $("form");
  form.innerHTML = "";
  let fs = null, group = null;
  for (const p of params) {
    if (p.group !== group) {
      group = p.group;
      fs = document.createElement("fieldset");
      fs.innerHTML = `<legend>${group}</legend>`;
      form.append(fs);
    }
    fs.append(makeControl(p));
  }
}

function makeControl(p) {
  const row = document.createElement("div");
  row.className = "row";
  const id = "p_" + p.name;
  const label = `<label for="${id}">${escapeHtml(p.label)}</label>`;
  const v = values[p.name];

  if (p.kind === "bool") {
    row.classList.add("check");
    row.innerHTML = `<input type="checkbox" id="${id}" ${v ? "checked" : ""}>${label}`;
    row.querySelector("input").onchange = (e) => setValue(p, e.target.checked);
  } else if (p.options) {
    row.classList.add("wide");
    const opts = p.options.map((o) =>
      `<option value="${escapeHtml(String(o.value))}" ${String(o.value) === String(v) ? "selected" : ""}>${escapeHtml(o.label)}</option>`).join("");
    row.innerHTML = `${label}<select id="${id}">${opts}</select>`;
    row.querySelector("select").onchange = (e) => setValue(p, e.target.value);
  } else if (p.kind === "number" && p.min !== undefined) {
    const attrs = `min="${p.min}" max="${p.max}" step="${p.step}" value="${v}"`;
    row.innerHTML = `${label}<input type="number" id="${id}" ${attrs}><input type="range" ${attrs} aria-label="${escapeHtml(p.label)}">`;
    const [num, range] = row.querySelectorAll("input");
    range.oninput = () => { num.value = range.value; setValue(p, range.value, false); };
    num.onchange = () => { setValue(p, num.value); num.value = values[p.name]; range.value = values[p.name]; };
  } else {
    row.innerHTML = `${label}<input type="${p.kind === "number" ? "number" : "text"}" id="${id}" value="${escapeHtml(String(v))}">`;
    row.querySelector("input").onchange = (e) => { setValue(p, e.target.value); e.target.value = values[p.name]; };
  }
  return row;
}

function setValue(p, raw) {
  values[p.name] = cleanValue(p, raw);
  // Keep the URL shareable: only non-default values go in the query string
  const q = new URLSearchParams();
  for (const x of params) if (values[x.name] !== x.default) q.set(x.name, values[x.name]);
  history.replaceState(null, "", q.toString() ? "?" + q : location.pathname);
  $("stale").style.display = renderedKey && renderedKey !== currentKey() ? "block" : "none";
}

const currentKey = () => JSON.stringify(values);

// ---------------------------------------------------------------- render
function getWorker() {
  if (!worker) {
    worker = new Worker("worker.js", { type: "module" });
    worker.onmessage = onWorkerMessage;
    worker.onerror = (e) => fail(`Worker failed to start: ${e.message || "check the browser console"}`, []);
  }
  return worker;
}

function generate() {
  const id = ++renderId;
  const part = values.part;
  const parts = part === "wheel" ? ["hub", "rim", "spokes"] : [part];
  results = {};
  clearModel();
  $("overlay").style.display = "none";
  $("stale").style.display = "none";
  $("results").hidden = true;
  $("downloads").innerHTML = "";
  setBusy(true);
  generate.started = performance.now();
  generate.key = currentKey();
  generate.logs = [];
  getWorker().postMessage({ type: "render", id, parts, defines: toDefines(params, values) });
}

function onWorkerMessage({ data: m }) {
  if (m.type === "status") { $("status").textContent = m.text; return; }
  if (m.id !== renderId) return;                       // stale message from a cancelled run
  if (m.type === "part") {
    results[m.part] = m.stl;
    generate.logs.push(...m.log);
    addMesh(m.part, m.stl);
  } else if (m.type === "done") {
    setBusy(false);
    renderedKey = generate.key;
    const secs = ((performance.now() - generate.started) / 1000).toFixed(1);
    $("status").textContent = `Done in ${secs}s`;
    showResults(generate.logs);
    showDownloads();
  } else if (m.type === "error") {
    fail(m.message, m.log);
  }
}

function fail(message, log) {
  const missing = message.match(/Can't open (?:import )?file ['"]\/?([^'"]+)['"]/i);
  if (missing) message = `Missing file: ${missing[1]}. Put it in the assets/ folder, or change the option that uses it.`;
  setBusy(false);
  $("status").textContent = "";
  $("overlay").style.display = Object.keys(results).length ? "none" : "grid";
  showResults(log || [], message);
}

function cancel() {
  if (worker) { worker.terminate(); worker = null; }   // next Generate starts a fresh worker
  renderId++;
  setBusy(false);
  $("status").textContent = "Cancelled";
}

function setBusy(busy) {
  $("generate").disabled = busy;
  $("cancel").hidden = !busy;
}

// ---------------------------------------------------------------- results
function showResults(log, error) {
  const echo = {};
  const warnings = new Set();
  for (const line of log) {
    const m = line.match(/^ECHO: "(\w+)=([-\d.]+)"/);
    if (m) echo[m[1]] = parseFloat(m[2]);
    const w = line.match(/^ECHO: "WARNING: (.*)"$/);
    if (w) warnings.add(w[1]);
    const f = line.match(/^WARNING: Can't open (?:import )?file '([^']+)'/i) || line.match(/^WARNING: Can't open (?:import )?file "([^"]+)"/i);
    if (f) warnings.add(`Missing file: ${f[1].replace(/^\//, "")} – put it in the assets folder or change the related option.`);
  }

  let html = "";
  if ("SPOKE_LENGTH_NDS" in echo) {
    const f = (x) => x.toFixed(1) + " mm";
    html += `<h2>Spoke lengths</h2>
      <table>
        <tr><th></th><th>Model</th><th>Order (est.)</th></tr>
        <tr><td>Non-drive / left</td><td class="num">${f(echo.SPOKE_LENGTH_NDS)}</td><td class="num">${f(echo.ORDER_LENGTH_NDS)}</td></tr>
        <tr><td>Drive / right</td><td class="num">${f(echo.SPOKE_LENGTH_DS)}</td><td class="num">${f(echo.ORDER_LENGTH_DS)}</td></tr>
      </table>
      <p class="note">Order length subtracts half the flange hole. Check against your hub and rim maker's figures before buying spokes.</p>`;
  }
  for (const w of warnings) html += `<div class="msg warn">${escapeHtml(w)}</div>`;
  if (error) html += `<div class="msg err">${escapeHtml(error)}</div>`;
  $("results").innerHTML = html;
  $("results").hidden = !html;
}

function showDownloads() {
  const box = $("downloads");
  box.innerHTML = "";
  const parts = Object.keys(results);
  const base = fileBase();
  const btn = (text, buf, name) => {
    const b = document.createElement("button");
    b.type = "button";
    b.textContent = text;
    b.onclick = () => download(buf, name);
    box.append(b);
  };
  if (parts.length > 1) {
    btn("Download STL", mergeStl(parts.map((p) => results[p])), `${base}.stl`);
    for (const p of parts) btn(PART_NAMES[p], results[p], `${base}-${p}.stl`);
  } else if (parts.length === 1) {
    btn("Download STL", results[parts[0]], `${base}-${parts[0]}.stl`);
  }
}

function fileBase() {
  const v = values;
  return `wheel-${v.spoke_count}h-${v.num_crosses}x-erd${v.erd}-${v.hub_type}`;
}

// Binary STL = 80-byte header + uint32 triangle count + 50 bytes/triangle,
// so joining files is just adding the counts and concatenating triangles.
function mergeStl(buffers) {
  const counts = buffers.map((b) => new DataView(b).getUint32(80, true));
  const total = counts.reduce((a, b) => a + b, 0);
  const out = new Uint8Array(84 + total * 50);
  out.set(new TextEncoder().encode("Wheel Builder STL".padEnd(80, " ")), 0);
  new DataView(out.buffer).setUint32(80, total, true);
  let off = 84;
  buffers.forEach((b, i) => { out.set(new Uint8Array(b, 84, counts[i] * 50), off); off += counts[i] * 50; });
  return out.buffer;
}

function download(buf, name) {
  const url = URL.createObjectURL(new Blob([buf], { type: "model/stl" }));
  const a = Object.assign(document.createElement("a"), { href: url, download: name });
  document.body.append(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

// ---------------------------------------------------------------- viewer
let scene, camera, renderer, controls, modelGroup;
const loader = new STLLoader();

function setupViewer() {
  const host = $("viewer");
  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(35, 1, 1, 10000);
  camera.position.set(500, 350, 650);
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  host.prepend(renderer.domElement);
  controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;

  scene.add(new THREE.HemisphereLight(0xffffff, 0x666655, 1.6));
  const sun = new THREE.DirectionalLight(0xffffff, 1.8);
  sun.position.set(1, 1.5, 2);
  camera.add(sun);           // light follows the camera so the model is always lit
  scene.add(camera);

  modelGroup = new THREE.Group();
  modelGroup.rotation.x = -Math.PI / 2;  // OpenSCAD is Z-up; three.js is Y-up
  scene.add(modelGroup);

  new ResizeObserver(() => {
    const { clientWidth: w, clientHeight: h } = host;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }).observe(host);

  renderer.setAnimationLoop(() => { controls.update(); renderer.render(scene, camera); });
}

function clearModel() {
  for (const m of [...modelGroup.children]) { m.geometry.dispose(); m.material.dispose(); modelGroup.remove(m); }
}

function addMesh(part, buf) {
  const geom = loader.parse(buf);
  geom.computeVertexNormals();
  const mat = new THREE.MeshStandardMaterial({
    color: PART_COLORS[part] ?? 0x888888, metalness: part === "spokes" ? 0.6 : 0.3, roughness: 0.45,
  });
  modelGroup.add(new THREE.Mesh(geom, mat));
  frame();
}

function frame() {
  const box = new THREE.Box3().setFromObject(modelGroup);
  if (box.isEmpty()) return;
  const sphere = box.getBoundingSphere(new THREE.Sphere());
  const dist = sphere.radius / Math.sin(THREE.MathUtils.degToRad(camera.fov / 2)) * 0.8;
  const dir = camera.position.clone().sub(controls.target).normalize();
  controls.target.copy(sphere.center);
  camera.position.copy(sphere.center).addScaledVector(dir, dist);
  camera.near = dist / 100; camera.far = dist * 10;
  camera.updateProjectionMatrix();
}

// ---------------------------------------------------------------- misc
function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

$("generate").onclick = generate;
$("cancel").onclick = cancel;
$("reset").onclick = () => {
  for (const p of params) values[p.name] = p.default;
  history.replaceState(null, "", location.pathname);
  buildForm();
};
$("share").onclick = async () => {
  try { await navigator.clipboard.writeText(location.href); $("status").textContent = "Link copied"; }
  catch { prompt("Copy this link:", location.href); }
};

init().catch((e) => { $("overlay").textContent = "Could not load Wheel.scad: " + e.message; });
