// Reads OpenSCAD Customizer annotations from a .scad file and turns them
// into a parameter schema the page can build a form from.
//
//   /* [Group] */                 starts a group ([Hidden] ends parsing)
//   // Description               the comment line just above a parameter
//   name = 24; // [16:4:48]       number range  (min:step:max or min:max)
//   name = "a"; // [a:Label A, b] dropdown (value or value:label)
//   name = true;                  checkbox
//   name = 2.0;                   plain number

export function parseScadParams(source) {
  const params = [];
  let group = "Parameters";
  let lastComment = "";
  let started = false;

  for (const raw of source.split(/\r?\n/)) {
    const line = raw.trim();

    const g = line.match(/^\/\*\s*\[([^\]]+)\]\s*\*\/$/);
    if (g) {
      group = g[1].trim();
      started = true;
      if (group.toLowerCase() === "hidden") break;
      lastComment = "";
      continue;
    }
    if (!started) continue;

    if (line.startsWith("//")) { lastComment = line.replace(/^\/\/\s*/, ""); continue; }

    const m = line.match(/^([A-Za-z_]\w*)\s*=\s*([^;]+);\s*(?:\/\/\s*(.*))?$/);
    if (!m) { if (line === "") lastComment = ""; continue; }
    const [, name, valueText, annotation = ""] = m;
    const p = parseOne(name, valueText.trim(), annotation.trim());
    if (p) {
      p.group = group;
      p.label = lastComment || name.replace(/_/g, " ");
      params.push(p);
    }
    lastComment = "";
  }
  return params;
}

function parseOne(name, valueText, annotation) {
  let value, kind;
  if (valueText === "true" || valueText === "false") { kind = "bool"; value = valueText === "true"; }
  else if (/^".*"$/.test(valueText)) { kind = "string"; value = valueText.slice(1, -1); }
  else if (/^-?\d+(\.\d+)?$/.test(valueText)) { kind = "number"; value = parseFloat(valueText); }
  else return null; // expressions etc. aren't user-settable

  const p = { name, kind, default: value };
  const a = annotation.match(/^\[(.*)\]$/);
  if (!a || kind === "bool") return p;
  const body = a[1];

  if (kind === "number" && /^-?[\d.]+(:-?[\d.]+){1,2}$/.test(body)) {
    const n = body.split(":").map(Number);
    if (n.length === 2) Object.assign(p, { min: n[0], max: n[1], step: 1 });
    else Object.assign(p, { min: n[0], step: n[1], max: n[2] });
    return p;
  }
  // Dropdown: "a:Label A, b:Label B" or "10, 11"
  p.options = body.split(",").map((s) => {
    const [v, ...rest] = s.trim().split(":");
    const val = kind === "number" ? Number(v) : v.trim();
    return { value: val, label: rest.length ? rest.join(":").trim() : String(val) };
  });
  return p;
}

// Validate/clamp a value against its schema entry. Returns the clean value.
export function cleanValue(p, raw) {
  if (p.kind === "bool") return raw === true || raw === "true" || raw === "1";
  if (p.options) {
    const hit = p.options.find((o) => String(o.value) === String(raw));
    return hit ? hit.value : p.default;
  }
  if (p.kind === "number") {
    let v = Number(raw);
    if (!Number.isFinite(v)) return p.default;
    if (p.min !== undefined) v = Math.max(p.min, v);
    if (p.max !== undefined) v = Math.min(p.max, v);
    if (p.step && p.min !== undefined) {           // snap to the slider step
      v = p.min + Math.round((v - p.min) / p.step) * p.step;
      v = Math.min(p.max, parseFloat(v.toFixed(6)));
    }
    return v;
  }
  // free-text strings: keep it to safe characters
  const s = String(raw);
  return /^[\w .\-]{0,64}$/.test(s) ? s : p.default;
}

// Build OpenSCAD -D arguments. Values are already cleaned, and numbers
// are re-serialized, so nothing arbitrary reaches OpenSCAD's parser.
export function toDefines(params, values) {
  const out = [];
  for (const p of params) {
    if (p.name === "part") continue; // the worker sets part per render
    const v = cleanValue(p, values[p.name]);
    const text = p.kind === "string" ? JSON.stringify(v) : String(v);
    out.push("-D", `${p.name}=${text}`);
  }
  return out;
}
