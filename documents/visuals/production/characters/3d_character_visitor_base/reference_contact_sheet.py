"""Assemble a self-contained comparison page: reference sheet vs rendered model.

    python3 reference_contact_sheet.py bench [render_dir] [out_html]
    python3 reference_contact_sheet.py boy   [render_dir] [out_html]

Each row pairs one usable panel of the reference PNG with the matching render produced by
``bench_preview.py`` / ``boy_preview.py``. Every image is embedded as a data URI, so the
output is a single portable HTML file.
"""

import base64
import io
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

ASSETS = {
    "bench": {
        "title": "Bench",
        "reference": "bench.png",
        "renders": "/tmp/bench_shots",
        "panel_h": 320,
        "meta": ("1.80 &times; 0.56 &times; 0.49 m &middot; 1 836 tris &middot; 2 materials "
                 "(orange timber, blue steel). Top-right panel (bench back) is intentionally "
                 "not modelled."),
        "rows": [
            ("Front elevation - length, seat thickness, leg stance", (880, 360, 1536, 590), "front"),
            ("End elevation - seat depth, leg splay, frame rails, feet", (670, 650, 980, 1024), "end"),
            ("Three-quarter from above (panel A) - slat + bolt layout", (60, 40, 760, 540), "top34"),
            ("Three-quarter front-left (panel D) - frame and rail ends", (30, 555, 650, 1010), "hero34"),
            ("Three-quarter front-right (panel F) - post + foot pads", (990, 620, 1536, 1000), "side34"),
        ],
        "build": "blender -b -P bench_build.py",
        "render": "blender -b bench.blend -P bench_preview.py -- /tmp/bench_shots",
    },
    "bin": {
        "title": "Litter bin",
        "reference": "bin.png",
        "renders": "/tmp/bin_shots",
        "panel_h": 380,
        "meta": ("0.61 &times; 0.61 &times; 1.10 m &middot; 4 076 tris &middot; 5 materials "
                 "(navy frame, cream shell, cyan roof, blue sign, white pictogram). The "
                 "pictogram faces +Y in Blender, i.e. Godot's -Z forward after export."),
        "rows": [
            ("Front elevation - shell width, corner posts, bolt rows, pictogram plate", (829, 150, 1036, 540), "front"),
            ("Side elevation - the plan is square, so this repeats the front", (1000, 150, 1200, 540), "end"),
            ("Roof plan (top row, last panel) - square slab with a mitred top bevel", (1248, 180, 1524, 470), "roof_top"),
            ("Three-quarter from above (bottom row) - overhang, liner rim, plinth corner cut", (1050, 540, 1250, 905), "top34"),
            ("Three-quarter hero (left panel) - panel bevels, dome bolts, pictogram", (55, 70, 545, 930), "hero34"),
        ],
        "build": "blender -b -P bin_build.py",
        "render": "blender -b bin.blend -P bin_preview.py -- /tmp/bin_shots",
    },
    "boy": {
        "title": "Boy (hoodie visitor)",
        "reference": "reference_02_3_figures_second_boy.png",
        "renders": "/tmp/boy_shots",
        "panel_h": 420,
        "meta": ("1.25 m tall, ~3.7 heads &middot; 2 690 tris &middot; 6 materials (skin, hair, "
                 "jacket blue, cloth white, shorts tan, eye dark). Faces +Y in Blender, "
                 "i.e. Godot's -Z forward after export."),
        "rows": [
            ("Front - head/body proportions, open jacket over white tee", (90, 10, 530, 1010), "front"),
            ("Three-quarter - head depth, jacket bulk, pockets", (590, 10, 1000, 1010), "threequarter"),
            ("Back - hood on the back, hair mass over the nape", (1020, 10, 1470, 1010), "back"),
        ],
        "build": "blender -b -P boy_build.py",
        "render": "blender -b boy.blend -P boy_preview.py -- /tmp/boy_shots",
    },
}


def data_uri(image, quality=82):
    buf = io.BytesIO()
    image.convert("RGB").save(buf, format="JPEG", quality=quality, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode("ascii")


def fit(image, height):
    width = max(1, round(image.size[0] * height / image.size[1]))
    return image.resize((width, height), Image.LANCZOS)


def build_page(asset, render_dir, panel_h):
    reference = Image.open(os.path.join(HERE, asset["reference"]))
    sections = []
    for caption, box, stem in asset["rows"]:
        tiles = []
        if box:
            tiles.append(("reference", data_uri(fit(reference.crop(box), panel_h))))
        path = os.path.join(render_dir, f"{stem}.png")
        if os.path.exists(path):
            tiles.append(("model", data_uri(fit(Image.open(path), panel_h))))
        cells = "".join(
            f"<figure><span class='tag {kind}'>{kind}</span><img src='{uri}' alt='{stem}'></figure>"
            for kind, uri in tiles
        )
        sections.append(f"<section><h2>{caption}</h2><div class='row'>{cells}</div></section>")

    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>{asset['title']} - reference comparison</title>
<style>
 :root {{ color-scheme: dark; }}
 body {{ margin:0; padding:28px; background:#14161c; color:#e8e6e1;
        font:14px/1.5 ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif; }}
 h1 {{ font-size:22px; margin:0 0 4px; }}
 p.meta {{ color:#9aa0ab; margin:0 0 24px; }}
 section {{ margin-bottom:26px; }}
 h2 {{ font-size:14px; font-weight:600; color:#c8ccd4; margin:0 0 10px;
       border-left:3px solid #e58950; padding-left:9px; }}
 .row {{ display:flex; gap:16px; align-items:flex-start; flex-wrap:wrap; }}
 figure {{ margin:0; position:relative; border-radius:8px; overflow:hidden;
           background:#0e1015; box-shadow:0 6px 18px #0006; }}
 img {{ display:block; height:{panel_h}px; }}
 .tag {{ position:absolute; top:8px; left:8px; font-size:11px; letter-spacing:.03em;
         padding:2px 7px; border-radius:99px; background:#0009; backdrop-filter:blur(3px); }}
 .tag.reference {{ color:#f0b184; }}
 .tag.model {{ color:#9fc4ff; }}
 code {{ background:#20232b; padding:1px 5px; border-radius:4px; }}
 footer {{ color:#8b909a; border-top:1px solid #262a33; padding-top:14px; margin-top:8px; }}
</style></head>
<body>
 <h1>{asset['title']} &mdash; reference vs generated model</h1>
 <p class="meta">Source <code>{asset['reference']}</code> &middot; {asset['meta']}</p>
 {''.join(sections)}
 <footer>Rebuild with <code>{asset['build']}</code>, re-render with
   <code>{asset['render']}</code>.</footer>
</body></html>
"""


def main():
    key = sys.argv[1] if len(sys.argv) > 1 else "bench"
    asset = ASSETS[key]
    render_dir = sys.argv[2] if len(sys.argv) > 2 else asset["renders"]
    out_html = (sys.argv[3] if len(sys.argv) > 3
                else os.path.join(HERE, ".freebuff", f"{key}_preview", "index.html"))
    os.makedirs(os.path.dirname(out_html), exist_ok=True)
    with open(out_html, "w", encoding="utf-8") as handle:
        handle.write(build_page(asset, render_dir, asset["panel_h"]))
    print(f"[sheet] wrote {out_html}")


main()
