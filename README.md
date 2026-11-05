# Wheel Builder (web front end for Wheel.scad)

A static web page: visitors set the wheel parameters, OpenSCAD runs in their
browser (WebAssembly), they see a 3D preview and download the STL.
No server code, so it can be hosted anywhere that serves files.

## Files

| File | What it does |
|---|---|
| `index.html` | Page layout and styles |
| `app.js` | Builds the form from Wheel.scad, 3D preview (three.js), downloads, shareable URLs |
| `params.js` | Reads the Customizer annotations in Wheel.scad; validates values |
| `worker.js` | Runs OpenSCAD in a background thread so the page stays responsive |
| `Wheel.scad` | The model, with a parameter section at the top |
| `Wheel.original.scad` | Your original file, for comparison |
| `assets/` | Put your `rim.svg`, `HopePro4Rear.svg`, `front_hub.svg`, `six_bolt.svg`, `centerlock.svg`, `nipple.stl`, `elbow.stl`, `thread.scad` here |

## Run it locally (WSL)

Workers and `fetch()` don't work from `file://`, so use a tiny local server:

```bash
cd wheel-site
python3 -m http.server 8000
```

Then open http://localhost:8000 in your Windows browser.

## Adding or changing parameters

Edit only `Wheel.scad`. Anything between the first `/* [Group] */` header
and `/* [Hidden] */` appears on the page automatically:

```scad
/* [Rim] */
// Effective rim diameter (mm)          <- label on the page
erd = 610; // [400:0.5:660]             <- slider: min:step:max
hub_type = "rear"; // [rear:Rear, front:Front]   <- dropdown
use_stl_parts = false;                  <- checkbox
```

Values are clamped and snapped to the slider step before being passed to
OpenSCAD with `-D`, and dropdowns only accept listed values.

## Changes to Wheel.scad (marked `CHANGED:` in the file)

- Parameters moved to the top with Customizer annotations; added `part`
  (whole wheel / hub / rim / spokes), `detail` ($fn), `hub_type`,
  `hub_source`, `rim_source`, `bsd`, `brake_mount`, `use_stl_parts`.
- **Loop bug:** the spoke, flange-hole and freehub loops ran `[0:count]`,
  making one extra item stacked on item 0 (25 spokes per side for a
  24-hole side, etc.). Now `[0:count-1]`.
- `assert("nds_dist is too large", true)` had its arguments reversed, so it
  never fired. Replaced with real checks (spoke count multiple of 4, flange
  distances < OLD/2, ERD vs flange size).
- `rim_by_points` moved the profile out by ERD/2 a second time; fixed.
  Rim bead seat (was hard-coded 622) is now `bsd`.
- `brake_mount` now selects none / 6-bolt / centerlock (the old
  `disc_brake` argument was ignored and six_bolt.svg was always used).
- New generated front hub.
- Spoke lengths are echoed (`SPOKE_LENGTH_*`, `ORDER_LENGTH_*`) and shown
  on the page. A warning is echoed when the cross pattern puts a spoke 90°
  or more around the flange.
- Threads and the "W" logo are optional so `thread.scad` and fonts aren't
  required for the web build.

**Defaults that differ from your file:** `hub_source="generated"` (the Hope
SVG ignores the flange parameters), `use_stl_parts=false` and
`brake_mount="none"`. Flip them in Wheel.scad once your assets are in place.

## Deploying

Copy the folder to any static host (mega-mouse.net, GitHub Pages, Netlify,
Cloudflare Pages). For reliability you can self-host the libraries instead
of using the jsDelivr CDN:

```bash
npm i openscad-wasm-prebuilt@1.2.0 three@0.170.0
mkdir -p vendor && cp node_modules/openscad-wasm-prebuilt/dist/openscad.js vendor/
cp -r node_modules/three vendor/three
```

then point the import in `worker.js` and the importmap in `index.html` at `./vendor/...`.

## Command line (same file)

```bash
openscad --backend=manifold -D spoke_count=32 -D num_crosses=3 -D 'part="spokes"' -o spokes.stl Wheel.scad
```
